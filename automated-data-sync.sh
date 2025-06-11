#!/bin/bash

# AI Lab Platform - Automated Data Sync System
# Automatically handles admin upload permissions and user data consistency
# Can run as daemon, cron job, or integrated into post-reboot automation

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${GREEN}[INFO]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

log_step() {
    echo -e "${BLUE}[STEP]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DATA_DIR="$SCRIPT_DIR/ai-lab-data"
SHARED_DIR="$DATA_DIR/shared"
USERS_DIR="$DATA_DIR/users"
TRACKING_FILE="$DATA_DIR/resource_tracking.json"
LOG_FILE="/var/log/ai-lab-data-sync.log"
LOCK_FILE="/var/run/ai-lab-data-sync.lock"
CONFIG_FILE="$SCRIPT_DIR/data-sync.conf"

# Default configuration
SYNC_INTERVAL=300  # 5 minutes
PERMISSION_CHECK_INTERVAL=60  # 1 minute
LEGACY_SYNC_ENABLED=true
AUTO_CLEANUP_ORPHANED=false
DAEMON_MODE=false

# Load configuration if exists
[ -f "$CONFIG_FILE" ] && source "$CONFIG_FILE"

cd "$SCRIPT_DIR"

# Function: Check if another instance is running
check_lock() {
    if [ -f "$LOCK_FILE" ]; then
        local pid=$(cat "$LOCK_FILE")
        if kill -0 "$pid" 2>/dev/null; then
            log_warn "Another instance is running (PID: $pid)"
            exit 1
        else
            log_warn "Removing stale lock file"
            rm -f "$LOCK_FILE"
        fi
    fi
    echo $$ > "$LOCK_FILE"
}

# Function: Cleanup on exit
cleanup() {
    if [ -f "$LOCK_FILE" ]; then
        rm -f "$LOCK_FILE" 2>/dev/null || true
    fi
    exit 0
}

trap cleanup EXIT INT TERM

# Function: Quick permission check and fix
quick_permission_fix() {
    local changed=false
    
    # Check if shared directory has correct permissions
    if [ -d "$SHARED_DIR" ]; then
        # Check for files with wrong group
        local wrong_group=$(find "$SHARED_DIR" -not -group docker 2>/dev/null | wc -l)
        
        if [ "$wrong_group" -gt 0 ]; then
            log_info "Found $wrong_group items with incorrect permissions, fixing..."
            
            # Fix ownership
            chown -R llurad:docker "$SHARED_DIR" 2>/dev/null || {
                chown -R $USER:docker "$SHARED_DIR" 2>/dev/null || true
            }
            
            # Fix permissions
            find "$SHARED_DIR" -type d -exec chmod 775 {} \; 2>/dev/null || true
            find "$SHARED_DIR" -type f -exec chmod 664 {} \; 2>/dev/null || true
            
            changed=true
            log_info "✅ Fixed permissions for $wrong_group items"
            
            # Sync to legacy location if enabled
            if [ "$LEGACY_SYNC_ENABLED" = true ]; then
                sync_to_legacy_location
            fi
        fi
    fi
    
    if [ "$changed" = true ]; then
        return 0
    else
        return 1
    fi
}

# Function: Sync to legacy location for existing environments
sync_to_legacy_location() {
    if [ -d "$SHARED_DIR" ] && [ -d "/opt/ai-lab-data" ]; then
        log_info "Syncing shared data to legacy location for existing environments..."
        rsync -av --delete "$SHARED_DIR/" "/opt/ai-lab-data/shared/" >/dev/null 2>&1 || {
            log_warn "Legacy sync failed, but continuing..."
        }
        log_info "✅ Legacy sync completed"
    fi
}

# Function: Clean up resource tracking automatically
auto_cleanup_tracking() {
    if [ -f "$TRACKING_FILE" ] && [ -f "$SCRIPT_DIR/post-reboot-automation.sh" ]; then
        # Use API cleanup if available
        curl -s -k -X POST https://localhost/api/environments/cleanup >/dev/null 2>&1 || {
            log_warn "API cleanup failed during auto-sync"
        }
        log_info "✅ Resource tracking auto-cleaned"
    fi
}

