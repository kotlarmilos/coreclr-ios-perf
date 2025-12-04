#!/bin/bash -e

# Script to install custom CoreCLR runtime pack for iOS

# Dynamically locate runtime build directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RUNTIME_PACKAGES="$(cd "$SCRIPT_DIR/../runtime/artifacts/packages/Release/Shipping" && pwd)"

if [ ! -d "$RUNTIME_PACKAGES" ]; then
  echo "Error: Runtime packages directory not found at $RUNTIME_PACKAGES"
  echo "Please build runtime first using ./scripts/build-runtime.sh"
  exit 1
fi

PACK_DIR="/usr/local/share/dotnet/packs"
RUNTIME_VERSION="10.0.0-dev"
INSTALLED_VERSION="10.0.0"
BACKUP_DIR="/tmp/coreclr-runtime-backup-${INSTALLED_VERSION}"

echo "=== Installing custom CoreCLR runtime for iOS ==="

# Create backup directory
sudo mkdir -p "$BACKUP_DIR"

# Install CoreCLR runtime pack for ios-arm64
RUNTIME_PACK="Microsoft.NETCore.App.Runtime.ios-arm64"
NUPKG_FILE="${RUNTIME_PACK}.${RUNTIME_VERSION}.nupkg"

if [ -f "$RUNTIME_PACKAGES/$NUPKG_FILE" ]; then
  echo "Installing $RUNTIME_PACK..."
  
  # Backup original if not already backed up
  if [ -d "$PACK_DIR/$RUNTIME_PACK/$INSTALLED_VERSION" ] && [ ! -d "$BACKUP_DIR/$RUNTIME_PACK" ]; then
    echo "  Backing up original..."
    sudo cp -r "$PACK_DIR/$RUNTIME_PACK/$INSTALLED_VERSION" "$BACKUP_DIR/$RUNTIME_PACK"
  fi
  
  # Create target directory
  sudo mkdir -p "$PACK_DIR/$RUNTIME_PACK/$RUNTIME_VERSION"
  
  # Extract the package
  TEMP_DIR=$(mktemp -d)
  unzip -q "$RUNTIME_PACKAGES/$NUPKG_FILE" -d "$TEMP_DIR"
  
  # Copy to packs directory
  sudo cp -r "$TEMP_DIR"/* "$PACK_DIR/$RUNTIME_PACK/$RUNTIME_VERSION/"
  
  # Replace installed version with symlink to local version
  sudo rm -rf "$PACK_DIR/$RUNTIME_PACK/$INSTALLED_VERSION"
  sudo ln -s "$RUNTIME_VERSION" "$PACK_DIR/$RUNTIME_PACK/$INSTALLED_VERSION"
  
  rm -rf "$TEMP_DIR"
  echo "✓ Installed $RUNTIME_PACK version $RUNTIME_VERSION"
else
  echo "Error: Runtime package not found at $RUNTIME_PACKAGES/$NUPKG_FILE"
  echo "Make sure you've built the runtime with the correct configuration."
  exit 1
fi

echo ""
echo "=== Custom CoreCLR runtime installed successfully! ==="
echo "Backup location: $BACKUP_DIR"
echo "To restore original, run: ./scripts/restore-local-coreclr.sh"