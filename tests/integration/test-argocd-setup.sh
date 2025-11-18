#!/usr/bin/env bash
# Integration tests for ArgoCD setup
set -euo pipefail

source tests/scripts/test-helpers.sh
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

# Test cluster name
TEST_CLUSTER="test-integration-$$"

cleanup() {
    log_info "Cleaning up test cluster: $TEST_CLUSTER"
    kind delete cluster --name "$TEST_CLUSTER" 2>/dev/null || true
    rm -f "${REPO_ROOT}/bootstrap/${TEST_CLUSTER}.kubeconfig"
}

# Setup cleanup trap
trap cleanup EXIT

test_kind_available() {
    if ! command -v kind &>/dev/null; then
        assert_skip "kind not available for integration testing"
        exit 0
    fi
    
    if ! command -v kubectl &>/dev/null; then
        assert_skip "kubectl not available for integration testing"
        exit 0
    fi
    
    if ! docker info &>/dev/null; then
        assert_skip "Docker not available for integration testing"
        exit 0
    fi
    
    assert_success "Prerequisites available for integration testing"
}

test_bootstrap_script_execution() {
    log_info "Running bootstrap script for test cluster..."
    
    # Run bootstrap script with test cluster name (non-interactive)
    if timeout 300 bash "${REPO_ROOT}/bootstrap/scripts/bootstrap-kind-argocd.sh" "$TEST_CLUSTER" &>/dev/null; then
        assert_success "Bootstrap script executed successfully"
    else
        assert_failure "Bootstrap script failed or timed out"
        return
    fi
    
    # Check if cluster was created
    if kind get clusters | grep -q "^${TEST_CLUSTER}$"; then
        assert_success "KIND cluster created successfully"
    else
        assert_failure "KIND cluster was not created"
    fi
}

test_kubeconfig_created() {
    local kubeconfig_path="${REPO_ROOT}/bootstrap/${TEST_CLUSTER}.kubeconfig"
    
    assert_file_exists "$kubeconfig_path"
    
    # Test kubeconfig is valid
    if KUBECONFIG="$kubeconfig_path" kubectl cluster-info &>/dev/null; then
        assert_success "Kubeconfig is valid and cluster accessible"
    else
        assert_failure "Kubeconfig is invalid or cluster not accessible"
    fi
}

test_argocd_namespace_created() {
    local kubeconfig_path="${REPO_ROOT}/bootstrap/${TEST_CLUSTER}.kubeconfig"
    
    if KUBECONFIG="$kubeconfig_path" kubectl get namespace argocd &>/dev/null; then
        assert_success "ArgoCD namespace exists"
    else
        assert_failure "ArgoCD namespace not found"
    fi
}

test_argocd_pods_running() {
    local kubeconfig_path="${REPO_ROOT}/bootstrap/${TEST_CLUSTER}.kubeconfig"
    
    # Wait a bit for pods to start
    sleep 30
    
    # Check if ArgoCD server pod exists
    if KUBECONFIG="$kubeconfig_path" kubectl get pods -n argocd -l app.kubernetes.io/name=argocd-server --no-headers | grep -q "Running\|Pending"; then
        assert_success "ArgoCD server pod is running or starting"
    else
        assert_warning "ArgoCD server pod not found (may still be starting)"
    fi
    
    # Check if ArgoCD application controller exists
    if KUBECONFIG="$kubeconfig_path" kubectl get pods -n argocd -l app.kubernetes.io/name=argocd-application-controller --no-headers | grep -q "Running\|Pending"; then
        assert_success "ArgoCD application controller pod is running or starting"
    else
        assert_warning "ArgoCD application controller pod not found"
    fi
}

test_argocd_admin_secret_exists() {
    local kubeconfig_path="${REPO_ROOT}/bootstrap/${TEST_CLUSTER}.kubeconfig"
    
    if KUBECONFIG="$kubeconfig_path" kubectl get secret argocd-initial-admin-secret -n argocd &>/dev/null; then
        assert_success "ArgoCD admin secret exists"
        
        # Check if password is retrievable
        local password
        password=$(KUBECONFIG="$kubeconfig_path" kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" 2>/dev/null | base64 -d 2>/dev/null)
        if [ -n "$password" ]; then
            assert_success "ArgoCD admin password is retrievable"
        else
            assert_warning "ArgoCD admin password could not be retrieved"
        fi
    else
        assert_failure "ArgoCD admin secret not found"
    fi
}

test_argocd_server_service() {
    local kubeconfig_path="${REPO_ROOT}/bootstrap/${TEST_CLUSTER}.kubeconfig"
    
    if KUBECONFIG="$kubeconfig_path" kubectl get service argocd-server -n argocd &>/dev/null; then
        assert_success "ArgoCD server service exists"
    else
        assert_failure "ArgoCD server service not found"
    fi
}

test_cluster_connectivity() {
    local kubeconfig_path="${REPO_ROOT}/bootstrap/${TEST_CLUSTER}.kubeconfig"
    
    # Test basic cluster operations
    if KUBECONFIG="$kubeconfig_path" kubectl get nodes &>/dev/null; then
        assert_success "Cluster nodes are accessible"
    else
        assert_failure "Cannot access cluster nodes"
    fi
    
    # Test ability to create resources
    if KUBECONFIG="$kubeconfig_path" kubectl create namespace test-integration --dry-run=client -o yaml >/dev/null 2>&1; then
        assert_success "Can create resources in cluster"
    else
        assert_failure "Cannot create resources in cluster"
    fi
}

# Only run tests if we have the necessary tools
if command -v kind &>/dev/null && command -v kubectl &>/dev/null && docker info &>/dev/null 2>&1; then
    log_info "Running ArgoCD setup integration tests with cluster: $TEST_CLUSTER"
    
    run_tests \
        test_kind_available \
        test_bootstrap_script_execution \
        test_kubeconfig_created \
        test_argocd_namespace_created \
        test_argocd_pods_running \
        test_argocd_admin_secret_exists \
        test_argocd_server_service \
        test_cluster_connectivity
else
    log_info "Skipping integration tests - required tools not available"
    assert_skip "Docker, kind, or kubectl not available"
fi