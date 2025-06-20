#!/bin/bash

# Test script for restore functionality
set -e

# Create test directory and file
echo "Creating test file..."
mkdir -p ~/test-restore
echo "This is a test file for restore testing" > ~/test-restore/test-file.txt

# Create a backup of just the test file
echo "Creating backup of test file..."
mkdir -p ~/backup-test
BACKUP_FILE=~/backup-test/test-backup-$(date +%Y%m%d-%H%M%S).tar.gpg

echo "Please enter a passphrase for the backup (remember it for restore):"
read -s passphrase
echo

# Create encrypted backup
echo "Creating encrypted backup..."
tar -czf - -C ~ test-restore | gpg --batch --yes --passphrase "$passphrase" -c -o "$BACKUP_FILE"

# Verify backup was created
if [ ! -f "$BACKUP_FILE" ]; then
    echo "Error: Backup file was not created"
    exit 1
fi

echo -e "\nBackup created at: $BACKUP_FILE"
echo "Original file content:"
cat ~/test-restore/test-file.txt

# Now test restore
echo -e "\nTesting restore..."
RESTORE_DIR=~/test-restore-restored
mkdir -p "$RESTORE_DIR"

# Decrypt and extract
echo "Decrypting and extracting backup..."
gpg --batch --passphrase "$passphrase" -d "$BACKUP_FILE" | tar -xzf - -C "$RESTORE_DIR"

echo -e "\nRestored file content:"
cat "$RESTORE_DIR/test-restore/test-file.txt"

# Verify the restored file matches the original
if diff -q ~/test-restore/test-file.txt "$RESTORE_DIR/test-restore/test-file.txt" > /dev/null; then
    echo -e "\n✅ Test passed: Restored file matches original"
else
    echo -e "\n❌ Test failed: Restored file does not match original"
    exit 1
fi

# Clean up (comment these lines if you want to inspect the files)
echo -e "\nCleaning up test files..."
rm -rf ~/test-restore ~/test-restore-restored

# Leave the backup file for inspection
echo "Backup file kept at: $BACKUP_FILE"
echo -e "\nTest completed successfully!"
