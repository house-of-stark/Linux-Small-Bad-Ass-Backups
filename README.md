# Unified# Advanced Backup and Restore Utility

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![CI/CD](https://github.com/house-of-stark/Linux-Small-Bad-Ass-Backups/actions/workflows/ci.yml/badge.svg)](https://github.com/house-of-stark/Linux-Small-Bad-Ass-Backups/actions/workflows/ci.yml)

A robust and efficient backup and restore solution for Linux systems, featuring encryption, compression, and flexible backup strategies.

## Features

- 🔒 **Secure Encryption**: AES-128/256 encryption for your backups
- 🚀 **Fast Compression**: Uses `pigz` for parallel compression (falls back to `gzip`)
- 📁 **Flexible Backups**: Backup specific files, directories, or system configurations
- 🔄 **Incremental Backups**: Option to perform incremental backups to save space
- 📊 **Logging**: Detailed logging for troubleshooting and monitoring
- 🔄 **Restore Capability**: Easy restoration of backups with verification
- 🛡️ **Integrity Checks**: MD5 checksums for backup verification
- 🧩 **Modular Design**: Easy to extend with custom backup modules
- 🐧 **Linux Optimized**: Built specifically for Linux systems

## Table of Contents

- [Installation](#installation)
- [Quick Start](#quick-start)
- [Usage](#usage)
  - [Backup Options](#backup-options)
  - [Restore Options](#restore-options)
- [Configuration](#configuration)
- [Examples](#examples)
- [Best Practices](#best-practices)
- [Contributing](#contributing)
- [License](#license)

## Installation

### Prerequisites

- Bash 4.0 or higher
- Core utilities: `tar`, `gzip`/`pigz`, `gpg`
- Optional: `pv` for progress display

### Installation Steps

1. Clone the repository:
   ```bash
   git clone https://github.com/house-of-stark/Linux-Small-Bad-Ass-Backups.git
   cd Linux-Small-Bad-Ass-Backups
   ```

2. Make the scripts executable:
   ```bash
   chmod +x backup.sh restore.sh test_*.sh
   ```

3. (Optional) Install system-wide:
   ```bash
   sudo cp backup.sh /usr/local/bin/backup-utility
   sudo cp restore.sh /usr/local/bin/restore-utility
   ```

## Quick Start

### Basic Backup

```bash
./backup.sh -d /path/to/backup/directory -f /path/to/backup/file1 /path/to/dir
```

### Basic Restore

```bash
./restore.sh -s /path/to/backup/file.tar.gz.gpg -d /restore/path
```

## Usage

### Backup Options

```
Usage: backup.sh [OPTIONS]

Options:
  -d, --destination DIR   Backup destination directory (required)
  -f, --files FILE|DIR...  Files or directories to backup (space-separated)
  -e, --encrypt ALGORITHM  Encryption algorithm (AES128, AES256) [default: AES128]
  -c, --compression LEVEL  Compression level (1-9) [default: 6]
  -i, --incremental        Perform incremental backup
  -q, --quiet              Suppress non-error output
  -v, --verbose            Show detailed output
  -h, --help               Show this help message

Examples:
  # Backup home directory with default settings
  backup.sh -d /backups -f $HOME

  # Backup specific directories with strong encryption
  backup.sh -d /backups -f /etc /var/www -e AES256
```

### Restore Options

```
Usage: restore.sh [OPTIONS]

Options:
  -s, --source FILE     Source backup file to restore (required)
  -d, --destination DIR  Destination directory for restoration [default: .]
  -k, --key FILE        GPG key file for decryption
  -q, --quiet           Suppress non-error output
  -v, --verbose         Show detailed output
  -h, --help            Show this help message

Examples:
  # Restore a backup to the current directory
  restore.sh -s /backups/home-backup-20230620.tar.gz.gpg

  # Restore to a specific directory
  restore.sh -s /backups/etc-backup.tar.gz.gpg -d /etc
```

## Configuration

### Environment Variables

You can configure the backup utility using environment variables:

```bash
# Encryption settings
export ENCRYPTION_CIPHER="AES256"  # AES128 or AES256
export PASSPHRASE="your-secure-passphrase"  # Not recommended for production

# Compression settings
export COMPRESSOR="pigz"  # pigz or gzip
export GZIP_LEVEL=6  # 1-9, higher = better compression but slower

# Backup settings
export BACKUP_DIR="/backups"
export LOG_LEVEL="INFO"  # DEBUG, INFO, WARNING, ERROR
```

### Configuration File

Create a `backup.conf` file in the script directory or `/etc/backup-utility/`:

```ini
# Backup configuration
BACKUP_DIR="/backups"
ENCRYPTION_CIPHER="AES256"
COMPRESSOR="pigz"
GZIP_LEVEL=6
LOG_LEVEL="INFO"
```

## Examples

### Backup Examples

1. **Basic Backup**:
   ```bash
   ./backup.sh -d /mnt/backup -f /home/user/Documents
   ```

2. **System Backup (requires root)**:
   ```bash
   sudo ./backup.sh -d /backups -f /etc /var/www --encrypt AES256
   ```

3. **Incremental Backup**:
   ```bash
   ./backup.sh -d /backups -f /home -i
   ```

### Restore Examples

1. **Basic Restore**:
   ```bash
   ./restore.sh -s /backups/home-20230620.tar.gz.gpg -d /home/restored
   ```

2. **Verify Backup**:
   ```bash
   ./restore.sh -s /backups/etc-20230620.tar.gz.gpg --verify-only
   ```

## Best Practices

1. **Regular Backups**: Set up a cron job for regular backups
   ```bash
   # Daily backup at 2 AM
   0 2 * * * /path/to/backup.sh -d /backups -f /home /etc
   ```

2. **Secure Storage**: Store encryption keys separately from backups

3. **Test Restores**: Periodically test restoring from backups

4. **Monitor Space**: Ensure backup destination has sufficient space

5. **Log Rotation**: Configure log rotation for backup logs

## Contributing

Contributions are welcome! Please read our [Contributing Guidelines](https://github.com/house-of-stark/Linux-Small-Bad-Ass-Backups/blob/main/CONTRIBUTING.md) for details.

1. Fork the repository
2. Create a feature branch
3. Commit your changes
4. Push to the branch
5. Create a new Pull Request

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

Created with ❤️ by [house-of-stark](https://github.com/house-of-stark)

# Unified Backup and Restore Scripts

A comprehensive and secure backup and restore solution for Linux systems that combines the best features of multiple backup scripts into one powerful tool.

## Features

- **Unified Solution**: Combines functionality from multiple backup scripts into one
- **Secure Encryption**: Uses GPG with AES-256 encryption
- **Flexible Backups**: Customize what to back up (system files, packages, home directory)
- **Easy Restoration**: Dedicated restore script for all backup types
- **Detailed Logging**: Color-coded logging for better readability
- **Self-Testing**: Built-in encryption test functionality
- **Command-Line Options**: Flexible configuration via command-line arguments

## Why This Backup Strategy?

This script implements an efficient backup and restore strategy that focuses on what matters most:

1. **Configuration Files**: Backs up system and application configurations which are small but time-consuming to recreate.
2. **Package Lists**: Instead of backing up installed packages (which can be large), it saves the list of installed packages for easy reinstallation.
3. **User Data**: Backs up your home directory where personal files and application data are stored.

### Benefits:
- **Space Efficient**: Saves disk space by not backing up system files that can be reinstalled.
- **Fast Operations**: Smaller backup size means quicker backup and restore operations.
- **Clean Restores**: Reinstalling packages ensures you get fresh, up-to-date versions.
- **Secure**: All backups are encrypted with strong encryption.
- **Customizable**: Easily add or remove directories and files to fit your needs.
- **Reliable**: Built-in verification ensures backups can be restored when needed.

## Requirements

- Linux-based operating system (tested on Debian/Ubuntu)
- `gpg` (GNU Privacy Guard)
- `tar`
- `dpkg` (for package management)
- `bash` (version 4.0 or later)
- Basic utilities: `grep`, `sed`, `awk`, `find`

## Installation

1. Make the scripts executable:
   ```bash
   chmod +x backup.sh restore.sh
   ```

2. (Optional) Create symlinks in your PATH:
   ```bash
   sudo ln -s $(pwd)/backup.sh /usr/local/bin/backup
   sudo ln -s $(pwd)/restore.sh /usr/local/bin/restore
   ```

## Backup Usage

Run the backup script with options:

```bash
./backup.sh [OPTIONS] [TYPES...]
```

### Options:
- `-h, --help`: Show help message
- `-d, --dir DIR`: Specify backup directory (default: ~/backup)
- `-p, --passphrase PASSPHRASE`: Set encryption passphrase (not recommended for security)
- `-y, --yes`: Skip confirmation prompts
- `-v, --version`: Show version information

### Backup Types:
- `home`: Back up home directory
- `packages`: Back up installed packages list
- `system`: Back up system files
- `all`: Back up everything (default if no types specified)

### Examples:

```bash
# Create a full backup with all types
./backup.sh

# Backup only home directory with a specific passphrase
./backup.sh -p "mysecretpass" home

# Backup packages and system files to a custom directory
./backup.sh -d /mnt/backup packages system
```

## Restore Usage

The restore script allows you to restore your system from previously created backups.

```bash
./restore.sh [OPTIONS] <backup_file>
```

### Options:
- `-h, --help`: Show help message
- `-p, --passphrase PASSPHRASE`: Provide decryption passphrase (will prompt if not provided)
- `-y, --yes`: Skip confirmation prompts

### Examples:

```bash
# Restore home directory (will prompt for passphrase)
./restore.sh ~/backup/backup_20230620-123456_home.tar.gpg

# Restore packages with a specific passphrase
./restore.sh -p "mysecretpass" backup_20230620-123456_packages.list.gpg

# Restore system files (requires root)
sudo ./restore.sh backup_20230620-123456_system.tar.gpg
```

### Restore Notes:
1. **Home Directory**: Will restore files to their original locations, potentially overwriting existing files.
2. **Packages**: Will reinstall all packages from the backup list using `apt-get`.
3. **System Files**: Requires root privileges. Be cautious as this will overwrite existing system configuration files.
4. **Encryption**: The same passphrase used for backup is required for restoration.

## Usage

### Basic Usage

```bash
./backup.sh
```

You will be prompted to enter a passphrase for encryption.

### Command Line Options

```
-d, --dir DIR       Set backup directory (default: ~/backup)
-p, --passphrase    Prompt for encryption passphrase
-f, --files FILES   Additional files to backup (comma-separated)
-t, --test          Run encryption test only
-h, --help          Show this help message
-v, --version       Show version information
```

### Examples

1. Run a standard backup:
   ```bash
   ./backup.sh
   ```

2. Specify a custom backup directory:
   ```bash
   ./backup.sh -d /mnt/backup
   ```

3. Add additional files to back up:
   ```bash
   ./backup.sh -f "/etc/nginx/nginx.conf,/etc/mysql/my.cnf"
   ```

4. Test encryption functionality:
   ```bash
   ./backup.sh --test
   ```

## Default Backed Up Files

By default, the script backs up these system files:
- `/etc/hosts`
- `/etc/fstab`
- `/etc/crontab`
- `/etc/ssh/sshd_config`

## Security Notes

- Always use a strong passphrase for encryption
- The backup directory should be on an encrypted filesystem for additional security
- Consider using a password manager to store your encryption passphrase
- Test your backups regularly to ensure they can be restored

## License

MIT License - see the [LICENSE](LICENSE) file for details.
```

### Examples

1. **Basic backup with passphrase prompt:**
   ```bash
   ./backup_configs_enhanced.sh
   ```

2. **Specify backup directory:**
   ```bash
   ./backup_configs_enhanced.sh -d /mnt/external/backups
   ```

3. **Skip home directory backup:**
   ```bash
   ./backup_configs_enhanced.sh --skip-home
   ```

4. **Non-interactive mode (not recommended for security):**
   ```bash
   ./backup_configs_enhanced.sh -p "your-secure-passphrase"
   ```

## Backup Contents

The backup includes:

1. **System Files**
   - `/etc/hosts`
   - `/etc/hostname`
   - `/etc/fstab`
   - `/etc/network/interfaces`
   - `/etc/resolv.conf`
   - `/etc/apt/sources.list` and `/etc/apt/sources.list.d/`

2. **Package Management**
   - List of installed packages (`Package.list`)
   - List of automatically installed packages (`PackageAuto.list`)
   - List of manually installed packages (`PackageManual.list`)

3. **Home Directory** (optional, can be skipped with `-s`)
   - All hidden files and directories in your home folder

## Restore Instructions

### Restoring System Files

1. Decrypt the system files backup:
   ```bash
   gpg -o system-backup.tar.gz -d system-files-*.tar.gz.gpg
   ```

2. Extract the files (as root):
   ```bash
   sudo tar xzf system-backup.tar.gz -C /
   ```

### Restoring Packages

1. Update package lists:
   ```bash
   sudo apt-get update
   ```

2. Install the package lists:
   ```bash
   sudo dpkg --set-selections < Package.list
   sudo apt-get dselect-upgrade -y
   ```

### Restoring Home Directory

1. Decrypt the home directory backup:
   ```bash
   gpg -o home-backup.tar.gz -d home-backup-*.tar.gz.gpg
   ```

2. Extract the files (be careful not to overwrite existing files):
   ```bash
   tar xzf home-backup.tar.gz -C ~/
   ```

## Security Considerations

1. **Passphrase Security**
   - Never store your passphrase in scripts or version control
   - Use a strong, unique passphrase
   - Consider using `gpg-agent` for automated backups

2. **Backup Storage**
   - Store backups in a secure location
   - Consider encrypting the entire backup directory
   - Keep multiple backup versions

3. **Permissions**
   - The script requires root access for system file backups
   - Run with minimal necessary privileges

## Troubleshooting

### Common Issues

1. **Permission Denied Errors**
   - Run the script with `sudo` for system file backups
   - Ensure you have write permissions for the backup directory

2. **GPG Errors**
   - Ensure GPG is installed: `sudo apt-get install gnupg`
   - Check for existing GPG agent issues: `gpgconf --kill all`

3. **Empty Backups**
   - Check if the source files exist
   - Verify you have read permissions for the files

## License

MIT License - See [LICENSE](LICENSE) for details.

## Contributing

Contributions are welcome! Please open an issue or submit a pull request.

## Author

Backup Utility - Chris Stark  

---

*Last updated: June 2025*
