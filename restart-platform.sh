#!/bin/bash

# AI Lab Platform - Quick Restart Script
# Use this script to restart the platform without a full reboot
# It incorporates all the critical fixes and synchronization

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_step() {
    echo -e "${BLUE}[STEP]${NC} $1"
}

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMPOSE_FILE="$SCRIPT_DIR/docker-compose.production.yml"
ENV_FILE="$SCRIPT_DIR/production.env"
DATA_DIR="$SCRIPT_DIR/ai-lab-data"

# Ensure we're running in the correct directory
cd "$SCRIPT_DIR"

log_step "🔄 AI Lab Platform Quick Restart"
log_info "Timestamp: $(date)"
log_info "Working directory: $SCRIPT_DIR"

# Function: Fix essential permissions
fix_essential_permissions() {
    log_step "🔐 Fixing essential permissions..."
    
    # Fix resource tracking file ownership for backend write access
    if [ -f "$DATA_DIR/resource_tracking.json" ]; then
        chown 1000:1000 "$DATA_DIR/resource_tracking.json" 2>/dev/null || true
        chmod 664 "$DATA_DIR/resource_tracking.json" 2>/dev/null || true
        log_info "✅ Resource tracking file permissions fixed"
    fi
    
    # Ensure ai-lab-data directory has correct ownership
    chown -R 1000:1000 "$DATA_DIR" 2>/dev/null || {
        log_warn "Could not set ai-lab-data ownership to 1000:1000"
    }
    
    # Fix specific subdirectory ownership
    chown -R 1000:100 "$DATA_DIR/users" 2>/dev/null || true
    chown -R $(whoami):docker "$DATA_DIR/shared" 2>/dev/null || true
    chown -R $(whoami):docker "$DATA_DIR/admin" 2>/dev/null || true
    
    log_info "✅ Essential permissions fixed"
}

# Function: Restart services
restart_services() {
    log_step "🚀 Restarting AI Lab Platform services..."
    
    # Stop services gracefully
    log_info "Stopping services..."
    docker compose -f "$COMPOSE_FILE" --env-file "$ENV_FILE" down --remove-orphans
    
    # Start services
    log_info "Starting services..."
    docker compose -f "$COMPOSE_FILE" --env-file "$ENV_FILE" up -d
    
    # Wait for services to be ready
    log_info "Waiting for services to initialize..."
    sleep 30
    
    # Quick health check
    local max_attempts=20
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        if curl -s -k https://localhost/api/health >/dev/null 2>&1; then
            log_info "✅ Backend is ready"
            break
        fi
        
        if [ $((attempt % 5)) -eq 0 ]; then
            log_info "Still waiting for backend... (attempt $attempt/$max_attempts)"
        fi
        
        sleep 2
        ((attempt++))
    done
    
    if [ $attempt -gt $max_attempts ]; then
        log_warn "Backend health check timed out, but continuing..."
    fi
}

# Function: Sync environment tracking
sync_environment_tracking() {
    log_step "🔄 Synchronizing environment tracking..."
    
    # Wait a bit more for backend to be fully ready
    sleep 10
    
    # Get running environment containers
    local env_containers=$(docker ps --filter "name=ai-lab-" --format "{{.Names}}" | grep -E "(jupyter|vscode|pytorch|tensorflow|multi-gpu)" || true)
    
    if [ -z "$env_containers" ]; then
        log_info "No environment containers found to sync"
        return
    fi
    
    log_info "Found environment containers:"
    echo "$env_containers" | while read container; do
        log_info "  - $container"
    done
    
    # Auto-register untracked containers
    local registered_count=0
    echo "$env_containers" | while read container; do
        if [ -n "$container" ]; then
            # Check if already tracked by checking admin environments API
            local is_tracked=$(curl -s -k "https://localhost/api/environments" 2>/dev/null | grep -c "\"$container\"" || echo "0")
            
            if [ "$is_tracked" -eq "0" ]; then
                log_info "Registering untracked container: $container"
                
                local register_result=$(curl -s -k -X POST "https://localhost/api/environments/$container/register-user" \
                    -H "Content-Type: application/json" \
                    -d '{"user_id": "demo@ailab.com"}' 2>/dev/null || echo "failed")
                
                if echo "$register_result" | grep -q "successfully registered"; then
                    log_info "✅ Registered $container to demo@ailab.com"
                    ((registered_count++))
                else
                    log_warn "⚠️ Failed to register $container"
                fi
            fi
        fi
    done
    
    # Clean up stale entries
    curl -s -k -X POST "https://localhost/api/environments/cleanup" >/dev/null 2>&1 || true
    
    log_info "✅ Environment tracking synchronized"
    if [ $registered_count -gt 0 ]; then
        log_info "Registered $registered_count new containers"
    fi
}

