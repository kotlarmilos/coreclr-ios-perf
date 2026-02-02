#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTNET="$SCRIPT_DIR/dotnet/dotnet"
APPS_DIR="$SCRIPT_DIR/apps"
RESULTS_DIR="$SCRIPT_DIR/results"

# Ensure we use local SDK only
export DOTNET_ROOT="$SCRIPT_DIR/dotnet"
export PATH="$DOTNET_ROOT:$PATH"
export DOTNET_MULTILEVEL_LOOKUP=0

APP="$1"
RUNTIME="$2"
CONFIG="$3"
TARGET="$4"

# Validate arguments
if [[ -z "$APP" || -z "$RUNTIME" || -z "$CONFIG" || -z "$TARGET" ]]; then
    echo "Usage: $0 <ios|maui> <coreclr|mono|nativeaot> <debug|release> <simulator|device>"
    exit 1
fi
[[ "$APP" =~ ^(ios|maui)$ ]] || { echo "Usage: $0 <ios|maui> <coreclr|mono|nativeaot> <debug|release> <simulator|device>"; exit 1; }
[[ "$RUNTIME" =~ ^(coreclr|mono|nativeaot)$ ]] || { echo "Usage: $0 <ios|maui> <coreclr|mono|nativeaot> <debug|release> <simulator|device>"; exit 1; }
[[ "$CONFIG" == "debug" || "$CONFIG" == "release" ]] || { echo "Usage: $0 <ios|maui> <coreclr|mono|nativeaot> <debug|release> <simulator|device>"; exit 1; }
[[ "$TARGET" == "simulator" || "$TARGET" == "device" ]] || { echo "Usage: $0 <ios|maui> <coreclr|mono|nativeaot> <debug|release> <simulator|device>"; exit 1; }

# Map to MSBuild config and RID
MSBUILD_CONFIG=$([[ "$CONFIG" == "debug" ]] && echo "Debug" || echo "Release")
if [[ "$TARGET" == "simulator" ]]; then
    RID="iossimulator-arm64"
    XHARNESS_TARGET="ios-simulator-64"
else
    RID="ios-arm64"
    XHARNESS_TARGET="ios-device"
fi

# Create results directory for this run
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
RUN_DIR="$RESULTS_DIR/${APP}-${RUNTIME}-${CONFIG}-${TARGET}-${TIMESTAMP}"
mkdir -p "$RUN_DIR"

echo "  dotnet new $APP - $RUNTIME $CONFIG"

# Setup SDK if needed
[[ -f "$DOTNET" ]] || "$SCRIPT_DIR/dotnet.sh"

# Create sample apps
mkdir -p "$APPS_DIR"
create_app() {
    local name=$1 template=$2
    if [[ ! -d "$APPS_DIR/$name" ]]; then
        echo "Creating $name app..."
        "$DOTNET" new $template -n $name -o "$APPS_DIR/$name" --force
    fi
}
create_app "SampleiOS" "ios"
create_app "SampleMAUI" "maui"