# Function: Monitor for orphaned user data
monitor_orphaned_data() {
    if [ ! -d "$USERS_DIR" ] || [ ! -f "$TRACKING_FILE" ]; then
        return
    fi
    
    local orphaned_count=0
    local user_dirs=$(ls -1 "$USERS_DIR" 2>/dev/null || true)
    
    if [ -n "$user_dirs" ]; then
        while IFS= read -r user_dir; do
            if [ -d "$USERS_DIR/$user_dir" ]; then
                local user_email=$(echo "$user_dir" | sed 's/_at_/@/g' | sed 's/_/./g')
                
                # Check if user exists in tracking
                if ! grep -q "\"$user_email\"" "$TRACKING_FILE" 2>/dev/null; then
                    ((orphaned_count++))
                    
                    if [ "$AUTO_CLEANUP_ORPHANED" = true ]; then
                        local backup_dir="$DATA_DIR/admin/backups/auto_orphaned_$(date +%Y%m%d_%H%M%S)"
                        mkdir -p "$backup_dir"
                        
                        log_info "Auto-cleaning orphaned data for $user_email (backed up)"
                        cp -r "$USERS_DIR/$user_dir" "$backup_dir/" 2>/dev/null || true
                        rm -rf "$USERS_DIR/$user_dir"
                    fi
                fi
            fi
        done <<< "$user_dirs"
    fi
    
    if [ "$orphaned_count" -gt 0 ] && [ "$AUTO_CLEANUP_ORPHANED" != true ]; then
        log_warn "Found $orphaned_count orphaned user directories (set AUTO_CLEANUP_ORPHANED=true to auto-clean)"
    fi
}

# Function: File system change detector
detect_changes() {
    local change_detected=false
    local current_hash=""
    local stored_hash=""
    local hash_file="$DATA_DIR/admin/.sync_hash"
    
    # Generate hash of shared directory structure and permissions
    if [ -d "$SHARED_DIR" ]; then
        current_hash=$(find "$SHARED_DIR" -type f -exec stat -c '%n %s %Y %a %U %G' {} \; 2>/dev/null | sort | md5sum | cut -d' ' -f1)
        
        if [ -f "$hash_file" ]; then
            stored_hash=$(cat "$hash_file")
        fi
        
        if [ "$current_hash" != "$stored_hash" ]; then
            change_detected=true
            echo "$current_hash" > "$hash_file"
            log_info "Detected changes in shared data structure"
        fi
    fi
    
    if [ "$change_detected" = true ]; then
        return 0
    else
        return 1
    fi
}

# Function: Health check integration
perform_health_check() {
    local issues=0
    
    # Check backend access to shared data
    if ! docker exec ai-lab-backend ls /app/ai-lab-data/shared/ >/dev/null 2>&1; then
        log_warn "Backend cannot access shared data"
        ((issues++))
    fi
    
    # Check if any running environment exists
    local running_envs=$(docker ps --filter "name=ai-lab-" --format "{{.Names}}" | grep -E "(pytorch|tensorflow|jupyter|vscode)" | wc -l)
    
    if [ "$running_envs" -gt 0 ]; then
        # Test environment access
        local test_env=$(docker ps --filter "name=ai-lab-" --format "{{.Names}}" | grep -E "(pytorch|tensorflow|jupyter|vscode)" | head -1)
        if ! docker exec "$test_env" ls /home/jovyan/shared/ >/dev/null 2>&1; then
            log_warn "Environment $test_env cannot access shared data"
            ((issues++))
        fi
    fi
    
    # Check API health
    if ! curl -s -k https://localhost/api/health | grep -q "healthy"; then
        log_warn "API health check failed"
        ((issues++))
    fi
    
    if [ "$issues" -eq 0 ]; then
        log_info "✅ Health check passed"
    else
        log_warn "⚠️ Health check found $issues issues"
    fi
    
    return $issues
}