# Function: Configure VS Code containers
configure_vscode_containers() {
    log_step "🔧 Configuring VS Code containers..."
    
    local vscode_containers=$(docker ps --filter "name=ai-lab-vscode" --format "{{.Names}}" || true)
    
    if [ -z "$vscode_containers" ]; then
        log_info "No VS Code containers found"
        return
    fi
    
    echo "$vscode_containers" | while read container; do
        if [ -n "$container" ]; then
            log_info "Configuring $container..."
            
            # Apply authentication fix
            docker exec "$container" mkdir -p /home/coder/.config/code-server 2>/dev/null || true
            docker exec "$container" bash -c 'echo "bind-addr: 127.0.0.1:8080
auth: none
cert: false" > /home/coder/.config/code-server/config.yaml' 2>/dev/null || true
            docker exec "$container" chown -R coder:coder /home/coder/.config 2>/dev/null || true
            docker exec "$container" pkill -f code-server 2>/dev/null || true
            
            log_info "✅ Configured $container"
        fi
    done
}

# Function: Test platform functionality
test_platform() {
    log_step "🧪 Testing platform functionality..."
    
    local tests_passed=0
    local total_tests=5
    
    # Test 1: Backend health
    if curl -s -k https://localhost/api/health | grep -q "healthy"; then
        log_info "✅ Backend health check passed"
        ((tests_passed++))
    else
        log_warn "❌ Backend health check failed"
    fi
    
    # Test 2: Main UI
    if curl -s -k https://localhost/ >/dev/null 2>&1; then
        log_info "✅ Main UI accessible"
        ((tests_passed++))
    else
        log_warn "❌ Main UI test failed"
    fi
    
    # Test 3: Admin portal
    if curl -s -k https://localhost/admin >/dev/null 2>&1; then
        log_info "✅ Admin portal accessible"
        ((tests_passed++))
    else
        log_warn "❌ Admin portal test failed"
    fi
    
    # Test 4: Environment API
    if curl -s -k https://localhost/api/environments >/dev/null 2>&1; then
        log_info "✅ Environment API accessible"
        ((tests_passed++))
    else
        log_warn "❌ Environment API test failed"
    fi
    
    # Test 5: User environment tracking
    local user_envs=$(curl -s -k "https://localhost/api/users/demo@ailab.com/environments" 2>/dev/null || echo "failed")
    if [[ "$user_envs" != "failed" ]]; then
        log_info "✅ User environment tracking functional"
        ((tests_passed++))
    else
        log_warn "❌ User environment tracking test failed"
    fi
    
    log_info "Platform tests: $tests_passed/$total_tests passed"
    
    if [ $tests_passed -eq $total_tests ]; then
        log_info "🎉 All tests passed! Platform is fully operational."
    else
        log_warn "⚠️ Some tests failed, but platform may still be functional."
    fi
}

# Main execution
main() {
    log_step "🎯 Starting Quick Platform Restart"
    
    # Essential fixes
    fix_essential_permissions
    
    # Restart services
    restart_services
    
    # Post-restart synchronization
    sync_environment_tracking
    configure_vscode_containers
    
    # Verification
    test_platform
    
    log_step "✅ Quick Restart Complete!"
    echo ""
    echo "🌐 Platform URLs:"
    echo "  - Main UI: https://localhost/"
    echo "  - Admin Portal: https://localhost/admin"
    echo "  - API Health: https://localhost/api/health"
    echo ""
    echo "💡 If you continue to have issues, run the full post-reboot automation:"
    echo "   sudo ./post-reboot-automation.sh"
}

# Error handling
trap 'log_error "Script failed at line $LINENO. Exit code: $?"' ERR

# Check if running as root for permissions
if [ "$EUID" -ne 0 ]; then
    log_warn "Not running as root - some permission fixes may fail"
    log_info "For full functionality, run: sudo ./restart-platform.sh"
fi

# Run main function
main "$@" 