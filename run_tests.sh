#!/bin/bash

# Exit on error
set -e

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Test directories
TEST_DIR="/tmp/backup-test-$(date +%s)
TEST_DATA_DIR="$TEST_DIR/test-data"
BACKUP_DIR="$TEST_DIR/backup"
RESTORE_DIR="$TEST_DIR/restore"

# Create test directories
setup() {
    echo "Setting up test environment..."
    mkdir -p "$TEST_DATA_DIR" "$BACKUP_DIR" "$RESTORE_DIR"
    
    # Create test files
    echo "Creating test files..."
    for i in {1..5}; do
        echo "Test file $i" > "$TEST_DATA_DIR/file$i.txt"
        mkdir -p "$TEST_DATA_DIR/dir$i"
        echo "Test file in dir$i" > "$TEST_DATA_DIR/dir$i/file.txt"
    done
    
    # Create a larger file for testing
    dd if=/dev/urandom of="$TEST_DATA_DIR/large_file.bin" bs=1M count=10 2>/dev/null
}

# Clean up test directories
teardown() {
    echo "Cleaning up..."
    rm -rf "$TEST_DIR"
}

# Run a command and check its exit status
run_test() {
    local test_name="$1"
    local command="$2"
    
    echo -n "Running test: $test_name... "
    
    if eval "$command"; then
        echo -e "${GREEN}PASSED${NC}"
        return 0
    else
        echo -e "${RED}FAILED${NC}"
        return 1
    fi
}

# Test backup functionality
test_backup() {
    echo "\n=== Testing Backup Functionality ==="
    
    # Run backup
    run_test "Basic backup" "./backup.sh -d \"$BACKUP_DIR\" -f \"$TEST_DATA_DIR\""
    
    # Verify backup files were created
    local backup_file=$(find "$BACKUP_DIR" -name "*.tar.gz.gpg" | head -1)
    if [ -z "$backup_file" ]; then
        echo -e "${RED}Backup file not found${NC}"
        return 1
    fi
    
    echo "Backup file created: $backup_file"
}

# Test restore functionality
test_restore() {
    echo "\n=== Testing Restore Functionality ==="
    
    # Find the backup file
    local backup_file=$(find "$BACKUP_DIR" -name "*.tar.gz.gpg" | head -1)
    if [ -z "$backup_file" ]; then
        echo -e "${RED}No backup file found for restore test${NC}"
        return 1
    fi
    
    # Run restore
    run_test "Basic restore" "./restore.sh -s \"$backup_file\" -d \"$RESTORE_DIR\""
    
    # Verify restored files
    if [ ! -f "$RESTORE_DIR/file1.txt" ]; then
        echo -e "${RED}Restored files not found${NC}"
        return 1
    fi
    
    echo "Files restored to: $RESTORE_DIR"
}

# Main test function
run_tests() {
    echo "=== Starting Backup/Restore Tests ==="
    
    setup
    
    # Run tests
    test_backup
    test_restore
    
    teardown
    
    echo "=== All tests completed ==="
}

# Run tests if script is executed directly
if [ "$0" = "${BASH_SOURCE[0]}" ]; then
    run_tests
fi