# Function: Generate status report
generate_status_report() {
    local report_file="$DATA_DIR/admin/auto_sync_status_$(date +%Y%m%d).txt"
    mkdir -p "$(dirname "$report_file")"
    
    {
        echo "AI Lab Platform - Automated Data Sync Status"
        echo "Generated: $(date)"
        echo "============================================"
        echo
        echo "SYNC CONFIGURATION:"
        echo "- Sync interval: ${SYNC_INTERVAL}s"
        echo "- Permission check interval: ${PERMISSION_CHECK_INTERVAL}s"
        echo "- Legacy sync enabled: $LEGACY_SYNC_ENABLED"
        echo "- Auto cleanup orphaned: $AUTO_CLEANUP_ORPHANED"
        echo "- Daemon mode: $DAEMON_MODE"
        echo
        echo "SHARED DATA STATUS:"
        if [ -d "$SHARED_DIR" ]; then
            echo "- Datasets: $(ls -1 "$SHARED_DIR/datasets" 2>/dev/null | wc -l || echo "0")"
            echo "- Total size: $(du -sh "$SHARED_DIR" 2>/dev/null | cut -f1 || echo "0")"
            echo "- Permissions: $(ls -ld "$SHARED_DIR" | awk '{print $1, $3, $4}')"
        else
            echo "- Shared directory not found"
        fi
        echo
        echo "RECENT ACTIVITY:"
        tail -10 "$LOG_FILE" 2>/dev/null || echo "No recent activity"
        
    } > "$report_file"
    
    # Keep only last 7 days of reports
    find "$DATA_DIR/admin" -name "auto_sync_status_*.txt" -mtime +7 -delete 2>/dev/null || true
}

# Function: Daemon mode
run_daemon() {
    log_info "🔄 Starting automated data sync daemon"
    log_info "Sync interval: ${SYNC_INTERVAL}s, Permission check: ${PERMISSION_CHECK_INTERVAL}s"
    
    local last_full_sync=0
    local last_permission_check=0
    
    while true; do
        local current_time=$(date +%s)
        
        # Quick permission check (more frequent)
        if [ $((current_time - last_permission_check)) -ge $PERMISSION_CHECK_INTERVAL ]; then
            if quick_permission_fix; then
                log_info "Permissions auto-fixed"
            fi
            last_permission_check=$current_time
        fi
        
        # Full sync (less frequent)
        if [ $((current_time - last_full_sync)) -ge $SYNC_INTERVAL ]; then
            log_step "🔄 Running automated full sync"
            
            # Check for changes
            if detect_changes; then
                log_info "Changes detected, performing full sync"
                
                # Sync to legacy location
                if [ "$LEGACY_SYNC_ENABLED" = true ]; then
                    sync_to_legacy_location
                fi
                
                # Cleanup tracking
                auto_cleanup_tracking
                
                # Monitor orphaned data
                monitor_orphaned_data
                
                # Health check
                perform_health_check
                
                log_info "✅ Full sync completed"
            fi
            
            last_full_sync=$current_time
            
            # Generate daily status report
            if [ "$(date +%H%M)" = "0200" ]; then  # 2 AM
                generate_status_report
            fi
        fi
        
        sleep 10  # Check every 10 seconds
    done
}

# Function: One-time sync
run_once() {
    log_step "🔄 Running one-time automated sync"
    
    # Fix permissions
    quick_permission_fix
    
    # Sync to legacy location
    if [ "$LEGACY_SYNC_ENABLED" = true ]; then
        sync_to_legacy_location
    fi
    
    # Cleanup tracking
    auto_cleanup_tracking
    
    # Monitor orphaned data
    monitor_orphaned_data
    
    # Health check
    perform_health_check
    
    # Generate status report
    generate_status_report
    
    log_step "✅ One-time sync completed"
}

