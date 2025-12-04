#!/bin/bash -e

# Script to restore original CoreCLR runtime pack

PACK_DIR="/usr/local/share/dotnet/packs"
RUNTIME_VERSION="10.0.0-dev"
INSTALLED_VERSION="10.0.0"
BACKUP_DIR="/tmp/coreclr-runtime-backup-${INSTALLED_VERSION}"

echo "=== Restoring original CoreCLR runtime ${INSTALLED_VERSION} ==="

if [ ! -d "$BACKUP_DIR" ]; then
  echo "Error: Backup not found at $BACKUP_DIR"
  echo "The original version may not have been backed up."
  exit 1
fi

RUNTIME_PACK="Microsoft.NETCore.App.Runtime.ios-arm64"

echo "Restoring $RUNTIME_PACK..."

if [ -d "$BACKUP_DIR/$RUNTIME_PACK" ]; then
  # Remove symlink
  sudo rm -f "$PACK_DIR/$RUNTIME_PACK/$INSTALLED_VERSION"
  
  # Restore original
  sudo cp -r "$BACKUP_DIR/$RUNTIME_PACK" "$PACK_DIR/$RUNTIME_PACK/$INSTALLED_VERSION"
  
  # Remove local version
  sudo rm -rf "$PACK_DIR/$RUNTIME_PACK/$RUNTIME_VERSION" 2>/dev/null || true
  
  echo "  Restored"
else
  echo "  Backup not found for $RUNTIME_PACK"
fi

echo ""
echo "=== Original CoreCLR runtime restored successfully! ==="
echo "You can now remove the backup: sudo rm -rf $BACKUP_DIR"
