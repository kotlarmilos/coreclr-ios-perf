#!/bin/bash -e

# Script to install local iOS SDK build by replacing installed packs

# Dynamically locate macios build directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOCAL_NUPKGS="$(cd "$SCRIPT_DIR/../macios/_build/nupkgs" && pwd)"

if [ ! -d "$LOCAL_NUPKGS" ]; then
  echo "Error: Local nupkgs directory not found at $LOCAL_NUPKGS"
  echo "Please build macios first using ./scripts/build-macios.sh"
  exit 1
fi

PACK_DIR="/usr/local/share/dotnet/packs"
LOCAL_VERSION="26.1.10554-ci.feature-coreclr-r2r"
INSTALLED_VERSION="26.1.10494"
BACKUP_DIR="/tmp/ios-sdk-backup-${INSTALLED_VERSION}"

echo "=== Installing local iOS SDK ${LOCAL_VERSION} ==="

# Create backup directory
sudo mkdir -p "$BACKUP_DIR"

# List of packs to replace
PACKS=(
  "Microsoft.iOS.Sdk.net10.0_26.1"
  "Microsoft.iOS.Ref.net10.0_26.1"
  "Microsoft.iOS.Runtime.ios.net10.0_26.1"
  "Microsoft.iOS.Runtime.ios-arm64.net10.0_26.1"
)

for PACK in "${PACKS[@]}"; do
  echo "Processing $PACK..."
  
  # Backup original if not already backed up
  if [ -d "$PACK_DIR/$PACK/$INSTALLED_VERSION" ] && [ ! -d "$BACKUP_DIR/$PACK" ]; then
    echo "  Backing up original..."
    sudo cp -r "$PACK_DIR/$PACK/$INSTALLED_VERSION" "$BACKUP_DIR/$PACK"
  fi
  
  # Extract and install local build
  NUPKG_NAME="${PACK}.${LOCAL_VERSION}.nupkg"
  if [ -f "$LOCAL_NUPKGS/$NUPKG_NAME" ]; then
    echo "  Installing local build..."
    TEMP_DIR=$(mktemp -d)
    unzip -q "$LOCAL_NUPKGS/$NUPKG_NAME" -d "$TEMP_DIR"
    
    # Remove old local version if exists
    sudo rm -rf "$PACK_DIR/$PACK/$LOCAL_VERSION" 2>/dev/null || true
    
    # Install new local version
    sudo mkdir -p "$PACK_DIR/$PACK/$LOCAL_VERSION"
    sudo cp -r "$TEMP_DIR"/* "$PACK_DIR/$PACK/$LOCAL_VERSION/"
    
    # Fix permissions for all executables in tools directory
    if [ -d "$PACK_DIR/$PACK/$LOCAL_VERSION/tools" ]; then
      echo "  Fixing executable permissions..."
      # Fix all shell scripts and executables in bin
      sudo find "$PACK_DIR/$PACK/$LOCAL_VERSION/tools/bin" -type f -exec chmod +x {} \; 2>/dev/null || true
      # Fix all MacOS executables in app bundles
      sudo find "$PACK_DIR/$PACK/$LOCAL_VERSION/tools/lib" -type d -name "MacOS" -exec sh -c 'chmod +x "$0"/*' {} \; 2>/dev/null || true
    fi
    
    # Replace installed version with symlink to local version
    sudo rm -rf "$PACK_DIR/$PACK/$INSTALLED_VERSION"
    sudo ln -s "$LOCAL_VERSION" "$PACK_DIR/$PACK/$INSTALLED_VERSION"
    
    rm -rf "$TEMP_DIR"
    echo "  Installed"
  else
    echo "  Package not found: $NUPKG_NAME"
  fi
done

echo ""
echo "=== Local iOS SDK installed successfully! ==="
echo "Backup location: $BACKUP_DIR"
echo "To restore original, run: ./scripts/restore-local-ios-sdk.sh"