# Function: Install as systemd service
install_service() {
    log_info "Installing automated data sync service..."
    
    # Create service file
    cat > "/tmp/ai-lab-data-sync.service" << EOF
[Unit]
Description=AI Lab Platform Automated Data Sync
After=docker.service ai-lab-startup.service
Wants=docker.service
Requires=docker.service

[Service]
Type=simple
User=root
WorkingDirectory=$SCRIPT_DIR
ExecStart=$SCRIPT_DIR/automated-data-sync.sh --daemon
Restart=always
RestartSec=30
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF
    
    # Install service
    sudo mv "/tmp/ai-lab-data-sync.service" "/etc/systemd/system/"
    sudo systemctl daemon-reload
    sudo systemctl enable ai-lab-data-sync.service
    
    log_info "✅ Service installed: ai-lab-data-sync.service"
    log_info "Start with: sudo systemctl start ai-lab-data-sync.service"
}

# Function: Create configuration file
create_config() {
    cat > "$CONFIG_FILE" << EOF
# AI Lab Platform - Automated Data Sync Configuration

# Sync interval in seconds (default: 300 = 5 minutes)
SYNC_INTERVAL=300

# Permission check interval in seconds (default: 60 = 1 minute)
PERMISSION_CHECK_INTERVAL=60

# Enable syncing to legacy /opt/ai-lab-data location for existing environments
LEGACY_SYNC_ENABLED=true

# Automatically clean up orphaned user data (with backup)
AUTO_CLEANUP_ORPHANED=false

# Log file location
LOG_FILE=/var/log/ai-lab-data-sync.log
EOF
    
    log_info "✅ Configuration file created: $CONFIG_FILE"
    log_info "Edit this file to customize automation settings"
}

# Function: Show usage
show_usage() {
    echo "AI Lab Platform - Automated Data Sync"
    echo "Usage: $0 [OPTIONS]"
    echo
    echo "Options:"
    echo "  --daemon                Run in daemon mode (continuous monitoring)"
    echo "  --once                  Run one-time sync and exit"
    echo "  --install-service       Install as systemd service"
    echo "  --create-config         Create configuration file"
    echo "  --status                Show current status"
    echo "  --help                  Show this help message"
    echo
    echo "Examples:"
    echo "  $0 --once              # Run sync once"
    echo "  $0 --daemon            # Run as daemon"
    echo "  sudo $0 --install-service  # Install as system service"
}

# Function: Show status
show_status() {
    echo "AI Lab Platform - Automated Data Sync Status"
    echo "============================================"
    echo
    
    # Check if service is installed
    if systemctl list-unit-files | grep -q "ai-lab-data-sync.service"; then
        echo "Service Status:"
        systemctl status ai-lab-data-sync.service --no-pager -l || true
        echo
    else
        echo "Service: Not installed (run --install-service to install)"
        echo
    fi
    
    # Check configuration
    if [ -f "$CONFIG_FILE" ]; then
        echo "Configuration:"
        cat "$CONFIG_FILE" | grep -E "^[A-Z_]+" || true
        echo
    else
        echo "Configuration: Not found (run --create-config to create)"
        echo
    fi
    
    # Check recent logs
    if [ -f "$LOG_FILE" ]; then
        echo "Recent Activity (last 10 lines):"
        tail -10 "$LOG_FILE"
        echo
    else
        echo "Logs: No activity logged yet"
        echo
    fi
    
    # Quick health check
    echo "Health Check:"
    if perform_health_check; then
        echo "✅ All systems operational"
    else
        echo "⚠️ Issues detected (check logs for details)"
    fi
}

# Main execution
main() {
    # Ensure log directory exists
    sudo mkdir -p "$(dirname "$LOG_FILE")"
    sudo touch "$LOG_FILE"
    sudo chown $USER:$USER "$LOG_FILE" 2>/dev/null || true
    
    case "${1:-}" in
        --daemon)
            DAEMON_MODE=true
            check_lock
            run_daemon
            ;;
        --once)
            check_lock
            run_once
            ;;
        --install-service)
            install_service
            ;;
        --create-config)
            create_config
            ;;
        --status)
            show_status
            ;;
        --help|"")
            show_usage
            ;;
        *)
            echo "Unknown option: $1"
            show_usage
            exit 1
            ;;
    esac
}

# Run main function
main "$@" 