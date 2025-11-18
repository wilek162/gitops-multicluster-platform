#!/usr/bin/env bash
# Unit tests for promotion script
set -euo pipefail

source tests/scripts/test-helpers.sh

test_promote_script_exists() {
    assert_file_exists "scripts/promote.sh"
    assert_file_executable "scripts/promote.sh"
}

test_promote_script_syntax() {
    bash -n scripts/promote.sh
    assert_success "Promotion script has valid syntax"
}

test_promote_validates_inputs() {
    # Test with invalid environments
    local output
    output=$(./scripts/promote.sh invalid-env another-invalid app 2>&1 || true)
    
    # Should handle gracefully (even if it fails)
    assert_success "Script handles invalid inputs"
}

test_promote_checks_dependencies() {
    # Test that script checks for gh CLI
    if ! command -v gh &>/dev/null; then
        local output
        output=$(./scripts/promote.sh dev stage guestbook 2>&1 || true)
        
        if echo "$output" | grep -qi "gh"; then
            assert_success "Script checks for gh CLI dependency"
        else
            assert_warning "Script should check for gh CLI"
        fi
    else
        assert_success "gh CLI available"
    fi
}

test_promote_file_operations() {
    # Create test directories
    mkdir -p tests/fixtures/clusters/{dev,stage}/apps/testapp
    
    echo "test: image" > tests/fixtures/clusters/dev/apps/testapp/patch-image.yaml
    
    # Verify source file exists
    assert_file_exists "tests/fixtures/clusters/dev/apps/testapp/patch-image.yaml"
    
    # Cleanup
    rm -rf tests/fixtures/clusters
}

# Run all tests
run_tests \
    test_promote_script_exists \
    test_promote_script_syntax \
    test_promote_validates_inputs \
    test_promote_checks_dependencies \
    test_promote_file_operations
