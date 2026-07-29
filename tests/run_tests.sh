#!/bin/bash

# ======================================================================
# HOMELAB INTEGRATION TESTS
# ======================================================================
# Usage: 
#   Local run:  ./run_tests.sh
#   Remote run: ./run_tests.sh <IP_ADDRESS> <USER>
# ======================================================================

set -e
set -o pipefail

TARGET_IP="${1:-localhost}"
TARGET_USER="${2:-$USER}"

echo "Starting integration tests against $TARGET_IP"

# Determine if we need to prefix commands with SSH
CMD_PREFIX=""
if [ "$TARGET_IP" != "localhost" ] && [ "$TARGET_IP" != "127.0.0.1" ]; then
    CMD_PREFIX="ssh -o StrictHostKeyChecking=no $TARGET_USER@$TARGET_IP"
fi

export CMD_PREFIX
export TARGET_IP

FAILED_TESTS=0

# Execute all test modules in order
for test_script in $(dirname "$0")/*.sh; do
    if [ "$test_script" == "$(dirname "$0")/run_tests.sh" ]; then
        continue
    fi
    
    echo "----------------------------------------"
    echo "Running: $(basename "$test_script")"
    
    if bash "$test_script"; then
        echo "PASS: $(basename "$test_script")"
    else
        echo "FAIL: $(basename "$test_script")"
        FAILED_TESTS=$((FAILED_TESTS + 1))
    fi
done

echo "----------------------------------------"
if [ "$FAILED_TESTS" -eq 0 ]; then
    echo "All tests passed successfully."
    exit 0
else
    echo "Tests failed. $FAILED_TESTS module(s) returned non-zero."
    exit 1
fi
