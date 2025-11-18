#!/usr/bin/env bash
# Unit tests for application code
set -euo pipefail

source tests/scripts/test-helpers.sh
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

test_guestbook_structure() {
    local guestbook_dir="${REPO_ROOT}/apps/guestbook"
    
    assert_directory_exists "$guestbook_dir"
    assert_file_exists "${guestbook_dir}/package.json"
    assert_file_exists "${guestbook_dir}/server.js"
}

test_package_json_validity() {
    local package_json="${REPO_ROOT}/apps/guestbook/package.json"
    
    if [ -f "$package_json" ]; then
        # Test JSON syntax
        if python3 -c "import json; json.load(open('$package_json'))" 2>/dev/null; then
            assert_success "package.json has valid JSON syntax"
        else
            assert_failure "package.json has invalid JSON syntax"
        fi
        
        # Check for required fields
        if grep -q '"name"' "$package_json" && \
           grep -q '"version"' "$package_json" && \
           grep -q '"main"' "$package_json"; then
            assert_success "package.json has required fields"
        else
            assert_failure "package.json missing required fields"
        fi
        
        # Check for start script
        if grep -q '"start"' "$package_json"; then
            assert_success "package.json has start script"
        else
            assert_warning "package.json missing start script"
        fi
    else
        assert_failure "package.json not found"
    fi
}

test_server_js_syntax() {
    local server_js="${REPO_ROOT}/apps/guestbook/server.js"
    
    if [ -f "$server_js" ]; then
        # Basic Node.js syntax check
        if node -c "$server_js" 2>/dev/null; then
            assert_success "server.js has valid Node.js syntax"
        else
            assert_failure "server.js has syntax errors"
        fi
    else
        assert_failure "server.js not found"
    fi
}

test_server_js_structure() {
    local server_js="${REPO_ROOT}/apps/guestbook/server.js"
    
    if [ -f "$server_js" ]; then
        # Check for Express.js patterns
        if grep -q "express" "$server_js"; then
            assert_success "server.js uses Express framework"
        else
            assert_warning "server.js doesn't appear to use Express"
        fi
        
        # Check for health endpoint
        if grep -q "/health" "$server_js"; then
            assert_success "server.js has health check endpoint"
        else
            assert_warning "server.js missing health check endpoint"
        fi
        
        # Check for API endpoints
        if grep -q "app.get\|app.post" "$server_js"; then
            assert_success "server.js has API endpoints"
        else
            assert_warning "server.js missing API endpoints"
        fi
        
        # Check for port configuration
        if grep -q "process.env.PORT\|port" "$server_js"; then
            assert_success "server.js has port configuration"
        else
            assert_warning "server.js missing port configuration"
        fi
    fi
}

test_dockerfile_exists() {
    local dockerfile="${REPO_ROOT}/apps/guestbook/Dockerfile"
    
    if [ -f "$dockerfile" ]; then
        assert_success "Dockerfile exists for guestbook"
        
        # Check Dockerfile content
        if grep -q "FROM" "$dockerfile" && \
           grep -q "COPY\|ADD" "$dockerfile" && \
           grep -q "CMD\|ENTRYPOINT" "$dockerfile"; then
            assert_success "Dockerfile has proper structure"
        else
            assert_warning "Dockerfile missing essential instructions"
        fi
    else
        assert_warning "Dockerfile not found (may use base images)"
    fi
}

test_public_directory() {
    local public_dir="${REPO_ROOT}/apps/guestbook/public"
    
    if [ -d "$public_dir" ]; then
        assert_success "Public directory exists"
        
        # Check for basic web files
        if find "$public_dir" -name "*.html" -o -name "*.css" -o -name "*.js" | grep -q .; then
            assert_success "Public directory contains web assets"
        else
            assert_warning "Public directory exists but no web assets found"
        fi
    else
        assert_warning "Public directory not found"
    fi
}

test_dependencies_installable() {
    local guestbook_dir="${REPO_ROOT}/apps/guestbook"
    
    if ! command -v npm &>/dev/null; then
        assert_skip "npm not available to test dependency installation"
        return
    fi
    
    if [ -f "${guestbook_dir}/package.json" ]; then
        # Test in a temporary directory to avoid polluting the repo
        local temp_dir
        temp_dir=$(mktemp -d)
        cp "${guestbook_dir}/package.json" "$temp_dir/"
        
        if (cd "$temp_dir" && npm install --production --silent &>/dev/null); then
            assert_success "npm dependencies can be installed"
        else
            assert_warning "npm install failed (may need network or specific npm version)"
        fi
        
        rm -rf "$temp_dir"
    else
        assert_skip "package.json not found"
    fi
}

# Run all application tests
run_tests \
    test_guestbook_structure \
    test_package_json_validity \
    test_server_js_syntax \
    test_server_js_structure \
    test_dockerfile_exists \
    test_public_directory \
    test_dependencies_installable