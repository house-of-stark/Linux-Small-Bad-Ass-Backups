#!/bin/bash
# Example: Backup web server configuration and data

# Requires root privileges
if [ "$(id -u)" -ne 0 ]; then
    echo "This script must be run as root"
    exit 1
fi

# Set the backup directory
BACKUP_DIR="/var/backups/webserver"

# Create backup directory if it doesn't exist
mkdir -p "$BACKUP_DIR"

# Run backup of web server files
./backup.sh \
    -d "$BACKUP_DIR" \
    -f "/etc/nginx" \
    -f "/var/www" \
    -f "/etc/letsencrypt" \
    -e AES256 \
    -c 9

echo "Web server backup completed. Files saved to: $BACKUP_DIR"
