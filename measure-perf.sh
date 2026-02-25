#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Find dotnet SDK (prefer local dotnet folder, fallback to system)
if [[ -x "$SCRIPT_DIR/dotnet/dotnet" ]]; then
    DOTNET="$SCRIPT_DIR/dotnet/dotnet"
elif [[ -d "$SCRIPT_DIR/macios/builds/downloads" ]]; then
    DOTNET=$(find "$SCRIPT_DIR/macios/builds/downloads" -maxdepth 2 -name "dotnet" -type f 2>/dev/null | head -1)
fi
DOTNET="${DOTNET:-$(command -v dotnet)}"
[[ -x "$DOTNET" ]] || { echo "Error: dotnet not found"; exit 1; }

# Find mlaunch (search in local packs, then system packs)
MLAUNCH=$(find "$SCRIPT_DIR/dotnet/packs" /usr/local/share/dotnet/packs ~/.dotnet/packs 2>/dev/null -path "*/tools/bin/mlaunch" -type f 2>/dev/null | head -1)
[[ -x "$MLAUNCH" ]] || { echo "Error: mlaunch not found"; exit 1; }

# Find connected iOS device (first available) - format: "Device Name: DEVICE_ID"
LISTDEV_TMP=$(mktemp)
"$MLAUNCH" --listdev > "$LISTDEV_TMP" 2>&1 &
LISTDEV_PID=$!
sleep 10
kill $LISTDEV_PID 2>/dev/null || true
wait $LISTDEV_PID 2>/dev/null || true
DEVICE_ID=$(grep -oE '[0-9A-F]{8}-[0-9A-F]{16}' "$LISTDEV_TMP" | head -1)
rm -f "$LISTDEV_TMP"
[[ -n "$DEVICE_ID" ]] || { echo "Error: No iOS device connected"; exit 1; }

APPS_DIR="$SCRIPT_DIR/apps"
RESULTS_DIR="$SCRIPT_DIR/results"

APP="$1"
RUNTIME="$2"
CONFIG="$3"

# Validate arguments
if [[ -z "$APP" || -z "$RUNTIME" || -z "$CONFIG" ]]; then
    echo "Usage: $0 <ios|maui|seeingai|azureux|m365admin> <coreclr|mono|nativeaot> <debug|release>"
    exit 1
fi
[[ "$APP" =~ ^(ios|maui|seeingai|azureux|m365admin)$ ]] || { echo "Usage: $0 <ios|maui|seeingai|azureux|m365admin> <coreclr|mono|nativeaot> <debug|release>"; exit 1; }
[[ "$RUNTIME" =~ ^(coreclr|mono|nativeaot)$ ]] || { echo "Usage: $0 <ios|maui|seeingai|azureux|m365admin> <coreclr|mono|nativeaot> <debug|release>"; exit 1; }
[[ "$CONFIG" =~ ^(debug|release)$ ]] || { echo "Usage: $0 <ios|maui|seeingai|azureux|m365admin> <coreclr|mono|nativeaot> <debug|release>"; exit 1; }

# Map app name and config
case "$APP" in
    ios)       APP_NAME="SampleiOS" ;;
    maui)      APP_NAME="SampleMAUI" ;;
    seeingai)  APP_NAME="SeeingAI-Mobile" ;;
    azureux)   APP_NAME="AzureUX-Mobile" ;;
    m365admin) APP_NAME="M365AdminMobileApp" ;;
esac
[[ "$CONFIG" == "debug" ]] && MSBUILD_CONFIG="Debug" || MSBUILD_CONFIG="Release"

# Clean build artifacts
if [[ "$APP" == "seeingai" ]]; then
    rm -rf "$APPS_DIR/$APP_NAME/iOS/App/bin" "$APPS_DIR/$APP_NAME/iOS/App/obj"
elif [[ "$APP" == "azureux" ]]; then
    rm -rf "$APPS_DIR/$APP_NAME/AzureMobile/AzureMobile.iOS/bin" "$APPS_DIR/$APP_NAME/AzureMobile/AzureMobile.iOS/obj"
elif [[ "$APP" == "m365admin" ]]; then
    rm -rf "$APPS_DIR/$APP_NAME/Admin/O365Admin.iOS/bin" "$APPS_DIR/$APP_NAME/Admin/O365Admin.iOS/obj"
else
    rm -rf "$APPS_DIR/$APP_NAME/bin" "$APPS_DIR/$APP_NAME/obj"
fi

# Map runtime props
case "$RUNTIME" in
    coreclr)   RUNTIME_PROPS="-p:UseMonoRuntime=false"; RUNTIME_NAME="CoreCLR" ;;
    mono)      RUNTIME_PROPS="-p:UseMonoRuntime=true"; RUNTIME_NAME="Mono" ;;
    nativeaot) RUNTIME_PROPS="-p:PublishAot=true -p:PublishAotUsingRuntimePack=true"; RUNTIME_NAME="NativeAOT" ;;
