#!/bin/bash
# Example: Backup home directory

# Set the backup directory
BACKUP_DIR="/mnt/backup"

# Create backup directory if it doesn't exist
mkdir -p "$BACKUP_DIR"

# Run backup
./backup.sh -d "$BACKUP_DIR" -f "$HOME"

echo "Backup completed. Files saved to: $BACKUP_DIR"
