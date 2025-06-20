#!/bin/bash

# Test script to compare backup performance
set -e

echo "=== Backup Performance Test ==="

# Create test directories with timestamp for uniqueness
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
TEST_DIR="/tmp/backup-test-$TIMESTAMP"
TEST_DATA_DIR="$TEST_DIR/test-data"
BACKUP_DIR_OLD="$TEST_DIR/backup-old"
BACKUP_DIR_NEW="$TEST_DIR/backup-new"
LOG_FILE="$TEST_DIR/performance-test-$TIMESTAMP.log"

# Clean up from previous runs if they exist
rm -rf "$TEST_DIR"

# Create fresh test directories
mkdir -p "$TEST_DATA_DIR" "$BACKUP_DIR_OLD" "$BACKUP_DIR_NEW"

# Function to log messages
log() {
    echo -e "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# Function to generate test data
generate_test_data() {
    local size_mb=$1
    log "Generating ${size_mb}MB of test data in $TEST_DATA_DIR..."
    
    # Create a few subdirectories
    mkdir -p "$TEST_DATA_DIR/dir1" "$TEST_DATA_DIR/dir2"
    
    # Create files of different sizes (10KB to 1MB)
    for i in {1..10}; do
        # Create files in root test directory (5 files, 100KB-1MB each)
        dd if=/dev/urandom of="$TEST_DATA_DIR/file_${i}.bin" bs=1K count=$((RANDOM % 900 + 100)) &>/dev/null
        
        # Create files in subdirectories (smaller files, 10-100KB)
        for dir in "$TEST_DATA_DIR/dir"{1..2}; do
            dd if=/dev/urandom of="${dir}/file_${i}.bin" bs=1K count=$((RANDOM % 90 + 10)) &>/dev/null
        done
    done
    
    # Create some text files with known content for verification (smaller files, 1-10KB)
    for i in {1..5}; do
        echo "Test file $i - $(date)" > "$TEST_DATA_DIR/text_${i}.txt"
        # Add some random content (1-10KB)
        base64 /dev/urandom | head -c $((RANDOM % 9000 + 1000)) >> "$TEST_DATA_DIR/text_${i}.txt"
    done
    
    # Create a checksum file for verification
    log "Creating checksums for verification..."
    (cd "$TEST_DATA_DIR" && find . -type f -not -name '*.md5' -exec md5sum {} \; > "$TEST_DATA_DIR/checksums.md5")
    
    local actual_size=$(du -sh "$TEST_DATA_DIR" | cut -f1)
    local file_count=$(find "$TEST_DATA_DIR" -type f | wc -l)
    log "Test data generated: $actual_size ($file_count files)"
    
    # Verify we have the expected directory structure
    log "Test directory structure created:"
    find "$TEST_DATA_DIR" -type d | sort
    
    # Show some progress
    log "Sample files created:"
    find "$TEST_DATA_DIR" -type f | head -n 5 | while read -r file; do
        log "  - $file ($(du -h "$file" | cut -f1))"
    done
}

# Function to run backup with old settings
run_old_backup() {
    log "\n=== Running backup with OLD settings ==="
    local start_time=$(date +%s)
    
    # Save current settings
    local old_compressor="$COMPRESSOR"
    local old_gzip_level="$GZIP_LEVEL"
    local old_cipher="$ENCRYPTION_CIPHER"
    
    # Set old settings
    export COMPRESSOR="gzip"
    export GZIP_LEVEL=6
    export ENCRYPTION_CIPHER="AES256"
    
    # Run backup with test data directory only
    log "Running backup of test data only..."
    local script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    
    # Get absolute path to the test data directory
    local abs_test_dir="$(realpath "$TEST_DATA_DIR")"
    
    log "Backing up directory: $abs_test_dir"
    
    # Run backup with absolute path to test data
    "$script_dir/backup.sh" -d "$BACKUP_DIR_OLD" -f "$abs_test_dir"
    
    # Restore settings
    export COMPRESSOR="$old_compressor"
    export GZIP_LEVEL="$old_gzip_level"
    export ENCRYPTION_CIPHER="$old_cipher"
    
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    log "Old backup completed in ${duration} seconds"
    echo "$duration" > "$BACKUP_DIR_OLD/duration.txt"
}

# Function to run backup with new settings
run_new_backup() {
    log "\n=== Running backup with NEW settings ==="
    local start_time=$(date +%s)
    
    # Run backup with optimized settings and test data directory only
    log "Running optimized backup of test data only..."
    local script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    
    # Get absolute path to the test data directory
    local abs_test_dir="$(realpath "$TEST_DATA_DIR")"
    
    log "Backing up directory: $abs_test_dir"
    
    # Run backup with absolute path to test data and passphrase via environment variable
    log "Running backup with passphrase from environment variable"
    PASSPHRASE="testpass123" "$script_dir/backup.sh" -d "$BACKUP_DIR_NEW" -f "$abs_test_dir"
    
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    log "New backup completed in ${duration} seconds"
    echo "$duration" > "$BACKUP_DIR_NEW/duration.txt"
}

# Function to compare results
compare_results() {
    log "\n=== Test Results ==="
    
    # Get file sizes
    local old_size=$(du -sh "$BACKUP_DIR_OLD" | cut -f1)
    local new_size=$(du -sh "$BACKUP_DIR_NEW" | cut -f1)
    
    # Get durations
    local old_duration=$(cat "$BACKUP_DIR_OLD/duration.txt" 2>/dev/null || echo "N/A")
    local new_duration=$(cat "$BACKUP_DIR_NEW/duration.txt" 2>/dev/null || echo "N/A")
    
    # Calculate speedup if possible
    local speedup="N/A"
    if [[ "$old_duration" =~ ^[0-9]+$ && "$new_duration" =~ ^[0-9]+$ && "$new_duration" -ne 0 ]]; then
        speedup=$(echo "scale=2; $old_duration / $new_duration" | bc)
    fi
    
    # Print results
    log "Old backup size: $old_size"
    log "New backup size: $new_size"
    log "Old backup time: ${old_duration} seconds"
    log "New backup time: ${new_duration} seconds"
    log "Speedup: ${speedup}x"
    
    # Print summary
    echo -e "\n=== Performance Summary ==="
    echo "Old settings: ${old_duration}s, ${old_size}"
    echo "New settings: ${new_duration}s, ${new_size}"
    echo "Speedup: ${speedup}x"
    
    if [[ "$speedup" != "N/A" && $(echo "$speedup > 1" | bc -l) -eq 1 ]]; then
        echo -e "\n✅ Performance IMPROVEMENT: ${speedup}x faster"
    fi
}

# Main test
main() {
    # Install pigz if not available
    if ! command -v pigz >/dev/null 2>&1; then
        log "Installing pigz for parallel compression..."
        sudo apt-get update && sudo apt-get install -y pigz
    fi
    
    # Generate test data (100MB by default, change as needed)
    generate_test_data 100
    
    # Run tests
    run_old_backup
    run_new_backup
    
    # Compare results
    compare_results
    
    log "\nTest complete! Log saved to $LOG_FILE"
    echo -e "\nTo clean up test files, run:"
    echo "  rm -rf $TEST_DIR"
}

# Run the main function
main "$@"
