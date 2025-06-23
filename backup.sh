#!/bin/bash

# =============================================================================
# Unified Backup Script
# =============================================================================
# Description: Creates encrypted backups of system files, package lists, and home directories
# Version: 3.0.0
# License: MIT
# =============================================================================

set -euo pipefail

# =============================================================================
# Configuration
# =============================================================================
VERSION="3.0.0"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
DEFAULT_BACKUP_DIR="${BACKUP_DIR:-$HOME/backup}"
TEMP_DIR=$(mktemp -d)
trap 'cleanup' EXIT

# Performance settings
NUM_CORES=$(nproc 2>/dev/null || sysctl -n hw.ncpu 2>/dev/null || echo 2)
COMPRESSOR="pigz"
GZIP_LEVEL=6  # 1=fastest, 9=best compression
ENCRYPTION_CIPHER="AES128"  # AES128 is faster than AES256 with minimal security trade-off
ENCRYPTION_OPTIONS="--batch --yes --compress-level $GZIP_LEVEL --cipher-algo $ENCRYPTION_CIPHER --s2k-count 65011712 --s2k-digest-algo SHA512"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default files to backup
DEFAULT_HOST_FILES=(
    "/etc/hosts"
    "/etc/fstab"
    "/etc/crontab"
    "/etc/ssh/sshd_config"
)

# =============================================================================
# Logging Functions
# =============================================================================
log_info() {
    echo -e "${BLUE}[INFO]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

log_warning() {
    echo -e "${YELLOW}[WARN]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1" >&2
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1" >&2
    exit 1
}

# =============================================================================
# Helper Functions
# =============================================================================
cleanup() {
    # Only clean up if TEMP_DIR is set and exists
    if [ -n "$TEMP_DIR" ] && [ -d "$TEMP_DIR" ]; then
        log_info "Cleaning up temporary files in $TEMP_DIR"
        rm -rf "$TEMP_DIR"
        if [ $? -eq 0 ]; then
            log_info "Temporary files cleaned up successfully"
        else
            log_warning "Failed to clean up some temporary files"
        fi
    fi
}

# Set up trap to ensure cleanup runs on script exit
trap 'exit_status=$?; cleanup; exit $exit_status' EXIT
# Also clean up on error
trap 'log_error "Script interrupted"; cleanup; exit 1' INT TERM

check_sudo() {
    local files=("$@")
    local needs_sudo=0
    
    for file in "${files[@]}"; do
        # Skip empty entries
        [ -z "$file" ] && continue
        
        # Check if file exists and is not readable by current user
        if [ -e "$file" ] && [ ! -r "$file" ]; then
            needs_sudo=1
            break
        fi
    done
    
    # If we need sudo and don't have it, request sudo access
    if [ $needs_sudo -eq 1 ] && [ "$(id -u)" -ne 0 ]; then
        log_info "Elevated privileges required for accessing system files"
        if ! sudo -v; then
            log_error "Failed to get sudo privileges"
            return 1
        fi
        # If we got here, we have sudo access
        return 0
    fi
    
    # If we don't need sudo or already have root, return success
    return 0
}

check_requirements() {
    local required_commands=("tar" "gzip" "gpg" "du")
    local recommended_commands=("pigz" "pv")
    local missing_commands=()
    
    # Check for required commands
    for cmd in "${required_commands[@]}"; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            missing_commands+=("$cmd")
        fi
    done
    
    # Check for recommended commands
    for cmd in "${recommended_commands[@]}"; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            log_warning "Recommended command not found: $cmd. Performance may be affected."
            
            # Special handling for pigz
            if [ "$cmd" = "pigz" ]; then
                log_warning "Install pigz for parallel compression: sudo apt-get install pigz"
            fi
        fi
    done
    
    # Check for missing required commands
    if [ ${#missing_commands[@]} -gt 0 ]; then
        log_error "Missing required commands: ${missing_commands[*]}"
        log_error "Please install the missing commands and try again."
        
        # Provide installation commands for missing packages
        local install_cmd="sudo apt-get install"
        for cmd in "${missing_commands[@]}"; do
            case $cmd in
                gpg) install_cmd+=" gnupg" ;;
                *) install_cmd+=" $cmd" ;;
            esac
        done
        
        log_info "You can install missing packages with: $install_cmd"
        return 1
    fi
    
    # Set PV_CMD based on availability of pv
    if ! command -v pv >/dev/null 2>&1; then
        PV_CMD="cat"
        log_info "pv not found. Progress bar will not be displayed. Install with: sudo apt-get install pv"
    else
        PV_CMD="pv -p -t -e -r -b -a"
    fi
    
    log_info "All requirements check passed successfully"
    return 0
}

prompt_confirm() {
    while true; do
        read -rp "$1 [y/N] " response
        case "$response" in
            [yY][eE][sS]|[yY]) 
                return 0
                ;;
            * )
                return 1
                ;;
        esac
    done
}

