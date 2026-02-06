#!/bin/bash -eux

# Script to clone, patch, build and install custom macios packs (with DEBUG_LAUNCH_TIME)
# To reset to stock, re-run ./dotnet.sh

set -o pipefail
IFS=$'\n\t'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MACIOS_DIR="$SCRIPT_DIR/macios"
PACK_DIR="$SCRIPT_DIR/dotnet/packs"
INSTALLED_VERSION="26.2.11310-net11-p1"

# =============================================================================
# Step 1: Clone macios repo
# =============================================================================
echo "=== Step 1: Clone macios repo ==="
if [ ! -d "$MACIOS_DIR" ]; then
  git clone https://github.com/dotnet/macios "$MACIOS_DIR"
fi

cd "$MACIOS_DIR"
git fetch origin
git checkout net11.0
git pull origin net11.0

# =============================================================================
# Step 2: Build macios
# =============================================================================
echo "=== Step 2: Build macios ==="

export IGNORE_XCODE_COMPONENTS=1
export IGNORE_SIMULATORS=1

if [[ "${1:-}" != "--skip-build" ]]; then
  git clean -xfd
  
  # Apply patches AFTER git clean
  echo "Applying patches..."
  
  # Patch runtime/runtime-internal.h - enable DEBUG_LAUNCH_TIME
  sed -i '' 's|// #define DEBUG_LAUNCH_TIME|#define DEBUG_LAUNCH_TIME|' runtime/runtime-internal.h
  sed -i '' '/#ifdef DEBUG_LAUNCH_TIME/a\
void debug_launch_time_print (const char *msg);
' runtime/runtime-internal.h

  # Patch runtime/monotouch-main.m - fix integer overflow
  sed -i '' 's|unow = now.tv_sec \* 1000000ULL + now.tv_usec;|unow = (uint64_t) now.tv_sec * 1000000ULL + (uint64_t) now.tv_usec;|' runtime/monotouch-main.m

  # Patch tests/Makefile - disable tests for faster build
  sed -i '' 's|^SUBDIRS=test-libraries dotnet|SUBDIRS=|' tests/Makefile

  # Patch Make.config - use default Xcode.app path
  sed -i '' 's|XCODE_DEVELOPER_ROOT=/Applications/Xcode_26.2.0.app/Contents/Developer|XCODE_DEVELOPER_ROOT=/Applications/Xcode.app/Contents/Developer|' Make.config

  echo "Patches applied"
  
  ./configure --disable-all-platforms --enable-ios --disable-simulator
  make reset
  make all -j8
  
  # Clean install target to avoid "Operation not permitted" errors
  rm -rf "$MACIOS_DIR/_build/Microsoft.iOS.Sdk.net11.0_26.2" 2>/dev/null || true
  
  make install -j8
fi

# =============================================================================
# Step 3: Install packs to local dotnet
# =============================================================================
echo "=== Step 3: Install packs to local dotnet ==="

LOCAL_NUPKGS="$MACIOS_DIR/_build/nupkgs"

# Find the built version
LOCAL_VERSION=$(ls "$LOCAL_NUPKGS"/Microsoft.iOS.Sdk.net11.0_26.2.*.nupkg 2>/dev/null | head -1 | sed 's/.*net11.0_26.2.\(.*\).nupkg/\1/')

if [ -z "$LOCAL_VERSION" ]; then
  echo "Error: No built nupkgs found in $LOCAL_NUPKGS"
  exit 1
fi

echo "Found built version: $LOCAL_VERSION"

PACKS=(
  "Microsoft.iOS.Sdk.net11.0_26.2"
  "Microsoft.iOS.Ref.net11.0_26.2"
  "Microsoft.iOS.Runtime.ios.net11.0_26.2"
  "Microsoft.iOS.Runtime.ios-arm64.net11.0_26.2"
)

for PACK in "${PACKS[@]}"; do
  echo "Processing $PACK..."
  
  NUPKG_NAME="${PACK}.${LOCAL_VERSION}.nupkg"
  if [ -f "$LOCAL_NUPKGS/$NUPKG_NAME" ]; then
    echo "  Installing custom build..."
    TEMP_DIR=$(mktemp -d)
    unzip -q "$LOCAL_NUPKGS/$NUPKG_NAME" -d "$TEMP_DIR"
    
    rm -rf "$PACK_DIR/$PACK/$LOCAL_VERSION" 2>/dev/null || true
    mkdir -p "$PACK_DIR/$PACK/$LOCAL_VERSION"
    cp -r "$TEMP_DIR"/* "$PACK_DIR/$PACK/$LOCAL_VERSION/"
    
    if [ -d "$PACK_DIR/$PACK/$LOCAL_VERSION/tools" ]; then
      echo "  Fixing executable permissions..."
      find "$PACK_DIR/$PACK/$LOCAL_VERSION/tools" -type f \( -name "mlaunch" -o -name "*.exe" -o -path "*/MacOS/*" -o -path "*/bin/*" \) -exec chmod +x {} \;
    fi
    
    rm -rf "$PACK_DIR/$PACK/$INSTALLED_VERSION"
    ln -s "$LOCAL_VERSION" "$PACK_DIR/$PACK/$INSTALLED_VERSION"
    
    rm -rf "$TEMP_DIR"
    echo "  ✓ Installed"
  else
    echo "  ⚠ Package not found: $NUPKG_NAME"
  fi
done

echo ""
echo "=== Custom macios installed successfully! ==="
