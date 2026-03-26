#!/bin/bash
set -e

# Setup local .NET SDK for iOS/MAUI performance testing
# Downloads the latest .NET 11 preview via the official install script and installs workloads

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

DOTNET_DIR="$SCRIPT_DIR/dotnet"
DOTNET="$DOTNET_DIR/dotnet"

echo "Setting up local .NET SDK (latest .NET 11 preview)..."

# Clean previous install
rm -rf "$DOTNET_DIR"

# Install latest .NET 11 preview using the official install script
curl -sSL https://dot.net/v1/dotnet-install.sh | bash /dev/stdin \
    --channel 11.0 --quality preview --install-dir "$DOTNET_DIR"

# Ensure we use this local SDK (not system SDK)
export DOTNET_ROOT="$DOTNET_DIR"
export PATH="$DOTNET_DIR:$PATH"
export DOTNET_MULTILEVEL_LOOKUP=0

echo ""
echo "Installed SDK: $("$DOTNET" --version)"

# Install workloads
echo "Installing iOS and MAUI workloads..."
"$DOTNET" workload install ios maccatalyst maui

echo ""
echo "Setup complete. Installed workloads:"
"$DOTNET" workload list

echo ""
echo "Local SDK ready at: $DOTNET"
