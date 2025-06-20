#!/bin/bash
# Example: Restore a backup

# Set the backup file and restore directory
BACKUP_FILE="$1"
RESTORE_DIR="${2:-./restored}"

# Check if backup file exists
if [ -z "$BACKUP_FILE" ] || [ ! -f "$BACKUP_FILE" ]; then
    echo "Usage: $0 <backup_file> [restore_directory]"
    echo "Error: Backup file not found: $BACKUP_FILE"
    exit 1
fi

# Create restore directory if it doesn't exist
mkdir -p "$RESTORE_DIR"

# Run restore
./restore.sh -s "$BACKUP_FILE" -d "$RESTORE_DIR"

echo "Restore completed. Files restored to: $RESTORE_DIR"