esac

# Set project and bundle paths
if [[ "$APP" == "seeingai" ]]; then
    PROJ="$APPS_DIR/$APP_NAME/iOS/App/SeeingAI.iOS.csproj"
    APP_BUNDLE="$APPS_DIR/$APP_NAME/iOS/App/bin/$MSBUILD_CONFIG/net11.0-ios/ios-arm64/SeeingAI.iOS.app"
    DISPLAY_NAME="SeeingAI"
elif [[ "$APP" == "azureux" ]]; then
    PROJ="$APPS_DIR/$APP_NAME/AzureMobile/AzureMobile.iOS/AzureMobile.iOS.csproj"
    APP_BUNDLE="$APPS_DIR/$APP_NAME/AzureMobile/AzureMobile.iOS/bin/$MSBUILD_CONFIG/net11.0-ios/ios-arm64/AzureMobile.iOS.app"
    DISPLAY_NAME="AzureUX"
elif [[ "$APP" == "m365admin" ]]; then
    PROJ="$APPS_DIR/$APP_NAME/Admin/O365Admin.iOS/O365Admin.iOS.csproj"
    APP_BUNDLE="$APPS_DIR/$APP_NAME/Admin/O365Admin.iOS/bin/$MSBUILD_CONFIG/net11.0-ios/ios-arm64/O365Admin.iOS.app"
    DISPLAY_NAME="M365Admin"
else
    PROJ="$APPS_DIR/$APP_NAME/$APP_NAME.csproj"
    APP_BUNDLE="$APPS_DIR/$APP_NAME/bin/$MSBUILD_CONFIG/net11.0-ios/ios-arm64/$APP_NAME.app"
    DISPLAY_NAME="$APP_NAME"
fi

# Create results directory
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
RUN_DIR="$RESULTS_DIR/${APP}-${RUNTIME}-${CONFIG}-${TIMESTAMP}"
mkdir -p "$RUN_DIR"

# Create app if needed (skip for SeeingAI, AzureUX, and M365Admin which are already present)
mkdir -p "$APPS_DIR"
if [[ "$APP" != "seeingai" && "$APP" != "azureux" && "$APP" != "m365admin" && ! -d "$APPS_DIR/$APP_NAME" ]]; then
    echo "Creating $APP_NAME..."
    "$DOTNET" new $APP -n $APP_NAME -o "$APPS_DIR/$APP_NAME" --force
fi

# Build with timing
echo "Building..."
BUILD_START=$(date +%s.%N)

# SeeingAI and AzureUX define their own constants per config;
# replicate them here so we can also add DEBUG_LAUNCH_TIME.
if [[ "$APP" == "seeingai" ]]; then
    if [[ "$CONFIG" == "debug" ]]; then
        DEFINE_CONSTANTS='-p:DefineConstants=DEBUG%3BALPHA%3BDEBUG_LAUNCH_TIME'
    else
        DEFINE_CONSTANTS='-p:DefineConstants=BETA%3BDEBUG_LAUNCH_TIME'
    fi
    EXTRA_PROPS='-p:RunSwiftAppIntentExtension=false'
elif [[ "$APP" == "azureux" ]]; then
    if [[ "$CONFIG" == "debug" ]]; then
        DEFINE_CONSTANTS='-p:DefineConstants=DEBUG%3B__MOBILE__%3B__UNIFIED__%3B__IOS__%3BDEBUG_LAUNCH_TIME'
    else
        DEFINE_CONSTANTS='-p:DefineConstants=__IOS__%3BDEBUG_LAUNCH_TIME'
    fi
    EXTRA_PROPS='-p:BuildIpa=false'
elif [[ "$APP" == "m365admin" ]]; then
    if [[ "$CONFIG" == "debug" ]]; then
        DEFINE_CONSTANTS='-p:DefineConstants=DEBUG%3BENABLE_TEST_CLOUD%3BDEBUG_LAUNCH_TIME'
    else
        DEFINE_CONSTANTS='-p:DefineConstants=DEBUG_LAUNCH_TIME'
    fi
    EXTRA_PROPS=''
else
    DEFINE_CONSTANTS='-p:DefineConstants=DEBUG_LAUNCH_TIME'
    EXTRA_PROPS=''
fi

if [[ "$RUNTIME" == "nativeaot" ]]; then
    "$DOTNET" publish "$PROJ" -c $MSBUILD_CONFIG $RUNTIME_PROPS \
        -f net11.0-ios \
        -p:RuntimeIdentifier=ios-arm64 \
        "$DEFINE_CONSTANTS" $EXTRA_PROPS --nologo \
        -bl:"$RUN_DIR/build.binlog"
