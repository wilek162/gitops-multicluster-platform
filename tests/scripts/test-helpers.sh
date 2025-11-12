#!/usr/bin/env bash

# Test helper functions

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_SKIPPED=0

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $*"
}

log_success() {
    echo -e "${GREEN}[PASS]${NC} $*"
    ((TESTS_PASSED++))
}

log_failure() {
    echo -e "${RED}[FAIL]${NC} $*"
    ((TESTS_FAILED++))
}

log_warning() {
    echo -e "${YELLOW}[WARN]${NC} $*"
}

log_skip() {
    echo -e "${YELLOW}[SKIP]${NC} $*"
    ((TESTS_SKIPPED++))
}

# Assertions (return 0 for pass, 1 for fail, except skip)
assert_success() {
    local message="$1"
    log_success "$message"
    ((TESTS_RUN++))
    return 0
}

assert_failure() {
    local message="$1"
    log_failure "$message"
    ((TESTS_RUN++))
    return 1
}

assert_skip() {
    local message="$1"
    log_skip "$message"
    ((TESTS_SKIPPED++))
    ((TESTS_RUN++))
    return 0
}

assert_equals() {
    local expected="$1"
    local actual="$2"
    local message="${3:-Values should be equal}"

    ((TESTS_RUN++))

    if [ "$expected" = "$actual" ]; then
        log_success "$message"
        return 0
    else
        log_failure "$message (expected: '$expected', got: '$actual')"
        return 1
    fi
}

assert_not_empty() {
    local value="$1"
    local message="${2:-Value should not be empty}"

    ((TESTS_RUN++))

    if [ -n "$value" ]; then
        log_success "$message"
        return 0
    else
        log_failure "$message"
        return 1
    fi
}

assert_file_exists() {
    local file="$1"
    local message="${2:-File should exist: $file}"

    ((TESTS_RUN++))

    if [ -f "$file" ]; then
        log_success "$message"
        return 0
    else
        log_failure "$message"
        return 1
    fi
}

assert_file_executable() {
    local file="$1"
    local message="${2:-File should be executable: $file}"

    ((TESTS_RUN++))

    if [ -x "$file" ]; then
        log_success "$message"
        return 0
    else
        log_failure "$message"
        return 1
    fi
}

assert_directory_exists() {
    local dir="$1"
    local message="${2:-Directory should exist: $dir}"

    ((TESTS_RUN++))

    if [ -d "$dir" ]; then
        log_success "$message"
        return 0
    else
        log_failure "$message"
        return 1
    fi
}

assert_command_exists() {
    local cmd="$1"
    local message="${2:-Command should be available: $cmd}"

    ((TESTS_RUN++))

    if command -v "$cmd" &>/dev/null; then
        log_success "$message"
        return 0
    else
        log_skip "$message"
        ((TESTS_SKIPPED--))  # Don't double-count skip
        return 1
    fi
}

# Test runner
run_tests() {
    local failed=0
    local test_func

    TESTS_RUN=0
    TESTS_PASSED=0
    TESTS_FAILED=0
    TESTS_SKIPPED=0

    for test_func in "$@"; do
        echo
        echo "──────────────────────────────────────"
        log_info "Running: $test_func"

        if "$test_func"; then
            :  # Test passed (success already logged inside)
        else
            failed=1
        fi
        echo
    done

    echo "══════════════════════════════════════"
    echo "Test Summary:"
    echo "  Total:    $TESTS_RUN"
    echo -e "  ${GREEN}Passed: ${NC} $TESTS_PASSED"
    echo -e "  ${RED}Failed:  ${NC} $TESTS_FAILED"
    echo -e "  ${YELLOW}Skipped: ${NC}$TESTS_SKIPPED"
    echo "══════════════════════════════════════"

    return "$failed"
}