prompt_passphrase() {
    # If PASSPHRASE is already set in the environment, use it
    if [ -n "${PASSPHRASE:-}" ]; then
        log_info "Using passphrase from environment variable"
        # Ensure it's exported for child processes
        export PASSPHRASE
        return 0
    fi
    
    # Check if we're running in a non-interactive environment or if input is piped
    if [ ! -t 0 ] || [ ! -t 1 ]; then
        log_info "Running in non-interactive mode"
        
        # First check if we can read from /dev/tty (for sudo)
        if [ -t 0 ] && [ -r /dev/tty ]; then
            log_info "Attempting to read passphrase from /dev/tty"
            if read -r -t 10 PASSPHRASE </dev/tty 2>/dev/null; then
                if [ -n "$PASSPHRASE" ]; then
                    log_info "Successfully read passphrase from /dev/tty"
                    export PASSPHRASE
                    return 0
                fi
            fi
        fi
        
        # If that failed, try reading from stdin
        log_info "Attempting to read passphrase from stdin"
        if read -r -t 5 PASSPHRASE; then
            if [ -n "$PASSPHRASE" ]; then
                log_info "Successfully read passphrase from stdin"
                export PASSPHRASE
                return 0
            fi
        fi
        
        log_error "Failed to read passphrase in non-interactive mode"
        return 1
    fi
    
    # Interactive mode - only reach here if running interactively
    log_info "Running in interactive mode, prompting for passphrase"
    local passphrase passphrase_confirm
    
    while true; do
        # Read first passphrase
        while true; do
            read -rsp "Enter passphrase for encryption (min 8 chars): " passphrase
            echo
            if [ -z "$passphrase" ]; then
                echo "Passphrase cannot be empty"
                continue
            fi
            if [ "${#passphrase}" -lt 8 ]; then
                echo "Passphrase must be at least 8 characters"
                continue
            fi
            break
        done
        
        # Read confirmation
        read -rsp "Confirm passphrase: " passphrase_confirm
        echo
        
        if [ "$passphrase" = "$passphrase_confirm" ]; then
            PASSPHRASE="$passphrase"
            export PASSPHRASE
            log_info "Passphrase set successfully"
            break
        else
            echo "Passphrases do not match. Please try again."
        fi
    done
    
    return 0
}

encrypt_file() {
    local input_file="$1"
    local output_file="$2"
    
    if [ ! -f "$input_file" ]; then
        log_warning "File not found: $input_file"
        return 1
    fi
    
    log_info "Encrypting $input_file using $ENCRYPTION_CIPHER..."
    
    # Use a temporary file for encrypted output to avoid partial files
    local temp_output="${output_file}.tmp"
    
    # Use simpler encryption settings for better reliability
    if ! gpg --batch --yes --passphrase "$PASSPHRASE" \
             --cipher-algo $ENCRYPTION_CIPHER \
             --compress-algo none \
             --s2k-digest-algo SHA1 \
             --s2k-mode 3 \
             --s2k-count 65536 \
             -o "$temp_output" -c "$input_file"; then
        log_error "Failed to encrypt $input_file"
        rm -f "$temp_output"
        return 1
    fi
    
    # Verify the encrypted file was created
    if [ ! -f "$temp_output" ]; then
        log_error "Encrypted file was not created: $temp_output"
        return 1
    fi
    
    # Only move if encryption was successful
    if ! mv -f "$temp_output" "$output_file"; then
        log_error "Failed to move encrypted file to $output_file"
        rm -f "$temp_output"
        return 1
    fi
    
    log_success "Successfully encrypted $input_file"
    return 0
}

