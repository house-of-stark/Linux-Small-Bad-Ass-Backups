#!/bin/bash

# =============================================================================
# Unified Restore Script
# =============================================================================
# Description: Restores encrypted backups created by backup.sh
# Version: 1.0.0
# License: MIT
# =============================================================================

set -euo pipefail

# =============================================================================
# Configuration
# =============================================================================
VERSION="1.0.0"
DEFAULT_BACKUP_DIR="${BACKUP_DIR:-$HOME/backup}"
TEMP_DIR=$(mktemp -d)
trap 'cleanup' EXIT

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

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
    if [ -d "$TEMP_DIR" ]; then
        rm -rf "$TEMP_DIR"
    fi
}

check_requirements() {
    local missing=()
    
    # Required commands
    command -v gpg >/dev/null 2>&1 || missing+=("gpg")
    command -v tar >/dev/null 2>&1 || missing+=("tar")
    command -v dpkg >/dev/null 2>&1 || missing+=("dpkg")
    
    if [ ${#missing[@]} -ne 0 ]; then
        log_error "Missing required packages: ${missing[*]}. Please install them first."
    fi
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
    local pass1 pass2
    while true; do
        read -rsp "Enter encryption passphrase: " pass1
        echo
        [ -n "$pass1" ] && break
        echo "Passphrase cannot be empty"
    done
    
    read -rsp "Confirm passphrase: " pass2
    echo
    
    if [ "$pass1" != "$pass2" ]; then
        log_error "Passphrases do not match"
    fi
    
    echo -n "$pass1"
}

decrypt_file() {
    local input_file="$1"
    local output_file="$2"
    local passphrase="$3"
    
    if ! echo "$passphrase" | gpg --batch --passphrase-fd 0 --decrypt --output "$output_file" "$input_file" 2>/dev/null; then
        log_error "Failed to decrypt $input_file. Wrong passphrase or corrupted file."
    fi
}

# =============================================================================
# Restore Functions
# =============================================================================
restore_plain_home() {
    local backup_file="$1"
    local extract_dir="$TEMP_DIR/home_restore"
    
    mkdir -p "$extract_dir"
    
    log_info "Extracting home directory backup..."
    if ! tar -xzf "$backup_file" -C "$extract_dir"; then
        log_error "Failed to extract home directory backup"
        return 1
    fi
    
    log_info "Restoring home directory files..."
    if ! cp -r "$extract_dir"/. "$HOME/"; then
        log_error "Failed to restore home directory files"
        return 1
    fi
    
    log_success "Home directory restored successfully from plain backup"
    return 0
}

restore_encrypted_home() {
    local backup_file="$1"
    local passphrase="$2"
    local extract_dir="$TEMP_DIR/home_restore"
    
    mkdir -p "$extract_dir"
    
    log_info "Decrypting home directory backup..."
    local decrypted_file="$TEMP_DIR/home_backup.tar"
    decrypt_file "$backup_file" "$decrypted_file" "$passphrase"
    
    log_info "Extracting home directory contents..."
    if ! tar -xf "$decrypted_file" -C "$extract_dir"; then
        log_error "Failed to extract home directory backup"
        return 1
    fi
    
    log_info "Restoring home directory files..."
    if ! cp -r "$extract_dir"/. "$HOME/"; then
        log_error "Failed to restore home directory files"
        return 1
    fi
    
    log_success "Home directory restored successfully from encrypted backup"
    return 0
}

restore_plain_packages() {
    local backup_file="$1"
    
    log_info "Restoring packages from plain backup..."
    if ! command -v apt-get >/dev/null 2>&1; then
        log_warning "apt-get not found. Cannot restore packages on this system."
        return 1
    fi
    
    if ! prompt_confirm "This will install all packages from the backup. Continue?"; then
        log_info "Package restoration cancelled"
        return 1
    fi
    
    xargs -a "$backup_file" sudo apt-get install -y
    
    log_success "Packages restored successfully from plain backup"
    return 0
}

restore_encrypted_packages() {
    local backup_file="$1"
    local passphrase="$2"
    local decrypted_file="$TEMP_DIR/packages.list"
    
    log_info "Decrypting package list..."
    decrypt_file "$backup_file" "$decrypted_file" "$passphrase"
    
    log_info "Restoring packages..."
    if ! command -v apt-get >/dev/null 2>&1; then
        log_warning "apt-get not found. Cannot restore packages on this system."
        return 1
    fi
    
    if ! prompt_confirm "This will install all packages from the backup. Continue?"; then
        log_info "Package restoration cancelled"
        return 1
    fi
    
    xargs -a "$decrypted_file" sudo apt-get install -y
    
    log_success "Packages restored successfully from encrypted backup"
    return 0
}

restore_plain_system_files() {
    local backup_file="$1"
    local extract_dir="$TEMP_DIR/system_restore"
    
    mkdir -p "$extract_dir"
    
    log_info "Extracting system files from plain backup..."
    if ! sudo tar -xzf "$backup_file" -C "$extract_dir"; then
        log_error "Failed to extract system files backup"
        return 1
    fi
    
    log_info "Restoring system files..."
    if ! sudo cp -r "$extract_dir"/. /; then
        log_error "Failed to restore system files"
        return 1
    fi
    
    log_success "System files restored successfully from plain backup"
    return 0
}

restore_encrypted_system_files() {
    local backup_file="$1"
    local passphrase="$2"
    local extract_dir="$TEMP_DIR/system_restore"
    
    mkdir -p "$extract_dir"
    
    log_info "Decrypting system files backup..."
    local decrypted_file="$TEMP_DIR/system_backup.tar"
    decrypt_file "$backup_file" "$decrypted_file" "$passphrase"
    
    log_info "Extracting system files..."
    if ! sudo tar -xf "$decrypted_file" -C "$extract_dir"; then
        log_error "Failed to extract system files backup"
        return 1
    fi
    
    log_info "Restoring system files..."
    if ! sudo cp -r "$extract_dir"/. /; then
        log_error "Failed to restore system files"
        return 1
    fi
    
    log_success "System files restored successfully from encrypted backup"
    return 0
}

# =============================================================================
# Main Script
# =============================================================================
show_help() {
    cat << EOF
Unified Restore Script v${VERSION}

Usage: $0 [OPTIONS] <backup_file>

Options:
  -h, --help          Show this help message and exit
  -p, --passphrase    Passphrase for decryption (optional, will prompt if not provided)
  -y, --yes          Skip confirmation prompts

Examples:
  $0 /path/to/backup_20230620-123456_home.tar.gpg
  $0 -p "mysecretpass" /path/to/backup_20230620-123456_packages.list.gpg

Note: This script requires root privileges for restoring system files and packages.
EOF
}

main() {
    local backup_file=""
    local passphrase=""
    local skip_confirm=false
    
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)
                show_help
                exit 0
                ;;
            -p|--passphrase)
                if [ $# -gt 1 ] && [[ ! "$2" == -* ]]; then
                    passphrase="$2"
                    shift 2
                else
                    # If no passphrase provided, prompt for it
                    passphrase=$(prompt_passphrase)
                    shift
                fi
                ;;
            -y|--yes)
                skip_confirm=true
                shift
                ;;
            -*)
                log_error "Unknown option: $1"
                show_help
                exit 1
                ;;
            *)
                if [ -z "$backup_file" ]; then
                    backup_file="$1"
                else
                    log_error "Multiple backup files specified"
                    show_help
                    exit 1
                fi
                shift
                ;;
        esac
    done
    
    # Validate backup file
    if [ -z "$backup_file" ]; then
        log_error "No backup file specified"
        show_help
        exit 1
    fi
    
    if [ ! -f "$backup_file" ]; then
        log_error "Backup file not found: $backup_file"
        exit 1
    fi
    
    # Check requirements
    check_requirements
    
    # Prompt for passphrase if not provided
    if [ -z "$passphrase" ]; then
        passphrase=$(prompt_passphrase)
    fi
    
        # Determine backup type and encryption status from filename and content
    local backup_type=""
    local is_encrypted=false
    local filename=$(basename "$backup_file")
    
    # Check if file is encrypted (ends with .gpg) or plain compressed (ends with .tar.gz)
    if [[ "$filename" == *.gpg ]]; then
        is_encrypted=true
        # Remove .gpg extension for further pattern matching
        local base_name="${filename%.gpg}"
        
        # Check for encrypted backup patterns
        if [[ "$base_name" == *"_home.tar" || "$base_name" == *"home-backup-"* || "$base_name" == *"home_backup"* ]]; then
            backup_type="home"
        elif [[ "$base_name" == *"_packages.list" || "$base_name" == *"packages-backup-"* || "$base_name" == *"packages_backup"* ]]; then
            backup_type="packages"
        elif [[ "$base_name" == *"_system.tar" || "$base_name" == *"system-backup-"* || "$base_name" == *"system_backup"* ]]; then
            backup_type="system"
        fi
    elif [[ "$filename" == *.tar.gz || "$filename" == *.tgz ]]; then
        is_encrypted=false
        # Check for plain backup patterns
        if [[ "$filename" == *"home"* || "$filename" == *"quick-backup"* ]]; then
            backup_type="home"
        elif [[ "$filename" == *"packages"* || "$filename" == *"pkg"* ]]; then
            backup_type="packages"
        elif [[ "$filename" == *"system"* || "$filename" == *"sys"* ]]; then
            backup_type="system"
        fi
    fi
    
    if [ -z "$backup_type" ]; then
        # If we still couldn't determine the type, try to guess based on file contents
        log_warning "Could not determine backup type from filename. Attempting to determine from contents..."
        
        # Check if the archive contains common home directory files
        if tar -tf "$backup_file" 2>/dev/null | grep -q -E '^(home/|etc/skel/|root/)'; then
            backup_type="home"
        # Check for package list files
        elif tar -tf "$backup_file" 2>/dev/null | grep -q -E 'var/lib/apt/lists/|var/cache/apt/'; then
            backup_type="packages"
        # Check for system files
        elif tar -tf "$backup_file" 2>/dev/null | grep -q -E '^(etc/|usr/|bin/|sbin/|lib/|opt/)'; then
            backup_type="system"
        else
            log_error "Could not determine backup type. Please specify the backup type with --type option.\n" \
                     "Supported backup types: home, packages, system\n" \
                     "Detected filename: $filename"
            exit 1
        fi
        
        log_info "Detected $backup_type backup based on contents"
    fi
    
    log_info "Detected $backup_type backup (${is_encrypted:+encrypted}${is_encrypted:+, }${is_encrypted:+compressed})"
    
    # Confirm before proceeding
    if [ "$skip_confirm" = false ]; then
        if ! prompt_confirm "Restore $backup_type from $backup_file? This will overwrite existing files."; then
            log_info "Restore cancelled"
            exit 0
        fi
    fi
    
    # Perform the restore
    case "$backup_type" in
        home)
            if [ "$is_encrypted" = true ]; then
                restore_encrypted_home "$backup_file" "$passphrase"
            else
                restore_plain_home "$backup_file"
            fi
            ;;
        packages)
            if [ "$is_encrypted" = true ]; then
                restore_encrypted_packages "$backup_file" "$passphrase"
            else
                restore_plain_packages "$backup_file"
            fi
            ;;
        system)
            if [ "$(id -u)" -ne 0 ]; then
                log_error "System restore requires root privileges. Please run with sudo."
                exit 1
            fi
            if [ "$is_encrypted" = true ]; then
                restore_encrypted_system_files "$backup_file" "$passphrase"
            else
                restore_plain_system_files "$backup_file"
            fi
            ;;
    esac
}

# Run the script
main "$@"
