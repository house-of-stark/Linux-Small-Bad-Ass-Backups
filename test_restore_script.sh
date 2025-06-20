#!/bin/bash

# Test script for restore.sh functionality
set -e

BACKUP_FILE=~/backup-test/test-backup-20250620-165525.tar.gpg
RESTORE_DIR=~/test-restore-verify

# Create restore directory
mkdir -p "$RESTORE_DIR"

# Get the passphrase from user
echo "Please enter the passphrase used for the backup:"
read -s passphrase
echo

# Run the restore script
echo "Running restore.sh..."
if ! ./restore.sh -p "$passphrase" "$BACKUP_FILE"; then
    echo "Error: restore.sh failed"
    exit 1
fi

# Check if the restored file exists and has the expected content
echo -e "\nVerifying restored files..."
if [ -f "$RESTORE_DIR/test-restore/test-file.txt" ]; then
    echo "✅ Restored file found at: $RESTORE_DIR/test-restore/test-file.txt"
    echo -e "\nRestored file content:"
    cat "$RESTORE_DIR/test-restore/test-file.txt"
    
    # Verify content matches expected
    if grep -q "This is a test file for restore testing" "$RESTORE_DIR/test-restore/test-file.txt"; then
        echo -e "\n✅ Content verification passed"
    else
        echo -e "\n❌ Content verification failed"
        exit 1
    fi
else
    echo "❌ Restored file not found"
    exit 1
fi

echo -e "\nTest completed successfully!"
echo "Restored files are in: $RESTORE_DIR"