# =============================================================================
# Backup Functions
# =============================================================================
backup_home() {
    log_info "=== Starting backup_home function ==="
    local files_to_backup=("$@")
    
    log_info "Number of files/directories to backup: ${#files_to_backup[@]}"
    for ((i=0; i<${#files_to_backup[@]}; i++)); do
        log_info "  File $((i+1)): '${files_to_backup[$i]}'"
        if [ ! -e "${files_to_backup[$i]}" ]; then
            log_warning "  File does not exist: '${files_to_backup[$i]}'"
        fi
    done
    
    # If no files specified, default to home directory
    if [ ${#files_to_backup[@]} -eq 0 ]; then
        log_info "No files specified, defaulting to home directory"
        files_to_backup=("$HOME")
    fi
    
    local backup_name="home"
    if [ ${#files_to_backup[@]} -eq 1 ] && [ -n "${files_to_backup[0]}" ]; then
        backup_name=$(basename "${files_to_backup[0]}")
        log_info "Using '$backup_name' as backup name"
    fi
    
    local backup_file="$BACKUP_DIR/${backup_name}-backup-$TIMESTAMP.tar.gz"
    local encrypted_file="$backup_file.gpg"
    
    log_info "Backup file: $backup_file"
    log_info "Encrypted file: $encrypted_file"
    
    # For multiple files, we'll create a temporary directory to store them
    local temp_dir=""
    if [ ${#files_to_backup[@]} -gt 1 ]; then
        log_info "Multiple files to back up, creating temporary directory"
        temp_dir=$(mktemp -d)
        log_info "Created temp directory: $temp_dir"
        for item in "${files_to_backup[@]}"; do
            if [ -e "$item" ]; then
                log_info "Creating symlink for: $item"
                ln -s "$(realpath "$item")" "$temp_dir/"
            else
                log_warning "File does not exist: $item"
            fi
        done
        files_to_backup=("$temp_dir")
    fi
    
    local source_dir="${files_to_backup[0]}"
    local base_dir="$(dirname "$source_dir")"
    local target_dir="$(basename "$source_dir")"
    
    log_info "Source directory: $source_dir"
    log_info "Base directory: $base_dir"
    log_info "Target directory: $target_dir"
    
    log_info "=== Starting backup creation ==="
    log_info "Source: $source_dir"
    log_info "Destination: $backup_file"
    log_info "Working directory: $(pwd)"
    log_info "Base directory: $base_dir"
    log_info "Target directory: $target_dir"
    
    # Verify source exists and is readable
    if [ ! -e "$source_dir" ]; then
        log_error "Source does not exist: $source_dir"
        return 1
    fi
    
    if [ ! -r "$source_dir" ]; then
        log_error "Source is not readable: $source_dir"
        log_info "Permissions: $(ls -ld "$source_dir")"
        return 1
    fi
    
    # Change to the parent directory to get relative paths in the archive
    log_info "Changing to directory: $base_dir"
    cd "$base_dir" || {
        log_error "Failed to change to directory: $base_dir"
        log_info "Current directory: $(pwd)"
        return 1
    }
    log_info "Current directory after cd: $(pwd)"
    
    log_info "Backing up: $source_dir"
    
    # Create archive with progress
    log_info "Creating backup (this may take a while)..."
    
    # Get total size of files to be backed up
    local total_size=$(du -sb "$source_dir" 2>/dev/null | awk '{print $1}')
    
    # Prepare exclude patterns
    local exclude_patterns=(
        "--exclude=${BACKUP_DIR}"  # Exclude the backup directory itself
        "--exclude=*/${BACKUP_DIR}/*"  # Exclude any backup directory within the target
        "--exclude=*/\.cache/*"  # Common directories to exclude
        "--exclude=*/\.local/share/Trash/*"  # Trash
    )
    
    # Create the archive with proper relative paths and exclusions
    log_info "Creating tar archive of: $target_dir"
    log_info "Excluding patterns: ${exclude_patterns[*]}"
    log_info "Command: tar -czf \"$backup_file\" ${exclude_patterns[*]} \"$target_dir\""
    
    # Run tar with detailed output and exclusions
    if ! tar -cvzf "$backup_file" ${exclude_patterns[@]} "$target_dir"; then
        log_error "Failed to create backup archive"
        log_info "Check disk space: $(df -h . | grep -v Filesystem)"
        return 1
    fi
    
    # Verify the archive was created
    if [ ! -f "$backup_file" ]; then
        log_error "Backup file was not created: $backup_file"
        return 1
    fi
    
    log_info "Backup archive created successfully: $backup_file"
    log_info "Backup size: $(du -h "$backup_file" | cut -f1)"
    
    # Encrypt the backup
    if ! encrypt_file "$backup_file" "$encrypted_file"; then
        rm -f "$backup_file"
        return 1
    fi
    
    # Remove unencrypted backup
    rm -f "$backup_file"
    log_success "Home directory backup complete: $encrypted_file"
}

backup_packages() {
    local package_list="$BACKUP_DIR/Package.list"
    local package_list_encrypted="$package_list-$TIMESTAMP.gpg"
    
    log_info "Backing up package list..."
    
    # Save package list
    dpkg --get-selections > "$package_list"
    
    # Encrypt the package list
    if ! encrypt_file "$package_list" "$package_list_encrypted"; then
        rm -f "$package_list"
        return 1
    fi
    
    # Remove unencrypted package list
    rm -f "$package_list"
    log_success "Package list backup complete: $package_list_encrypted"
}

backup_system_files() {
    local files_to_backup=("${@:-${DEFAULT_HOST_FILES[@]}}")
    
    # Check if we need sudo for any of the files
    if ! check_sudo "${files_to_backup[@]}"; then
        log_error "Cannot continue without required permissions"
        return 1
    fi
    local backup_file="$BACKUP_DIR/system-files-$TIMESTAMP.tar.gz"
    local encrypted_file="$backup_file.gpg"
    local valid_files=()
    
    log_info "Checking system files to back up..."
    
    # Check which files exist and are readable
    for file in "${files_to_backup[@]}"; do
        if [ -r "$file" ]; then
            valid_files+=("$file")
        else
            log_warning "Skipping non-existent or unreadable file: $file"
        fi
    done
    
    if [ ${#valid_files[@]} -eq 0 ]; then
        log_warning "No valid files to back up"
        return 0
    fi
    
    log_info "Backing up system files: ${valid_files[*]}"
    
    # Get total size of files to be backed up (using sudo if needed)
    local du_cmd="du -sb"
    if [ "$(id -u)" -eq 0 ]; then
        du_cmd="sudo $du_cmd"
    fi
    local total_size=$($du_cmd "${valid_files[@]}" 2>/dev/null | awk '{total += $1} END {print total}')
    
    # Create archive of system files with progress (using sudo if needed)
    local tar_cmd="tar"
    if [ "$(id -u)" -eq 0 ]; then
        tar_cmd="sudo $tar_cmd"
    fi
    
    # Build the compression command
    local compress_cmd="$COMPRESSOR -$GZIP_LEVEL"
    if [ "$COMPRESSOR" = "pigz" ]; then
        compress_cmd+=" -p$NUM_CORES"
    fi
    
    log_info "Using $COMPRESSOR with $GZIP_LEVEL compression level"
    
    if ! $tar_cmd cf - "${valid_files[@]}" 2>/dev/null | \
         $PV_CMD -s ${total_size:-0} | \
         $compress_cmd > "$backup_file"; then
        log_error "Failed to create system files backup"
        return 1
    fi
    
    # Encrypt the backup
    if ! encrypt_file "$backup_file" "$encrypted_file"; then
        rm -f "$backup_file"
        return 1
    fi
    
    # Remove unencrypted backup
    rm -f "$backup_file"
    log_success "System files backup complete: $encrypted_file"
}

# =============================================================================
# Test Functions
# =============================================================================
test_encryption() {
    local test_file="$TEMP_DIR/test_backup_$TIMESTAMP.txt"
    local encrypted_file="$test_file.gpg"
    local decrypted_file="$test_file.decrypted"
    
    log_info "Running encryption test..."
    
    # Create test file
    echo "This is a test backup file created at $(date)" > "$test_file"
    
    # Test encryption
    if ! echo "$PASSPHRASE" | gpg --batch --yes --passphrase-fd 0 \
             --symmetric --cipher-algo AES256 -o "$encrypted_file" "$test_file" 2>/dev/null; then
        log_error "Encryption test failed"
        return 1
    fi
    
    # Test decryption
    if ! echo "$PASSPHRASE" | gpg --batch --yes --passphrase-fd 0 \
             -d -o "$decrypted_file" "$encrypted_file" 2>/dev/null; then
        log_error "Decryption test failed"
        return 1
    fi
    
    # Verify files match
    if ! cmp -s "$test_file" "$decrypted_file"; then
        log_error "Decrypted file does not match original"
        return 1
    else
        log_success "Encryption test passed successfully"
    fi
    
    # Clean up test files
    rm -f "$test_file" "$encrypted_file" "$decrypted_file"
    
    return 0
}

# =============================================================================
# Main Script
# =============================================================================
show_help() {
    cat << EOF
Unified Backup Script v$VERSION

Usage: $(basename "$0") [OPTIONS]

Options:
  -d, --dir DIR       Set backup directory (default: $DEFAULT_BACKUP_DIR)
  -p, --passphrase    Prompt for encryption passphrase
  -f, --files FILES   Additional files to backup (comma-separated)
  -t, --test          Run encryption test only
  -h, --help          Show this help message
  -v, --version       Show version information

Examples:
  $(basename "$0") -d /mnt/backup
  $(basename "$0") -p -f "/etc/nginx/nginx.conf,/etc/mysql/my.cnf"
  $(basename "$0") --test

Note: Always ensure your backup directory is secure and encrypted at rest.
EOF
}

main() {
    log_info "=== Starting backup script execution ==="
    
    # Check if we're running as root
    if [ "$(id -u)" -eq 0 ]; then
        log_warning "Running as root. Be cautious with file permissions in backups."
    fi
    
    local additional_files=()
    local run_test=false
    
    log_info "Current working directory: $(pwd)"
    log_info "Script directory: $(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    log_info "User: $(whoami)"
    log_info "Hostname: $(hostname)"
    log_info "Environment variables:"
    env | sort | while read -r line; do log_info "  $line"; done
    
    # Parse command line arguments
    log_info "Parsing command line arguments: $*"
    while [[ $# -gt 0 ]]; do
        log_info "Processing argument: $1"
        case "$1" in
            -d|--dir)
                log_info "Setting backup directory to: $2"
                BACKUP_DIR="$2"
                shift 2
                ;;
            -p|--passphrase)
                log_info "Prompting for passphrase"
                prompt_passphrase
                shift
                ;;
            -f|--files)
                log_info "Processing additional files: $2"
                IFS=',' read -r -a additional_files <<< "$2"
                log_info "Split into ${#additional_files[@]} items"
                for ((i=0; i<${#additional_files[@]}; i++)); do
                    log_info "  File $((i+1)): '${additional_files[$i]}'"
                done
                shift 2
                ;;
            -t|--test)
                log_info "Test mode enabled"
                run_test=true
                shift
                ;;
            -h|--help)
                log_info "Showing help"
                show_help
                exit 0
                ;;
            -v|--version)
                log_info "Showing version"
                echo "Unified Backup Script v$VERSION"
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                shift
                ;;
        esac
    done
    log_info "Finished parsing command line arguments"
    
    # Set default backup directory if not specified
    BACKUP_DIR="${BACKUP_DIR:-$DEFAULT_BACKUP_DIR}"
    
    # Create backup directory if it doesn't exist
    if [ ! -d "$BACKUP_DIR" ]; then
        log_info "Creating backup directory: $BACKUP_DIR"
        mkdir -p "$BACKUP_DIR" || {
            log_error "Failed to create backup directory: $BACKUP_DIR"
            return 1
        }
        log_info "Successfully created backup directory"
    else
        log_info "Using existing backup directory: $BACKUP_DIR"
    fi
    
    # Verify backup directory is writable
    if [ ! -w "$BACKUP_DIR" ]; then
        log_error "Backup directory is not writable: $BACKUP_DIR"
        log_info "Current user: $(whoami)"
        log_info "Directory permissions: $(ls -ld "$BACKUP_DIR")"
        return 1
    fi
    
    # Check requirements
    log_info "=== Checking system requirements ==="
    if ! check_requirements; then
        log_error "System requirements check failed"
        exit 1
    fi
    log_info "System requirements check passed"
    
    # Prompt for passphrase if not provided
    prompt_passphrase
    
    # Run test if requested
    if [ "$run_test" = true ]; then
        log_info "=== Running encryption test ==="
        if test_encryption; then
            log_success "Encryption test completed successfully"
            exit 0
        else
            log_error "Encryption test failed"
            exit 1
        fi
    fi
    
    # Start backup process
    log_info "=== Starting backup process ==="
    log_info "Backup directory: $BACKUP_DIR"
    log_info "Number of additional files: ${#additional_files[@]}"
    
    # Create a timestamp for this backup
    TIMESTAMP=$(date +"%Y%m%d-%H%M%S")
    log_info "Backup timestamp: $TIMESTAMP"
    
    # Run backup functions
    log_info "=== Starting home backup ==="
    log_info "Files to back up:"
    for ((i=0; i<${#additional_files[@]}; i++)); do
        log_info "  $((i+1)). ${additional_files[$i]}"
    done
    
    if ! backup_home "${additional_files[@]}"; then
        log_error "Home backup failed"
        exit 1
    fi
    log_info "=== Home backup completed successfully ==="
    
    # If additional files were specified, back them up
    if [ ${#additional_files[@]} -gt 0 ]; then
        log_info "Backing up additional files: ${additional_files[*]}"
        # Convert relative paths to absolute paths
        local abs_files=()
        for file in "${additional_files[@]}"; do
            log_info "Processing file/directory: $file"
            if [[ "$file" == ./* ]] || [[ "$file" != /* ]]; then
                # Convert relative path to absolute path
                local abs_path="$(realpath -m "$file")"
                log_info "Converted relative path '$file' to absolute path: $abs_path"
                abs_files+=("$abs_path")
            else
                log_info "Using absolute path as is: $file"
                abs_files+=("$file")
            fi
            
            # Verify the file/directory exists
            if [ ! -e "${abs_files[-1]}" ]; then
                log_error "File/directory does not exist: ${abs_files[-1]}"
                return 1
            else
                log_info "Verified file/directory exists: ${abs_files[-1]}"
            fi
        done
        
        log_info "Backing up the following files/directories: ${abs_files[*]}"
        if ! backup_home "${abs_files[@]}"; then
            log_error "Additional files backup failed"
            return 1
        fi
    else
        # Otherwise, back up the home directory
        log_info "No additional files specified, backing up home directory"
        if ! backup_home; then
            log_error "Home directory backup failed"
            return 1
        fi
    fi
    
    if ! backup_packages; then
        log_warning "Package list backup failed"
    fi
    
    # Combine default and additional files
    local all_files=("${DEFAULT_HOST_FILES[@]}" "${additional_files[@]}")
    
    if ! backup_system_files "${all_files[@]}"; then
        log_warning "System files backup failed"
    fi
    
    log_success "Backup process completed successfully"
}

# Run the script
main "$@"
