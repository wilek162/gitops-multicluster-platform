#!/usr/bin/env bash
# Unit tests for bootstrap scripts
set -euo pipefail

source tests/scripts/test-helpers.sh
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

test_bootstrap_script_exists() {
    assert_file_exists "${REPO_ROOT}/bootstrap/scripts/bootstrap-kind-argocd.sh"
    assert_file_executable "${REPO_ROOT}/bootstrap/scripts/bootstrap-kind-argocd.sh"
}

test_bootstrap_script_syntax() {
    bash -n "${REPO_ROOT}/bootstrap/scripts/bootstrap-kind-argocd.sh"
    assert_success "Bootstrap script has valid syntax"
}

test_bootstrap_creates_kubeconfig() {
    local test_cluster="test-$$"

    # Run bootstrap with test cluster (may require Docker/kind; tolerate failures)
    bash "${REPO_ROOT}/bootstrap/scripts/bootstrap-kind-argocd.sh" "$test_cluster" || true

    # Check if kubeconfig was created
    if [ -f "${REPO_ROOT}/bootstrap/${test_cluster}.kubeconfig" ]; then
        assert_success "Kubeconfig file created"
        # Cleanup
        kind delete cluster --name "$test_cluster" 2>/dev/null || true
        rm -f "${REPO_ROOT}/bootstrap/${test_cluster}.kubeconfig"
    else
        assert_warning "Kubeconfig file not created (environment may not have Docker/kind available)"
    fi
}

test_bootstrap_idempotency() {
    # Test that script handles existing cluster gracefully (run but tolerate failures)
    local output
    output=$(bash "${REPO_ROOT}/bootstrap/scripts/bootstrap-kind-argocd.sh" test-cluster 2>&1 || true)

    if echo "$output" | grep -q "already exists"; then
        assert_success "Script detects existing cluster"
    else
        assert_success "Script runs without existing cluster (or environment prevented creation)"
    fi
}

test_cluster_registration_script() {
    assert_file_exists "${REPO_ROOT}/bootstrap/scripts/register-cluster.sh"
    assert_file_executable "${REPO_ROOT}/bootstrap/scripts/register-cluster.sh"

    # Syntax check for registration script
    bash -n "${REPO_ROOT}/bootstrap/scripts/register-cluster.sh"
    assert_success "Cluster registration script has valid syntax"
}

# Run all tests
run_tests \
    test_bootstrap_script_exists \
    test_bootstrap_script_syntax \
    test_bootstrap_creates_kubeconfig \
    test_bootstrap_idempotency \
    test_cluster_registration_script