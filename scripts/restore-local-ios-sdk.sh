#!/bin/bash -e

# Script to restore original iOS SDK packs

PACK_DIR="/usr/local/share/dotnet/packs"
LOCAL_VERSION="26.1.10554-ci.feature-coreclr-r2r"
INSTALLED_VERSION="26.1.10494"
BACKUP_DIR="/tmp/ios-sdk-backup-${INSTALLED_VERSION}"

echo "=== Restoring original iOS SDK ${INSTALLED_VERSION} ==="

if [ ! -d "$BACKUP_DIR" ]; then
  echo "Error: Backup not found at $BACKUP_DIR"
  echo "The original version may not have been backed up."
  exit 1
fi

# List of packs to restore
PACKS=(
  "Microsoft.iOS.Sdk.net10.0_26.1"
  "Microsoft.iOS.Ref.net10.0_26.1"
  "Microsoft.iOS.Runtime.ios.net10.0_26.1"
  "Microsoft.iOS.Runtime.ios-arm64.net10.0_26.1"
)

for PACK in "${PACKS[@]}"; do
  echo "Restoring $PACK..."
  
  if [ -d "$BACKUP_DIR/$PACK" ]; then
    # Remove symlink
    sudo rm -rf "$PACK_DIR/$PACK/$INSTALLED_VERSION"
    
    # Restore original
    sudo cp -r "$BACKUP_DIR/$PACK" "$PACK_DIR/$PACK/$INSTALLED_VERSION"
    
    # Remove local version
    sudo rm -rf "$PACK_DIR/$PACK/$LOCAL_VERSION" 2>/dev/null || true
    
    echo "  Restored"
  else
    echo "  Backup not found for $PACK"
  fi
done

echo ""
echo "=== Original iOS SDK restored successfully! ==="
echo "You can now remove the backup: sudo rm -rf $BACKUP_DIR"
