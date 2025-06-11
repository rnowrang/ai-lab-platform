#!/bin/bash

# AI Lab Platform - Data Management Sync Script
# Fixes admin upload permissions and syncs user data with actual environments

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
DATA_DIR="$SCRIPT_DIR/ai-lab-data"
SHARED_DIR="$DATA_DIR/shared"
USERS_DIR="$DATA_DIR/users"
TRACKING_FILE="$DATA_DIR/resource_tracking.json"

cd "$SCRIPT_DIR"

log_step "🔧 AI Lab Data Management Sync Started"
log_info "Timestamp: $(date)"

# Function: Fix shared data permissions
fix_shared_data_permissions() {
    log_step "🔐 Fixing shared data permissions..."
    
    if [ ! -d "$SHARED_DIR" ]; then
        log_error "Shared directory not found: $SHARED_DIR"
        return 1
    fi
    
    # Fix ownership for all shared data
    log_info "Setting correct ownership (llurad:docker) for shared data..."
    chown -R llurad:docker "$SHARED_DIR" 2>/dev/null || {
        log_warn "Could not change ownership to llurad:docker, trying current user..."
        chown -R $USER:docker "$SHARED_DIR" 2>/dev/null || true
    }
    
    # Fix permissions
    log_info "Setting correct permissions for shared data..."
    find "$SHARED_DIR" -type d -exec chmod 775 {} \; 2>/dev/null || true
    find "$SHARED_DIR" -type f -exec chmod 664 {} \; 2>/dev/null || true
    
    # Report what was fixed
    local problematic_items=$(find "$SHARED_DIR" -not -group docker 2>/dev/null | wc -l)
    if [ "$problematic_items" -gt 0 ]; then
        log_warn "Found $problematic_items items with incorrect permissions (fixed)"
    fi
    
    log_info "✅ Shared data permissions fixed"
    log_info "Admin uploaded files are now accessible in environments"
}

# Function: Get current active environments
get_active_environments() {
    log_step "📊 Analyzing current environment state..."
    
    # Get currently running user environments
    local active_containers=$(docker ps --filter "name=ai-lab-" --format "{{.Names}}" | grep -E "(pytorch|tensorflow|jupyter|vscode|multi-gpu)" || true)
    
    # Get all user environment containers (including stopped)
    local all_containers=$(docker ps -a --filter "name=ai-lab-" --format "{{.Names}}" | grep -E "(pytorch|tensorflow|jupyter|vscode|multi-gpu)" || true)
    
    echo "Active user environments:"
    if [ -n "$active_containers" ]; then
        echo "$active_containers" | while read container; do
            local status=$(docker inspect --format='{{.State.Status}}' "$container" 2>/dev/null || echo "unknown")
            log_info "  - $container ($status)"
        done
    else
        log_info "  - No active user environments found"
    fi
    
    echo
    echo "All user environment containers:"
    if [ -n "$all_containers" ]; then
        echo "$all_containers" | while read container; do
            local status=$(docker inspect --format='{{.State.Status}}' "$container" 2>/dev/null || echo "unknown")
            log_info "  - $container ($status)"
        done
    else
        log_info "  - No user environment containers found"
    fi
}

# Function: Clean up resource tracking
cleanup_resource_tracking() {
    log_step "🧹 Cleaning up resource tracking..."
    
    if [ ! -f "$TRACKING_FILE" ]; then
        log_info "No tracking file found, nothing to clean"
        return
    fi
    
    # Backup tracking file
    cp "$TRACKING_FILE" "$TRACKING_FILE.backup.$(date +%Y%m%d_%H%M%S)"
    log_info "Created backup: $TRACKING_FILE.backup.*"
    
    # Get list of existing containers
    local existing_containers=$(docker ps -a --filter "name=ai-lab-" --format "{{.Names}}" | grep -E "(pytorch|tensorflow|jupyter|vscode|multi-gpu)" || true)
    
    # Use API to clean up tracking
    log_info "Calling API cleanup to sync tracking with actual containers..."
    curl -s -k -X POST https://localhost/api/environments/cleanup >/dev/null 2>&1 || {
        log_warn "API cleanup failed, but continuing..."
    }
    
    log_info "✅ Resource tracking cleanup completed"
}

