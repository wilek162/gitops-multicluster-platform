#!/usr/bin/env bash
# test-runner.sh - Main test orchestrator for GitOps platform
set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Test results tracking
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_SKIPPED=0

# Logging functions
log_info() {
    echo -e "${BLUE}ℹ${NC} $*"
}

log_success() {
    echo -e "${GREEN}✓${NC} $*"
    ((TESTS_PASSED++))
}

log_error() {
    echo -e "${RED}✗${NC} $*"
    ((TESTS_FAILED++))
}

log_warning() {
    echo -e "${YELLOW}⚠${NC} $*"
}

log_skip() {
    echo -e "${YELLOW}⊝${NC} $*"
    ((TESTS_SKIPPED++))
}

# Test execution wrapper
run_test() {
    local test_name="$1"
    local test_script="$2"
    
    echo ""
    echo "═══════════════════════════════════════════════════════════"
    log_info "Running: $test_name"
    echo "═══════════════════════════════════════════════════════════"
    
    if bash "$test_script"; then
        log_success "$test_name passed"
        return 0
    else
        log_error "$test_name failed"
        return 1
    fi
}

# Display usage
usage() {
    cat << EOF
GitOps Platform Test Runner

Usage: $0 [OPTIONS]

OPTIONS:
    --all               Run all tests
    --unit              Run unit tests only
    --integration       Run integration tests only
    --e2e               Run end-to-end tests only
    --module <name>     Run specific module test
    --quick             Run quick smoke tests only
    --cleanup           Clean up test resources
    --help              Show this help message

MODULES:
    bootstrap           Test cluster bootstrap
    argocd              Test ArgoCD installation
    manifests           Test Kubernetes manifests
    app                 Test guestbook application
    promotion           Test promotion workflow
    scripts             Test helper scripts

EXAMPLES:
    $0 --all                    # Run everything
    $0 --module bootstrap       # Test bootstrap only
    $0 --quick                  # Fast smoke test
    $0 --integration --e2e      # Integration + E2E tests

EOF
}

# Print test summary
print_summary() {
    echo ""
    echo "═══════════════════════════════════════════════════════════"
    echo "                     TEST SUMMARY"
    echo "═══════════════════════════════════════════════════════════"
    echo -e "${GREEN}Passed:${NC}  $TESTS_PASSED"
    echo -e "${RED}Failed:${NC}  $TESTS_FAILED"
    echo -e "${YELLOW}Skipped:${NC} $TESTS_SKIPPED"
    echo "───────────────────────────────────────────────────────────"
    local total=$((TESTS_PASSED + TESTS_FAILED))
    if [ $total -gt 0 ]; then
        local percentage=$((TESTS_PASSED * 100 / total))
        echo -e "Success Rate: ${percentage}%"
    fi
    echo "═══════════════════════════════════════════════════════════"
    
    if [ $TESTS_FAILED -gt 0 ]; then
        exit 1
    fi
}

# Main test execution
main() {
    local run_all=false
    local run_unit=false
    local run_integration=false
    local run_e2e=false
    local run_quick=false
    local run_module=""
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --all)
                run_all=true
                shift
                ;;
            --unit)
                run_unit=true
                shift
                ;;
            --integration)
                run_integration=true
                shift
                ;;
            --e2e)
                run_e2e=true
                shift
                ;;
            --quick)
                run_quick=true
                shift
                ;;
            --module)
                run_module="$2"
                shift 2
                ;;
            --cleanup)
                bash tests/scripts/cleanup.sh
                exit 0
                ;;
            --help)
                usage
                exit 0
                ;;
            *)
                echo "Unknown option: $1"
                usage
                exit 1
                ;;
        esac
    done
    
    # Default to quick tests if no options specified
    if ! $run_all && ! $run_unit && ! $run_integration && ! $run_e2e && [ -z "$run_module" ]; then
        run_quick=true
    fi
    
    log_info "GitOps Platform Test Suite"
    log_info "Starting test execution..."
    
    # Run tests based on flags
    if $run_quick; then
        run_test "Quick Smoke Test" "tests/quick-smoke.sh"
    fi
    
    if $run_all || $run_unit; then
        run_test "Unit Tests - Bootstrap Scripts" "tests/unit/test-bootstrap.sh"
        run_test "Unit Tests - Promotion Scripts" "tests/unit/test-promotion.sh"
        run_test "Unit Tests - Manifest Validation" "tests/unit/test-manifests.sh"
        run_test "Unit Tests - Application Code" "tests/unit/test-app.sh"
    fi
    
    if $run_all || $run_integration; then
        run_test "Integration - ArgoCD Setup" "tests/integration/test-argocd-setup.sh"
        run_test "Integration - App Deployment" "tests/integration/test-app-deployment.sh"
        run_test "Integration - Sync Behavior" "tests/integration/test-sync.sh"
    fi
    
    if $run_all || $run_e2e; then
        run_test "E2E - Full Workflow" "tests/e2e/test-full-workflow.sh"
        run_test "E2E - Promotion Flow" "tests/e2e/test-promotion-flow.sh"
    fi
    
    if [ -n "$run_module" ]; then
        case $run_module in
            bootstrap)
                run_test "Module Test - Bootstrap" "tests/unit/test-bootstrap.sh"
                ;;
            argocd)
                run_test "Module Test - ArgoCD" "tests/modules/test-argocd.sh"
                ;;
            manifests)
                run_test "Module Test - Manifests" "tests/modules/test-manifests.sh"
                ;;
            app)
                run_test "Module Test - Application" "tests/modules/test-app.sh"
                ;;
            promotion)
                run_test "Module Test - Promotion" "tests/modules/test-promotion.sh"
                ;;
            scripts)
                run_test "Module Test - Scripts" "tests/modules/test-scripts.sh"
                ;;
            *)
                log_error "Unknown module: $run_module"
                exit 1
                ;;
        esac
    fi
    
    print_summary
}

main "$@"