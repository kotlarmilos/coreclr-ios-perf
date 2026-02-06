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
sleep 3
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
    echo "Usage: $0 <ios|maui> <coreclr|mono|nativeaot> <debug|release>"
    exit 1
fi
[[ "$APP" =~ ^(ios|maui)$ ]] || { echo "Usage: $0 <ios|maui> <coreclr|mono|nativeaot> <debug|release>"; exit 1; }
[[ "$RUNTIME" =~ ^(coreclr|mono|nativeaot)$ ]] || { echo "Usage: $0 <ios|maui> <coreclr|mono|nativeaot> <debug|release>"; exit 1; }
[[ "$CONFIG" =~ ^(debug|release)$ ]] || { echo "Usage: $0 <ios|maui> <coreclr|mono|nativeaot> <debug|release>"; exit 1; }

# Map app name and config
[[ "$APP" == "ios" ]] && APP_NAME="SampleiOS" || APP_NAME="SampleMAUI"
[[ "$CONFIG" == "debug" ]] && MSBUILD_CONFIG="Debug" || MSBUILD_CONFIG="Release"

# Clean build artifacts
rm -rf "$APPS_DIR/$APP_NAME/bin" "$APPS_DIR/$APP_NAME/obj"

# Map runtime props
case "$RUNTIME" in
    coreclr)   RUNTIME_PROPS="-p:UseMonoRuntime=false"; RUNTIME_NAME="CoreCLR" ;;
    mono)      RUNTIME_PROPS="-p:UseMonoRuntime=true"; RUNTIME_NAME="Mono" ;;
    nativeaot) RUNTIME_PROPS="-p:PublishAot=true -p:PublishAotUsingRuntimePack=true"; RUNTIME_NAME="NativeAOT" ;;
esac

PROJ="$APPS_DIR/$APP_NAME/$APP_NAME.csproj"
APP_BUNDLE="$APPS_DIR/$APP_NAME/bin/$MSBUILD_CONFIG/net11.0-ios/ios-arm64/$APP_NAME.app"

# Create results directory
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
RUN_DIR="$RESULTS_DIR/${APP}-${RUNTIME}-${CONFIG}-${TIMESTAMP}"
mkdir -p "$RUN_DIR"

# Create app if needed
mkdir -p "$APPS_DIR"
if [[ ! -d "$APPS_DIR/$APP_NAME" ]]; then
    echo "Creating $APP_NAME..."
    "$DOTNET" new $APP -n $APP_NAME -o "$APPS_DIR/$APP_NAME" --force
fi

# Build with timing
echo "Building..."
BUILD_START=$(date +%s.%N)
if [[ "$RUNTIME" == "nativeaot" ]]; then
    "$DOTNET" publish "$PROJ" -c $MSBUILD_CONFIG $RUNTIME_PROPS \
        -f net11.0-ios \
        -p:RuntimeIdentifier=ios-arm64 \
        -p:DefineConstants=DEBUG_LAUNCH_TIME --nologo
else
    "$DOTNET" build "$PROJ" -c $MSBUILD_CONFIG $RUNTIME_PROPS \
        -p:RuntimeIdentifier=ios-arm64 \
        -p:DefineConstants=DEBUG_LAUNCH_TIME --nologo
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
# Managed main: from "Total initialization time" to "[PERF] RuntimeInit - didFinishLaunchingWithOptions: END"
VM_INIT_US=$(grep "Total initialization time:" "$RUN_LOG" | grep -oE 'Total: [0-9]+' | grep -oE '[0-9]+' | tail -1 || true)
MANAGED_END_US=$(grep "\[PERF\].*END:" "$RUN_LOG" | grep -oE 'Total: [0-9]+' | grep -oE '[0-9]+' | tail -1 || true)

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
echo "=== Results: $APP_NAME ($RUNTIME_NAME) ==="
echo "Build Time:     ${BUILD_TIME}s"
echo "Bundle Size:    ${SIZE_MB} MB"
echo "VM Init:        ${VM_INIT_MS} ms"
echo "Managed Main:   ${MANAGED_MS} ms"
echo "Total Startup:  ${TOTAL_MS} ms"
echo ""
echo "Log saved: $RUN_LOG"
