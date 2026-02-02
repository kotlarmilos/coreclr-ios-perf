#!/bin/bash
set -e

# Setup local .NET SDK for iOS/MAUI performance testing
# This script downloads and configures a local SDK with iOS and MAUI workloads

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

SDK_VERSION="11.0.100-preview.1.26076.102"
SDK_TARBALL="dotnet-sdk-${SDK_VERSION}-osx-arm64.tar.gz"
SDK_URL="https://ci.dot.net/public/Sdk/${SDK_VERSION}/${SDK_TARBALL}"
DOTNET_DIR="$SCRIPT_DIR/dotnet"
DOTNET="$DOTNET_DIR/dotnet"

echo "Setting up local .NET SDK ${SDK_VERSION}..."

# Download SDK if not present
if [[ ! -f "$SDK_TARBALL" ]]; then
    echo "Downloading SDK..."
    curl -LO "$SDK_URL"
fi

# Always extract fresh to ensure clean state
echo "Extracting SDK..."
rm -rf "$DOTNET_DIR"
mkdir -p "$DOTNET_DIR"
tar -xzf "$SDK_TARBALL" -C "$DOTNET_DIR"

# Ensure we use this local SDK (not system SDK)
export DOTNET_ROOT="$DOTNET_DIR"
export PATH="$DOTNET_DIR:$PATH"
export DOTNET_MULTILEVEL_LOOKUP=0

# Install workloads
echo "Installing iOS and MAUI workloads..."
"$DOTNET" workload install ios maccatalyst maui --from-rollback-file "$SCRIPT_DIR/rollback.json"

echo ""
echo "Setup complete. Installed workloads:"
"$DOTNET" workload list

echo ""
echo "Local SDK ready at: $DOTNET"