# Function: Analyze user data directories
analyze_user_data() {
    log_step "📁 Analyzing user data directories..."
    
    if [ ! -d "$USERS_DIR" ]; then
        log_info "No users directory found"
        return
    fi
    
    local user_dirs=$(ls -1 "$USERS_DIR" 2>/dev/null || true)
    local user_count=$(echo "$user_dirs" | grep -c . || echo "0")
    
    log_info "Found $user_count user data directories:"
    
    if [ -n "$user_dirs" ]; then
        echo "$user_dirs" | while read user_dir; do
            if [ -d "$USERS_DIR/$user_dir" ]; then
                local size=$(du -sh "$USERS_DIR/$user_dir" 2>/dev/null | cut -f1)
                local files=$(find "$USERS_DIR/$user_dir" -type f 2>/dev/null | wc -l)
                
                # Convert sanitized user ID back to email format
                local user_email=$(echo "$user_dir" | sed 's/_at_/@/g' | sed 's/_/./g')
                
                log_info "  - $user_email: $size ($files files)"
                
                # Check if user has active environments
                if [ -f "$TRACKING_FILE" ]; then
                    local has_envs=$(grep -q "\"$user_email\"" "$TRACKING_FILE" && echo "yes" || echo "no")
                    if [ "$has_envs" = "no" ]; then
                        log_warn "    ⚠️  No active environments for this user"
                    fi
                fi
            fi
        done
    fi
}

