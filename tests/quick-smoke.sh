#!/usr/bin/env bash
# Quick smoke tests for GitOps platform
set -euo pipefail

source tests/scripts/test-helpers.sh
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

log_info "Running quick smoke tests..."

test_repo_structure() {
    assert_directory_exists "${REPO_ROOT}/bootstrap"
    assert_directory_exists "${REPO_ROOT}/apps"
    assert_directory_exists "${REPO_ROOT}/clusters"
    assert_directory_exists "${REPO_ROOT}/tests"
}

test_bootstrap_scripts() {
    assert_file_exists "${REPO_ROOT}/bootstrap.sh"
    assert_file_executable "${REPO_ROOT}/bootstrap.sh"
    assert_file_exists "${REPO_ROOT}/bootstrap/scripts/bootstrap-kind-argocd.sh"
    assert_file_executable "${REPO_ROOT}/bootstrap/scripts/bootstrap-kind-argocd.sh"
}

test_makefile() {
    assert_file_exists "${REPO_ROOT}/Makefile"
    
    # Test that Makefile has expected targets
    if grep -q "bootstrap:" "${REPO_ROOT}/Makefile"; then
        assert_success "Makefile has bootstrap target"
    else
        assert_failure "Makefile missing bootstrap target"
    fi
}

test_guestbook_app() {
    assert_directory_exists "${REPO_ROOT}/apps/guestbook"
    assert_file_exists "${REPO_ROOT}/apps/guestbook/package.json"
    assert_file_exists "${REPO_ROOT}/apps/guestbook/server.js"
}

test_script_syntax() {
    # Test main bootstrap script syntax
    if bash -n "${REPO_ROOT}/bootstrap.sh"; then
        assert_success "Main bootstrap script has valid syntax"
    else
        assert_failure "Main bootstrap script has syntax errors"
    fi
    
    # Test cluster bootstrap script syntax
    if bash -n "${REPO_ROOT}/bootstrap/scripts/bootstrap-kind-argocd.sh"; then
        assert_success "Cluster bootstrap script has valid syntax"
    else
        assert_failure "Cluster bootstrap script has syntax errors"
    fi
}

test_promotion_script() {
    assert_file_exists "${REPO_ROOT}/scripts/promote.sh"
    assert_file_executable "${REPO_ROOT}/scripts/promote.sh"
    
    if bash -n "${REPO_ROOT}/scripts/promote.sh"; then
        assert_success "Promotion script has valid syntax"
    else
        assert_failure "Promotion script has syntax errors"
    fi
}

test_docker_availability() {
    if command -v docker &>/dev/null; then
        if docker info &>/dev/null; then
            assert_success "Docker is available and running"
        else
            assert_warning "Docker command exists but daemon not running"
        fi
    else
        assert_warning "Docker not available (required for KIND clusters)"
    fi
}

test_kubernetes_tools() {
    if command -v kubectl &>/dev/null; then
        assert_success "kubectl is available"
    else
        assert_warning "kubectl not available"
    fi
    
    if command -v kind &>/dev/null; then
        assert_success "kind is available"
    else
        assert_warning "kind not available"
    fi
}

# Run all smoke tests
run_tests \
    test_repo_structure \
    test_bootstrap_scripts \
    test_makefile \
    test_guestbook_app \
    test_script_syntax \
    test_promotion_script \
    test_docker_availability \
    test_kubernetes_tools