# Build and measure
measure() {
    local app=$1 runtime=$2
    local proj="$APPS_DIR/$app/$app.csproj"
    local extra_props=""
    
    case "$runtime" in
        CoreCLR)   extra_props="-p:UseMonoRuntime=false" ;;
        Mono)      extra_props="-p:UseMonoRuntime=true" ;;
        NativeAOT) extra_props="-p:PublishAot=true -p:UseMonoRuntime=false" ;;
    esac
    
    # Clean
    rm -rf "$APPS_DIR/$app/bin" "$APPS_DIR/$app/obj"
    
    # Build with timing
    echo ""
    echo "Building app..."
    local start=$(date +%s.%N)
    "$DOTNET" build "$proj" -c "$MSBUILD_CONFIG" $extra_props \
        -p:RuntimeIdentifier=$RID \
        -p:DefineConstants=DEBUG_LAUNCH_TIME --nologo
    local end=$(date +%s.%N)
    local build_time=$(echo "scale=2; $end - $start" | bc)
    
    # Find and measure app bundle
    local app_bundle=$(find "$APPS_DIR/$app/bin" -name "*.app" -type d 2>/dev/null | head -1)
    local size_kb=0
    [[ -d "$app_bundle" ]] && size_kb=$(du -sk "$app_bundle" | cut -f1)
    local size_mb=$(echo "scale=2; $size_kb / 1024" | bc)
    
    # Copy app bundle snapshot
    if [[ -d "$app_bundle" ]]; then
        cp -R "$app_bundle" "$RUN_DIR/"
    fi
    
    # Run on selected target and measure startup time with Instruments
    # 1 cold run + 3 warm runs (averaged)
    echo ""
    echo "Running on $TARGET..."
    local cold_runtime_ms="N/A"
    
    local cold_managed_ms="N/A"
    local warm_runtime_ms="N/A"
    
    local warm_managed_ms="N/A"
    
    # Helper to get median of 3 values
    median3() {
        echo "$1 $2 $3" | tr ' ' '\n' | sort -n | sed -n '2p'
    }
    
    if [[ -d "$app_bundle" ]]; then
        local bundle_id=$(defaults read "$app_bundle/Info.plist" CFBundleIdentifier)
        
        if [[ "$TARGET" == "simulator" ]]; then
            # Boot simulator if needed
            xcrun simctl boot "iPhone 16" 2>/dev/null || true
            local sim_udid=$(xcrun simctl list devices booted -j | python3 -c "import sys,json; d=json.load(sys.stdin); print([u for devs in d['devices'].values() for u in devs if u['state']=='Booted'][0]['udid'])" 2>/dev/null)
            
            # Install app (fresh install for cold run)
            echo "Installing app..."
            xcrun simctl uninstall booted "$bundle_id" 2>/dev/null || true
            xcrun simctl install booted "$app_bundle"
            
            # Cold run (first run after install)
            echo "Cold run..."
            cd "$RUN_DIR"
            xcrun xctrace record --template "Time Profiler" \
                --device "$sim_udid" \
                --time-limit 5s \
                --launch -- "$app_bundle" 2>&1 || true
            xcrun simctl terminate booted "$bundle_id" 2>/dev/null || true
            sleep 1
            
            local latest_trace=$(find . -maxdepth 1 -name "*.trace" -type d 2>/dev/null | head -1)
            if [[ -n "$latest_trace" && -d "$latest_trace" ]]; then
                mv "$latest_trace" "cold-run.trace"
            fi
            
            if [[ -d "$RUN_DIR/cold-run.trace" ]]; then
                local parse_output=$("$SCRIPT_DIR/parse-trace.py" "$RUN_DIR/cold-run.trace" 2>/dev/null)
                cold_runtime_ms=$(echo "$parse_output" | grep "^runtime_ms=" | cut -d= -f2)
                cold_managed_ms=$(echo "$parse_output" | grep "^managed_ms=" | cut -d= -f2)
                echo "  Cold: runtime=${cold_runtime_ms}ms managed=${cold_managed_ms}ms"
            fi
            
            # Warmup run (discarded - ensures caches are truly warm)
            echo "Warmup run (discarded)..."
            xcrun simctl terminate booted "$bundle_id" 2>/dev/null || true
            xcrun xctrace record --template "Time Profiler" \
                --device "$sim_udid" \
                --time-limit 5s \
                --launch -- "$app_bundle" 2>&1 || true
            xcrun simctl terminate booted "$bundle_id" 2>/dev/null || true
            local warmup_trace=$(find . -maxdepth 1 -name "*.trace" -type d 2>/dev/null | head -1)
            [[ -n "$warmup_trace" ]] && rm -rf "$warmup_trace"
            
            # Warm runs (3 iterations, take median)
            echo "Warm runs (3 iterations)..."
            local -a warm_rt=() warm_mg=()
            for i in 1 2 3; do
                xcrun simctl terminate booted "$bundle_id" 2>/dev/null || true
                xcrun xctrace record --template "Time Profiler" \
                    --device "$sim_udid" \
                    --time-limit 5s \
                    --launch -- "$app_bundle" 2>&1 || true
                xcrun simctl terminate booted "$bundle_id" 2>/dev/null || true
                
                local latest_trace=$(find . -maxdepth 1 -name "*.trace" -type d 2>/dev/null | head -1)
                if [[ -n "$latest_trace" && -d "$latest_trace" ]]; then
                    mv "$latest_trace" "warm-run-${i}.trace"
                fi
                
                if [[ -d "$RUN_DIR/warm-run-${i}.trace" ]]; then
                    local parse_output=$("$SCRIPT_DIR/parse-trace.py" "$RUN_DIR/warm-run-${i}.trace" 2>/dev/null)
                    local rt=$(echo "$parse_output" | grep "^runtime_ms=" | cut -d= -f2)
                    local mg=$(echo "$parse_output" | grep "^managed_ms=" | cut -d= -f2)
                    echo "  Warm $i: runtime=${rt}ms managed=${mg}ms"
                    [[ "$rt" != "N/A" ]] && warm_rt+=("$rt")
                    [[ "$mg" != "N/A" ]] && warm_mg+=("$mg")
                fi
            done
            
            # Calculate medians (or use available values if fewer than 3)
            if [[ ${#warm_rt[@]} -ge 1 ]]; then
                if [[ ${#warm_rt[@]} -eq 3 ]]; then
                    warm_runtime_ms=$(median3 "${warm_rt[0]}" "${warm_rt[1]}" "${warm_rt[2]}")
                elif [[ ${#warm_rt[@]} -eq 2 ]]; then
                    warm_runtime_ms=$(( (warm_rt[0] + warm_rt[1]) / 2 ))
                else
                    warm_runtime_ms="${warm_rt[0]}"
                fi
            fi
            if [[ ${#warm_mg[@]} -ge 1 ]]; then
                if [[ ${#warm_mg[@]} -eq 3 ]]; then
                    warm_managed_ms=$(median3 "${warm_mg[0]}" "${warm_mg[1]}" "${warm_mg[2]}")
                elif [[ ${#warm_mg[@]} -eq 2 ]]; then
                    warm_managed_ms=$(( (warm_mg[0] + warm_mg[1]) / 2 ))
                else
                    warm_managed_ms="${warm_mg[0]}"
                fi
            fi
            echo "  Warm (median): runtime=${warm_runtime_ms}ms managed=${warm_managed_ms}ms"
            cd "$SCRIPT_DIR"
            
        else
            # Device - need two different IDs:
            # 1. devicectl uses CoreDevice UUID (8-4-4-4-12 format)
            # 2. xctrace uses ECID-based identifier from xctrace list devices
            local devicectl_id=$(xcrun devicectl list devices 2>/dev/null | grep -i "iPhone" | head -1 | awk '{for(i=1;i<=NF;i++) if($i ~ /^[0-9A-Fa-f-]{36}$/) print $i}')
            local xctrace_id=$(xcrun xctrace list devices 2>/dev/null | grep -i "iPhone" | grep -v "Simulator" | head -1 | grep -oE '\([0-9A-Fa-f-]+\)$' | tr -d '()')
            
            if [[ -n "$devicectl_id" && -n "$xctrace_id" ]]; then
                echo "Using device: $devicectl_id (xctrace: $xctrace_id)"
                echo "Installing app on device..."
                xcrun devicectl device uninstall app --device "$devicectl_id" "$bundle_id" 2>/dev/null || true
                xcrun devicectl device install app --device "$devicectl_id" "$app_bundle" 2>&1 || true
                
                # Cold run
                echo "Cold run..."
                cd "$RUN_DIR"
                xcrun xctrace record --template "Time Profiler" \
                    --device "$xctrace_id" \
                    --time-limit 5s \
                    --launch -- "$app_bundle" 2>&1 || true
                xcrun devicectl device process terminate --device "$devicectl_id" --bundle-id "$bundle_id" 2>/dev/null || true
                
                local latest_trace=$(find . -maxdepth 1 -name "*.trace" -type d 2>/dev/null | head -1)
                if [[ -n "$latest_trace" && -d "$latest_trace" ]]; then
                    mv "$latest_trace" "cold-run.trace"
                fi
                
                if [[ -d "$RUN_DIR/cold-run.trace" ]]; then
                    local parse_output=$("$SCRIPT_DIR/parse-trace.py" "$RUN_DIR/cold-run.trace" 2>/dev/null)
                    cold_runtime_ms=$(echo "$parse_output" | grep "^runtime_ms=" | cut -d= -f2)
                    cold_managed_ms=$(echo "$parse_output" | grep "^managed_ms=" | cut -d= -f2)
                    echo "  Cold: runtime=${cold_runtime_ms}ms managed=${cold_managed_ms}ms"
                fi
                
                # Warm run (caches warm from cold run)
                echo "Warm run..."
                xcrun xctrace record --template "Time Profiler" \
                    --device "$xctrace_id" \
                    --time-limit 5s \
                    --launch -- "$app_bundle" 2>&1 || true
                xcrun devicectl device process terminate --device "$devicectl_id" --bundle-id "$bundle_id" 2>/dev/null || true
                
                local latest_trace=$(find . -maxdepth 1 -name "*.trace" -type d 2>/dev/null | head -1)
                if [[ -n "$latest_trace" && -d "$latest_trace" ]]; then
                    mv "$latest_trace" "warm-run.trace"
                fi
                
                if [[ -d "$RUN_DIR/warm-run.trace" ]]; then
                    local parse_output=$("$SCRIPT_DIR/parse-trace.py" "$RUN_DIR/warm-run.trace" 2>/dev/null)
                    warm_runtime_ms=$(echo "$parse_output" | grep "^runtime_ms=" | cut -d= -f2)
                    warm_managed_ms=$(echo "$parse_output" | grep "^managed_ms=" | cut -d= -f2)
                    echo "  Warm: runtime=${warm_runtime_ms}ms managed=${warm_managed_ms}ms"
                fi
                cd "$SCRIPT_DIR"
            fi
        fi
        
        echo ""
        echo "Cold Startup: runtime=${cold_runtime_ms}ms managed=${cold_managed_ms}ms"
        echo "Warm Startup: runtime=${warm_runtime_ms}ms managed=${warm_managed_ms}ms"
        echo "Run completed"
    fi
    
    # Store results
    RESULT_APP="$app"
    RESULT_RUNTIME="$runtime"
    RESULT_BUILD_TIME="$build_time"
    RESULT_SIZE_MB="$size_mb"
    RESULT_COLD_RUNTIME_MS="$cold_runtime_ms"
    RESULT_COLD_VM_INIT_MS="$cold_vm_init_ms"
    RESULT_COLD_MANAGED_MS="$cold_managed_ms"
    RESULT_WARM_RUNTIME_MS="$warm_runtime_ms"
    RESULT_WARM_VM_INIT_MS="$warm_vm_init_ms"
    RESULT_WARM_MANAGED_MS="$warm_managed_ms"
    
    # Clean build artifacts
    rm -f "$APPS_DIR/$app"/*.binlog 2>/dev/null
    rm -rf "$APPS_DIR/$app/bin" "$APPS_DIR/$app/obj"
    
    printf "%-12s %-10s %8.2fs %10.2f MB\n" "$app" "$runtime" "$build_time" "$size_mb"
}

# Determine app name
[[ "$APP" == "ios" ]] && APP_NAME="SampleiOS" || APP_NAME="SampleMAUI"

# Determine runtime name
case "$RUNTIME" in
    coreclr)   RUNTIME_NAME="CoreCLR" ;;
    mono)      RUNTIME_NAME="Mono" ;;
    nativeaot) RUNTIME_NAME="NativeAOT" ;;
esac

# Run measurement
measure "$APP_NAME" "$RUNTIME_NAME"

# Print results
echo ""
echo "  Results"
echo ""
echo "App          Runtime      Build        Size       Cold (runtime+managed)    Warm (runtime+managed)"
echo "─────────────────────────────────────────────────────────────────────────────────────────────────────"
printf "%-12s %-10s %7.2fs   %7.2f MB          %3s + %-3s ms            %3s + %-3s ms\n" \
    "$RESULT_APP" "$RESULT_RUNTIME" "$RESULT_BUILD_TIME" "$RESULT_SIZE_MB" \
    "$RESULT_COLD_RUNTIME_MS" "$RESULT_COLD_MANAGED_MS" \
    "$RESULT_WARM_RUNTIME_MS" "$RESULT_WARM_MANAGED_MS"

# Generate markdown results
cat > "$RUN_DIR/results.md" << EOF
# Performance Results

**Date:** $(date '+%Y-%m-%d %H:%M:%S')

## Configuration

| Parameter | Value |
|-----------|-------|
| Config | $MSBUILD_CONFIG |
| Runtime | $RUNTIME_NAME |
| App | $APP_NAME |
| Target | $TARGET |

## Results

| Metric | Value |
|--------|-------|
| Build Time | ${RESULT_BUILD_TIME}s |
| Bundle Size | ${RESULT_SIZE_MB} MB |
| **Cold Startup** | |
| - Runtime (xamarin_main → xamarin_initialize) | ${RESULT_COLD_RUNTIME_MS}ms |
| - Managed (xamarin_initialize → FinishedLaunching) | ${RESULT_COLD_MANAGED_MS}ms |
| **Warm Startup (median of 3)** | |
| - Runtime | ${RESULT_WARM_RUNTIME_MS}ms |
| - Managed | ${RESULT_WARM_MANAGED_MS}ms |

## Traces

- \`cold-run.trace\` - First run after install
- \`warm-run-1.trace\`, \`warm-run-2.trace\`, \`warm-run-3.trace\` - Warm runs

Open in Instruments: \`open cold-run.trace\`
EOF

echo "Results saved to: $RUN_DIR"
echo "Done."