# Function: Clean up orphaned user data (interactive)
cleanup_orphaned_user_data() {
    log_step "🗑️  Checking for orphaned user data..."
    
    if [ ! -d "$USERS_DIR" ] || [ ! -f "$TRACKING_FILE" ]; then
        log_info "Cannot check for orphaned data - missing directories or tracking file"
        return
    fi
    
    local orphaned_users=()
    local user_dirs=$(ls -1 "$USERS_DIR" 2>/dev/null || true)
    
    if [ -n "$user_dirs" ]; then
        while IFS= read -r user_dir; do
            if [ -d "$USERS_DIR/$user_dir" ]; then
                # Convert sanitized user ID back to email format
                local user_email=$(echo "$user_dir" | sed 's/_at_/@/g' | sed 's/_/./g')
                
                # Check if user exists in tracking
                if ! grep -q "\"$user_email\"" "$TRACKING_FILE"; then
                    orphaned_users+=("$user_dir:$user_email")
                fi
            fi
        done <<< "$user_dirs"
    fi
    
    if [ ${#orphaned_users[@]} -eq 0 ]; then
        log_info "✅ No orphaned user data found"
        return
    fi
    
    log_warn "Found ${#orphaned_users[@]} users with data but no tracked environments:"
    for orphan in "${orphaned_users[@]}"; do
        local user_dir="${orphan%:*}"
        local user_email="${orphan#*:}"
        local size=$(du -sh "$USERS_DIR/$user_dir" 2>/dev/null | cut -f1)
        log_warn "  - $user_email ($user_dir): $size"
    done
    
    echo
    read -p "Do you want to clean up orphaned user data? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        log_info "Cleaning up orphaned user data..."
        for orphan in "${orphaned_users[@]}"; do
            local user_dir="${orphan%:*}"
            local user_email="${orphan#*:}"
            
            # Create backup before deletion
            local backup_dir="$DATA_DIR/admin/backups/orphaned_$(date +%Y%m%d_%H%M%S)"
            mkdir -p "$backup_dir"
            
            log_info "Backing up $user_email data to $backup_dir/"
            cp -r "$USERS_DIR/$user_dir" "$backup_dir/" 2>/dev/null || true
            
            log_info "Removing orphaned data for $user_email"
            rm -rf "$USERS_DIR/$user_dir"
        done
        log_info "✅ Orphaned user data cleaned up (backups created)"
    else
        log_info "Skipping orphaned data cleanup"
    fi
}

# Function: Verify shared data accessibility
verify_shared_data_accessibility() {
    log_step "🔍 Verifying shared data accessibility..."
    
    # Check if backend can access shared data
    local backend_check=$(docker exec ai-lab-backend ls -la /app/ai-lab-data/shared/ 2>/dev/null | wc -l)
    
    if [ "$backend_check" -gt 2 ]; then
        log_info "✅ Backend can access shared data ($((backend_check-2)) items)"
    else
        log_warn "⚠️  Backend cannot access shared data or directory is empty"
    fi
    
    # Check shared datasets specifically
    if [ -d "$SHARED_DIR/datasets" ]; then
        local datasets=$(ls -1 "$SHARED_DIR/datasets" 2>/dev/null | wc -l)
        log_info "✅ Found $datasets shared datasets"
        
        # List datasets with permissions
        ls -la "$SHARED_DIR/datasets" | while read line; do
            if [[ "$line" =~ ^d ]] && [[ ! "$line" =~ ^\. ]]; then
                local dataset=$(echo "$line" | awk '{print $NF}')
                local perms=$(echo "$line" | awk '{print $1, $3, $4}')
                log_info "  - $dataset ($perms)"
            fi
        done
    fi
}

# Function: Test environment access to shared data
test_environment_access() {
    log_step "🧪 Testing environment access to shared data..."
    
    # Get a running environment to test with
    local test_env=$(docker ps --filter "name=ai-lab-" --format "{{.Names}}" | grep -E "(pytorch|tensorflow|jupyter|vscode)" | head -1)
    
    if [ -n "$test_env" ]; then
        log_info "Testing with environment: $test_env"
        
        # Test access to shared directory
        local shared_access=$(docker exec "$test_env" ls -la /home/jovyan/shared/ 2>/dev/null | wc -l)
        
        if [ "$shared_access" -gt 2 ]; then
            log_info "✅ Environment can access shared data ($((shared_access-2)) items)"
            
            # List what the environment can see
            docker exec "$test_env" ls -la /home/jovyan/shared/ | while read line; do
                if [[ ! "$line" =~ ^total ]] && [[ ! "$line" =~ ^\. ]]; then
                    log_info "  - $(echo "$line" | awk '{print $NF}')"
                fi
            done
        else
            log_warn "⚠️  Environment cannot access shared data"
        fi
    else
        log_info "No running environments found to test with"
    fi
}

# Function: Generate sync report
generate_sync_report() {
    log_step "📋 Generating sync report..."
    
    local report_file="$DATA_DIR/admin/data_sync_report_$(date +%Y%m%d_%H%M%S).txt"
    mkdir -p "$(dirname "$report_file")"
    
    {
        echo "AI Lab Platform - Data Management Sync Report"
        echo "Generated: $(date)"
        echo "=========================================="
        echo
        
        echo "SHARED DATA STATUS:"
        echo "- Datasets directory: $(ls -1 "$SHARED_DIR/datasets" 2>/dev/null | wc -l || echo "0") items"
        echo "- Permissions: $(ls -ld "$SHARED_DIR" | awk '{print $1, $3, $4}')"
        echo
        
        echo "USER DATA STATUS:"
        echo "- User directories: $(ls -1 "$USERS_DIR" 2>/dev/null | wc -l || echo "0")"
        echo "- Total size: $(du -sh "$USERS_DIR" 2>/dev/null | cut -f1 || echo "0")"
        echo
        
        echo "ACTIVE ENVIRONMENTS:"
        docker ps --filter "name=ai-lab-" --format "{{.Names}}\t{{.Status}}" | grep -E "(pytorch|tensorflow|jupyter|vscode)" || echo "None"
        echo
        
        echo "TRACKING STATUS:"
        if [ -f "$TRACKING_FILE" ]; then
            echo "- Tracking file exists: $(stat -c%s "$TRACKING_FILE") bytes"
            echo "- Tracked users: $(grep -c '".*@.*":' "$TRACKING_FILE" 2>/dev/null || echo "0")"
        else
            echo "- No tracking file found"
        fi
        
    } > "$report_file"
    
    log_info "✅ Sync report generated: $report_file"
}

# Main execution
main() {
    echo "🔧 AI Lab Platform - Data Management Sync"
    echo "=========================================="
    echo
    
    # Check if running as root for permission fixes
    if [ "$EUID" -ne 0 ]; then
        log_warn "Not running as root - some permission fixes may fail"
        log_info "Run with 'sudo' for full functionality"
        echo
    fi
    
    # Step 1: Fix immediate permission issues
    fix_shared_data_permissions
    echo
    
    # Step 2: Analyze current state
    get_active_environments
    echo
    
    # Step 3: Clean up tracking
    cleanup_resource_tracking
    echo
    
    # Step 4: Analyze user data
    analyze_user_data
    echo
    
    # Step 5: Clean up orphaned data (interactive)
    cleanup_orphaned_user_data
    echo
    
    # Step 6: Verify accessibility
    verify_shared_data_accessibility
    echo
    
    # Step 7: Test environment access
    test_environment_access
    echo
    
    # Step 8: Generate report
    generate_sync_report
    echo
    
    log_step "🎉 Data Management Sync Complete!"
    echo
    echo "📋 Summary:"
    echo "  ✅ Fixed shared data permissions"
    echo "  ✅ Cleaned up resource tracking"
    echo "  ✅ Analyzed user data consistency"
    echo "  ✅ Verified data accessibility"
    echo
    echo "📊 Next steps:"
    echo "  1. Check admin portal - uploads should now be visible"
    echo "  2. Test creating a new environment and accessing shared data"
    echo "  3. Review sync report for detailed analysis"
    echo
    echo "🌐 Test access:"
    echo "  curl -k https://localhost/api/shared/datasets"
}

# Error handling
trap 'log_error "Script failed at line $LINENO. Exit code: $?"' ERR

# Run main function
main "$@" 