else
    "$DOTNET" build "$PROJ" -c $MSBUILD_CONFIG $RUNTIME_PROPS \
        -p:RuntimeIdentifier=ios-arm64 \
        "$DEFINE_CONSTANTS" $EXTRA_PROPS --nologo \
        -bl:"$RUN_DIR/build.binlog"
fi
BUILD_END=$(date +%s.%N)
BUILD_TIME=$(echo "scale=2; $BUILD_END - $BUILD_START" | bc)

# Measure size
SIZE_KB=$(du -sk "$APP_BUNDLE" | cut -f1)
SIZE_MB=$(echo "scale=2; $SIZE_KB / 1024" | bc)

echo "Build: ${BUILD_TIME}s, Size: ${SIZE_MB}MB"

# Install app
echo "Installing..."
"$MLAUNCH" --installdev "$APP_BUNDLE" --devname "$DEVICE_ID" -v -v -v -v 2>&1 | tail -5

# Run app twice - first is warm-up, measure second
echo "Running (warm-up)..."
"$MLAUNCH" --launchdev "$APP_BUNDLE" --devname "$DEVICE_ID" \
    --wait-for-exit:true -v -v -v -v -- > /dev/null 2>&1 &
MLAUNCH_PID=$!
sleep 5
kill $MLAUNCH_PID 2>/dev/null || true
wait $MLAUNCH_PID 2>/dev/null || true

echo "Running (measured)..."
RUN_LOG="$RUN_DIR/run.log"
"$MLAUNCH" --launchdev "$APP_BUNDLE" --devname "$DEVICE_ID" \
    --wait-for-exit:true -v -v -v -v -- > "$RUN_LOG" 2>&1 &
MLAUNCH_PID=$!
sleep 5
kill $MLAUNCH_PID 2>/dev/null || true
wait $MLAUNCH_PID 2>/dev/null || true

# Parse timing from logs
# VM init: "Total initialization time" line shows total VM init time
# Managed main: calculated from timestamp difference between "Total initialization time" and "didFinishLaunchingWithOptions: END"
VM_INIT_US=$(grep "Total initialization time:" "$RUN_LOG" | grep -oE 'Total: [0-9]+' | grep -oE '[0-9]+' | tail -1 || true)

# Extract timestamps and calculate managed time as the difference
VM_INIT_TIME=$(grep "Total initialization time:" "$RUN_LOG" | grep -oE '[0-9]{2}:[0-9]{2}:[0-9]{2}\.[0-9]+' | tail -1 || true)
MANAGED_END_TIME=$(grep "didFinishLaunchingWithOptions end:" "$RUN_LOG" | grep -oE '[0-9]{2}:[0-9]{2}:[0-9]{2}\.[0-9]+' | tail -1 || true)

if [[ -n "$VM_INIT_TIME" && -n "$MANAGED_END_TIME" ]]; then
    # Convert HH:MM:SS.mmm to total seconds and calculate difference in microseconds
    VM_INIT_SECS=$(echo "$VM_INIT_TIME" | awk -F'[:.]' '{printf "%.3f", ($1*3600 + $2*60 + $3) + ($4/1000)}')
    MANAGED_END_SECS=$(echo "$MANAGED_END_TIME" | awk -F'[:.]' '{printf "%.3f", ($1*3600 + $2*60 + $3) + ($4/1000)}')
    MANAGED_END_US=$(echo "scale=0; ($MANAGED_END_SECS - $VM_INIT_SECS) * 1000000 / 1" | bc)
else
    MANAGED_END_US=""
fi

if [[ -n "$VM_INIT_US" ]]; then
  VM_INIT_MS=$(echo "scale=2; $VM_INIT_US / 1000" | bc)
else
  VM_INIT_MS="N/A"
fi

if [[ -n "$VM_INIT_US" && -n "$MANAGED_END_US" ]]; then
  MANAGED_MS=$(echo "scale=2; $MANAGED_END_US / 1000" | bc)
  TOTAL_MS=$(echo "scale=2; ($VM_INIT_US + $MANAGED_END_US) / 1000" | bc)
else
  MANAGED_MS="N/A"
  TOTAL_MS="N/A"
fi

# Print results
echo ""
echo "=== Results: $DISPLAY_NAME ($RUNTIME_NAME) ==="
echo "Build Time:     ${BUILD_TIME}s"
echo "Bundle Size:    ${SIZE_MB} MB"
echo "VM Init:        ${VM_INIT_MS} ms"
echo "Managed Main:   ${MANAGED_MS} ms"
echo "Total Startup:  ${TOTAL_MS} ms"
echo ""
echo "Logs saved: $RUN_DIR"
