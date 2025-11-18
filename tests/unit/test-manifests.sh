#!/usr/bin/env bash
# Unit tests for Kubernetes manifests
set -euo pipefail

source tests/scripts/test-helpers.sh
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

test_manifests_exist() {
    # Check for cluster configurations
    assert_directory_exists "${REPO_ROOT}/clusters"
    
    # Look for any YAML files in clusters directory
    if find "${REPO_ROOT}/clusters" -name "*.yaml" -o -name "*.yml" | grep -q .; then
        assert_success "Found Kubernetes manifests in clusters directory"
    else
        assert_warning "No Kubernetes manifests found in clusters directory"
    fi
}

test_guestbook_has_manifests() {
    # Check if guestbook has Kubernetes resources defined
    local guestbook_dir="${REPO_ROOT}/apps/guestbook"
    
    if [ -d "$guestbook_dir" ]; then
        if find "$guestbook_dir" -name "*.yaml" -o -name "*.yml" | grep -q .; then
            assert_success "Guestbook has Kubernetes manifests"
        else
            assert_warning "Guestbook exists but no Kubernetes manifests found"
        fi
    else
        assert_failure "Guestbook directory not found"
    fi
}

test_manifest_syntax() {
    local yaml_files
    yaml_files=$(find "${REPO_ROOT}" -name "*.yaml" -o -name "*.yml" | grep -v node_modules | head -10)
    
    if [ -z "$yaml_files" ]; then
        assert_skip "No YAML files found to validate"
        return
    fi
    
    local invalid_count=0
    while IFS= read -r file; do
        if [ -n "$file" ]; then
            # Basic YAML syntax check using Python
            if python3 -c "import yaml; yaml.safe_load(open('$file'))" 2>/dev/null; then
                assert_success "Valid YAML syntax: $(basename "$file")"
            else
                assert_failure "Invalid YAML syntax: $file"
                ((invalid_count++))
            fi
        fi
    done <<< "$yaml_files"
    
    if [ $invalid_count -eq 0 ] && [ -n "$yaml_files" ]; then
        assert_success "All checked YAML files have valid syntax"
    fi
}

test_kubectl_validation() {
    if ! command -v kubectl &>/dev/null; then
        assert_skip "kubectl not available for manifest validation"
        return
    fi
    
    # Find Kubernetes manifest files
    local k8s_files
    k8s_files=$(find "${REPO_ROOT}" -name "*.yaml" -o -name "*.yml" | grep -E "(deployment|service|configmap|secret)" | head -5)
    
    if [ -z "$k8s_files" ]; then
        assert_skip "No Kubernetes manifest files found"
        return
    fi
    
    local validation_errors=0
    while IFS= read -r file; do
        if [ -n "$file" ]; then
            if kubectl --dry-run=client -f "$file" validate &>/dev/null; then
                assert_success "kubectl validates: $(basename "$file")"
            else
                assert_warning "kubectl validation failed: $file"
                ((validation_errors++))
            fi
        fi
    done <<< "$k8s_files"
    
    if [ $validation_errors -eq 0 ] && [ -n "$k8s_files" ]; then
        assert_success "All checked manifests pass kubectl validation"
    fi
}

test_argocd_applications() {
    # Look for ArgoCD Application manifests
    local argocd_apps
    argocd_apps=$(find "${REPO_ROOT}" -name "*.yaml" -exec grep -l "kind: Application" {} \; | head -5)
    
    if [ -z "$argocd_apps" ]; then
        assert_warning "No ArgoCD Application manifests found"
        return
    fi
    
    while IFS= read -r file; do
        if [ -n "$file" ]; then
            # Check for required ArgoCD Application fields
            if grep -q "apiVersion: argoproj.io" "$file" && \
               grep -q "spec:" "$file" && \
               grep -q "source:" "$file" && \
               grep -q "destination:" "$file"; then
                assert_success "Valid ArgoCD Application: $(basename "$file")"
            else
                assert_failure "Invalid ArgoCD Application structure: $file"
            fi
        fi
    done <<< "$argocd_apps"
}

# Run all manifest tests
run_tests \
    test_manifests_exist \
    test_guestbook_has_manifests \
    test_manifest_syntax \
    test_kubectl_validation \
    test_argocd_applications