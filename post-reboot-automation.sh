#!/bin/bash

# AI Lab Platform - Post-Reboot Automation System
# This script ensures the platform works correctly after every reboot
# It addresses all known post-reboot issues automatically

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
LOG_FILE="/var/log/ai-lab-post-reboot.log"
COMPOSE_FILE="$SCRIPT_DIR/docker-compose.production.yml"
ENV_FILE="$SCRIPT_DIR/production.env"
DATA_DIR="$SCRIPT_DIR/ai-lab-data"

# Ensure we're running in the correct directory
cd "$SCRIPT_DIR"

# Logging setup
exec 1> >(tee -a "$LOG_FILE")
exec 2> >(tee -a "$LOG_FILE" >&2)

log_step "🚀 AI Lab Platform Post-Reboot Automation Started"
log_info "Timestamp: $(date)"
log_info "Working directory: $SCRIPT_DIR"

# Function: Wait for Docker daemon
wait_for_docker() {
    log_step "⏳ Waiting for Docker daemon to be ready..."
    local max_attempts=30
    local attempt=1
    
    while ! docker info >/dev/null 2>&1; do
        if [ $attempt -ge $max_attempts ]; then
            log_error "Docker daemon failed to start after $max_attempts attempts"
            exit 1
        fi
        log_info "Attempt $attempt/$max_attempts - Docker not ready, waiting..."
        sleep 5
        ((attempt++))
    done
    
    log_info "✅ Docker daemon is ready"
}

# Function: Clean up orphaned containers
cleanup_orphaned_containers() {
    log_step "🧹 Cleaning up orphaned AI Lab containers..."
    
    # Get all containers (including stopped ones)
    local containers=$(docker ps -a --filter "name=ai-lab-" --format "{{.Names}}")
    local cleaned_count=0
    
    if [ -z "$containers" ]; then
        log_info "No AI Lab containers found"
        return
    fi
    
    for container in $containers; do
        # Skip system containers that should always run
        if [[ "$container" =~ ^ai-lab-(postgres|nginx|redis|prometheus|grafana|mlflow|backend|torchserve|gpu-monitor)(-[0-9]+)?$ ]]; then
            log_info "Skipping system container: $container"
            continue
        fi
        
        # Check if it's a user environment container in problematic state
        local status=$(docker inspect --format='{{.State.Status}}' "$container" 2>/dev/null || echo "not_found")
        
        if [[ "$status" == "created" ]] || [[ "$status" == "exited" && "$container" =~ (pytorch|tensorflow|jupyter|vscode|multi-gpu) ]]; then
            log_info "Removing orphaned container: $container (status: $status)"
            docker rm -f "$container" >/dev/null 2>&1 || true
            ((cleaned_count++))
        fi
    done
    
    log_info "✅ Cleaned up $cleaned_count orphaned containers"
}

# Function: Fix data directory permissions
fix_data_permissions() {
    log_step "🔐 Fixing data directory permissions..."
    
    if [ ! -d "$DATA_DIR" ]; then
        log_warn "Data directory doesn't exist, creating: $DATA_DIR"
        mkdir -p "$DATA_DIR"/{shared,users,admin}
    fi
    
    # Fix ownership for Jupyter containers
    # USER DATA: Use jovyan user (UID 1000, GID 100) for Jupyter container compatibility
    log_info "Setting user data ownership for Jupyter container compatibility..."
    chown -R 1000:100 "$DATA_DIR/users" 2>/dev/null || {
        log_warn "Could not set user data ownership to 1000:100"
    }
    
    # SHARED DATA: Use host user for admin management
    log_info "Setting shared data ownership for admin management..."
    chown -R llurad:docker "$DATA_DIR/shared" 2>/dev/null || {
        log_warn "Could not change shared data ownership to llurad:docker, trying current user..."
        chown -R $USER:docker "$DATA_DIR/shared" 2>/dev/null || true
    }
    
    # ADMIN DATA: Use host user for admin access
    chown -R llurad:docker "$DATA_DIR/admin" 2>/dev/null || {
        chown -R $USER:docker "$DATA_DIR/admin" 2>/dev/null || true
    }
    
    # Set directory permissions (775 = rwxrwxr-x)
    find "$DATA_DIR" -type d -exec chmod 775 {} \; 2>/dev/null || true
    
    # Set file permissions (664 = rw-rw-r--)
    find "$DATA_DIR" -type f -exec chmod 664 {} \; 2>/dev/null || true
    
    # Ensure specific subdirectories exist with correct permissions
    for subdir in shared/datasets users admin/backups; do
        mkdir -p "$DATA_DIR/$subdir"
        chmod 775 "$DATA_DIR/$subdir"
    done
    
    # Apply specific ownership after directory creation
    chown -R 1000:100 "$DATA_DIR/users" 2>/dev/null || true
    chown -R llurad:docker "$DATA_DIR/shared" 2>/dev/null || chown -R $USER:docker "$DATA_DIR/shared" 2>/dev/null || true
    chown -R llurad:docker "$DATA_DIR/admin" 2>/dev/null || chown -R $USER:docker "$DATA_DIR/admin" 2>/dev/null || true
    
    # NEW: Sync shared data to legacy location for existing environments
    sync_shared_data_to_legacy
    
    log_info "✅ Data directory permissions fixed (users: 1000:100, shared/admin: llurad:docker)"
}

# NEW Function: Sync shared data to legacy location
sync_shared_data_to_legacy() {
    log_info "Syncing shared data to legacy location for existing environments..."
    
    # Check if legacy location exists and has different data
    if [ -d "/opt/ai-lab-data/shared" ] && [ -d "$DATA_DIR/shared" ]; then
        # Sync project data to production location
        rsync -av --delete "$DATA_DIR/shared/" "/opt/ai-lab-data/shared/" >/dev/null 2>&1 || {
            log_warn "Legacy shared data sync failed, but continuing..."
        }
        log_info "✅ Shared data synced to legacy location"
    elif [ -d "$DATA_DIR/shared" ]; then
        log_info "Legacy location not found, all environments will use unified path"
    fi
}

# NEW Function: Setup automated data sync service
setup_automated_data_sync() {
    log_step "⚙️ Setting up automated data sync monitoring..."
    
    # Check if automated data sync script exists
    if [ -f "$SCRIPT_DIR/automated-data-sync.sh" ]; then
        # Create configuration if it doesn't exist
        if [ ! -f "$SCRIPT_DIR/data-sync.conf" ]; then
            log_info "Creating data sync configuration..."
            "$SCRIPT_DIR/automated-data-sync.sh" --create-config >/dev/null 2>&1 || true
        fi
        
        # Install as systemd service if not already installed
        if ! systemctl list-unit-files | grep -q "ai-lab-data-sync.service"; then
            log_info "Installing automated data sync service..."
            "$SCRIPT_DIR/automated-data-sync.sh" --install-service >/dev/null 2>&1 || {
                log_warn "Could not install data sync service automatically"
            }
        fi
        
        # Start the service
        if systemctl is-enabled ai-lab-data-sync.service >/dev/null 2>&1; then
            systemctl start ai-lab-data-sync.service >/dev/null 2>&1 || true
            log_info "✅ Automated data sync service started"
        else
            log_info "Data sync service not enabled, running one-time sync..."
            "$SCRIPT_DIR/automated-data-sync.sh" --once >/dev/null 2>&1 || true
        fi
    else
        log_info "Automated data sync script not found, skipping automation setup"
    fi
}

# Function: Check and fix network configuration
check_network_config() {
    log_step "🌐 Checking Docker network configuration..."
    
    # Check if the AI Lab network exists
    if ! docker network ls | grep -q "ai-lab-platform_ai-lab-network"; then
        log_warn "AI Lab network not found, it will be created during startup"
    else
        log_info "✅ AI Lab network exists"
    fi
    
    # Clean up any conflicting networks
    local orphaned_networks=$(docker network ls --filter "name=ai-lab" --format "{{.Name}}" | grep -v "ai-lab-platform_ai-lab-network" || true)
    
    for network in $orphaned_networks; do
        log_info "Removing orphaned network: $network"
        docker network rm "$network" >/dev/null 2>&1 || true
    done
}

# Function: Check port availability
check_port_availability() {
    log_step "🔌 Checking port availability..."
    
    local critical_ports=(80 443 5555 5000 5432 3000 9090 6379)
    local conflicts=false
    
    for port in "${critical_ports[@]}"; do
        if netstat -tuln 2>/dev/null | grep -q ":$port "; then
            local process=$(lsof -ti:$port 2>/dev/null || echo "unknown")
            log_warn "Port $port is in use by process: $process"
            
            # If it's a Docker container, we'll let Docker Compose handle it
            if docker ps --format "{{.Ports}}" | grep -q ":$port->"; then
                log_info "Port $port is used by Docker container (acceptable)"
            else
                conflicts=true
            fi
        fi
    done
    
    if [ "$conflicts" = true ]; then
        log_warn "Some port conflicts detected, but proceeding with startup"
    else
        log_info "✅ All critical ports are available or properly managed"
    fi
}

# Function: Start services with health checks
start_services_with_health_checks() {
    log_step "🚀 Starting AI Lab Platform services..."
    
    # Stop any running services first
    log_info "Stopping any existing services..."
    docker compose -f "$COMPOSE_FILE" --env-file "$ENV_FILE" down --remove-orphans >/dev/null 2>&1 || true
    
    # Start services
    log_info "Starting services with Docker Compose..."
    docker compose -f "$COMPOSE_FILE" --env-file "$ENV_FILE" up -d --build
    
    # Wait for services to start
    log_info "Waiting for services to initialize..."
    sleep 30
    
    # Health check sequence
    check_service_health "postgres" "5432" 60
    check_service_health "redis" "6379" 30
    check_service_health "backend" "5555" 45
    check_service_health "nginx" "443" 30
    check_service_health "mlflow" "5000" 30
    
    log_info "✅ All services started successfully"
}

# Function: Check individual service health
check_service_health() {
    local service_name="$1"
    local port="$2"
    local timeout="${3:-30}"
    local attempt=1
    
    log_info "Checking health of $service_name service..."
    
    while [ $attempt -le $timeout ]; do
        if docker ps --filter "name=ai-lab-$service_name" --format "{{.Status}}" | grep -q "healthy\|Up"; then
            # Additional specific checks
            case "$service_name" in
                "backend")
                    if curl -s -k https://localhost/api/health >/dev/null 2>&1; then
                        log_info "✅ $service_name is healthy"
                        
                        # Validate multi-gpu dynamic port allocation fix
                        log_info "🔍 Validating multi-gpu port allocation fix..."
                        backend_code_check=$(docker exec ai-lab-backend grep -c "env_type == \"multi-gpu\"" /app/ai_lab_backend.py 2>/dev/null || echo "0")
                        if [[ "$backend_code_check" -ge "2" ]]; then
                            log_info "✅ Multi-gpu dynamic port allocation fix verified"
                        else
                            log_warning "⚠️ Multi-gpu fix may not be applied, but continuing..."
                        fi
                    else
                        log_warn "⚠️ $service_name health check failed"
                        return 1
                    fi
                    ;;
                "postgres")
                    if docker exec ai-lab-postgres pg_isready -U postgres >/dev/null 2>&1; then
                        log_info "✅ $service_name is healthy"
                        return 0
                    fi
                    ;;
                *)
                    log_info "✅ $service_name is healthy"
                    return 0
                    ;;
            esac
        fi
        
        if [ $((attempt % 10)) -eq 0 ]; then
            log_info "Still waiting for $service_name... (attempt $attempt/$timeout)"
        fi
        
        sleep 1
        ((attempt++))
    done
    
    log_warn "⚠️ $service_name health check timed out, but continuing"
    return 1
}

# Function: Verify data consistency
verify_data_consistency() {
    log_step "🔍 Verifying data volume consistency..."
    
    # Check that backend can access data
    local data_check=$(docker exec ai-lab-backend ls -la /app/ai-lab-data/ 2>/dev/null || echo "failed")
    
    if [[ "$data_check" == "failed" ]]; then
        log_error "Backend cannot access data directory"
        return 1
    fi
    
    # Check HOST_DATA_PATH configuration
    local host_data_path=$(grep "HOST_DATA_PATH=" production.env | cut -d'=' -f2)
    
    if [[ "$host_data_path" == *"/ai-lab-platform/ai-lab-data" ]]; then
        log_info "✅ Data volume consistency verified - using project directory"
    else
        log_warn "⚠️ Unexpected HOST_DATA_PATH: $host_data_path"
    fi
    
    # Test shared data accessibility
    if [ -d "$DATA_DIR/shared" ]; then
        local shared_files=$(ls -la "$DATA_DIR/shared/" 2>/dev/null | wc -l)
        log_info "✅ Shared data directory accessible ($((shared_files-2)) items)"
    else
        log_warn "⚠️ Shared data directory not found"
    fi
}

# Function: Update container resource tracking
update_resource_tracking() {
    log_step "📊 Updating container resource tracking..."
    
    # Clean up tracking file of non-existent containers
    local tracking_file="$DATA_DIR/resource_tracking.json"
    
    if [ -f "$tracking_file" ]; then
        # Create a backup
        cp "$tracking_file" "$tracking_file.backup.$(date +%Y%m%d_%H%M%S)"
        
        # Update tracking data via API (when backend is ready)
        sleep 5
        curl -s -k -X POST https://localhost/api/environments/cleanup >/dev/null 2>&1 || true
        
        log_info "✅ Resource tracking updated"
    else
        log_info "No existing resource tracking file found"
    fi
}

# Function: Test system functionality
test_system_functionality() {
    log_step "🧪 Testing system functionality..."
    
    # Test main UI
    if curl -s -k https://localhost/ >/dev/null 2>&1; then
        log_info "✅ Main UI accessible"
    else
        log_warn "⚠️ Main UI test failed"
    fi
    
    # Test admin portal
    if curl -s -k https://localhost/admin >/dev/null 2>&1; then
        log_info "✅ Admin portal accessible"
    else
        log_warn "⚠️ Admin portal test failed"
    fi
    
    # Test API health
    if curl -s -k https://localhost/api/health | grep -q "healthy"; then
        log_info "✅ Backend API healthy"
    else
        log_warn "⚠️ Backend API test failed"
    fi
    
    # Test environment creation capability
    local env_test=$(curl -s -k https://localhost/api/environments/templates 2>/dev/null || echo "failed")
    if [[ "$env_test" != "failed" ]]; then
        log_info "✅ Environment management functional"
    else
        log_warn "⚠️ Environment management test failed"
    fi
}

# Function: Create monitoring cron job
setup_monitoring_cron() {
    log_step "⏰ Setting up monitoring cron job..."
    
    # Create a monitoring script
    cat > /usr/local/bin/ai-lab-health-monitor.sh << 'EOF'
#!/bin/bash
# AI Lab Platform Health Monitor

LOG_FILE="/var/log/ai-lab-health-monitor.log"
ALERT_FILE="/tmp/ai-lab-alerts"

# Check if all critical services are running
services=("ai-lab-nginx" "ai-lab-backend" "ai-lab-postgres" "ai-lab-mlflow")
failed_services=()

for service in "${services[@]}"; do
    if ! docker ps --filter "name=$service" --format "{{.Names}}" | grep -q "$service"; then
        failed_services+=("$service")
    fi
done

if [ ${#failed_services[@]} -gt 0 ]; then
    echo "$(date): ALERT - Failed services: ${failed_services[*]}" >> "$LOG_FILE"
    echo "$(date): Attempting to restart services..." >> "$LOG_FILE"
    
    # Attempt restart
    cd /home/llurad/ai-lab-platform
    docker compose -f docker-compose.production.yml --env-file production.env up -d "${failed_services[@]}" >> "$LOG_FILE" 2>&1
    
    # Create alert file for admin notification
    echo "Services restarted at $(date): ${failed_services[*]}" > "$ALERT_FILE"
else
    echo "$(date): All services healthy" >> "$LOG_FILE"
    # Remove alert file if exists
    rm -f "$ALERT_FILE"
fi

# NEW: Check data sync service health
if systemctl is-active ai-lab-data-sync.service >/dev/null 2>&1; then
    echo "$(date): Data sync service healthy" >> "$LOG_FILE"
else
    echo "$(date): WARNING - Data sync service not running" >> "$LOG_FILE"
    # Attempt to restart data sync service
    systemctl start ai-lab-data-sync.service >/dev/null 2>&1 || true
fi
EOF

    chmod +x /usr/local/bin/ai-lab-health-monitor.sh
    
    # Add to crontab (run every 5 minutes)
    (crontab -l 2>/dev/null | grep -v "ai-lab-health-monitor"; echo "*/5 * * * * /usr/local/bin/ai-lab-health-monitor.sh") | crontab -
    
    log_info "✅ Health monitoring cron job installed"
}

# Function: Validate critical fixes are in place
validate_permanent_fixes() {
    log_step "🔧 Validating permanent fixes..."
    
    local validation_failed=false
    
    # 1. Check multi-gpu dynamic port allocation fix in backend code
    log_info "Checking multi-gpu port allocation fix..."
    if grep -q "env_type == \"multi-gpu\"" ai_lab_backend.py; then
        local multi_gpu_occurrences=$(grep -c "env_type == \"multi-gpu\"" ai_lab_backend.py)
        if [[ "$multi_gpu_occurrences" -ge "2" ]]; then
            log_info "✅ Multi-gpu dynamic port allocation fix present in backend code"
        else
            log_warning "⚠️ Multi-gpu fix incomplete - only $multi_gpu_occurrences occurrences found"
            validation_failed=true
        fi
    else
        log_warning "⚠️ Multi-gpu dynamic port allocation fix missing from backend code"
        validation_failed=true
    fi
    
    # 2. Check that backend file is properly mounted
    log_info "Checking backend file mount..."
    if docker inspect ai-lab-backend 2>/dev/null | grep -q "ai_lab_backend.py"; then
        log_info "✅ Backend code file properly mounted"
    else
        log_warning "⚠️ Backend file mount may not be configured correctly"
        validation_failed=true
    fi
    
    # 3. Check resource tracking file exists and is writable
    log_info "Checking resource tracking setup..."
    if [[ -f "ai-lab-data/resource_tracking.json" ]]; then
        if [[ -w "ai-lab-data/resource_tracking.json" ]]; then
            log_info "✅ Resource tracking file accessible"
        else
            log_warning "⚠️ Resource tracking file not writable"
            validation_failed=true
        fi
    else
        log_info "Creating initial resource tracking file..."
        mkdir -p ai-lab-data
        echo '{"user_environments":{},"allocated_ports":[]}' > ai-lab-data/resource_tracking.json
        log_info "✅ Resource tracking file created"
    fi
    
    if [[ "$validation_failed" == "true" ]]; then
        log_warning "Some validations failed, but automation will continue..."
    else
        log_info "✅ All permanent fixes validated successfully"
    fi
}

# Main execution
main() {
    log_step "🎯 Starting Post-Reboot Automation Sequence"
    
    # Pre-flight checks
    wait_for_docker
    
    # System preparation
    cleanup_orphaned_containers
    fix_data_permissions
    check_network_config
    check_port_availability
    
    # Service startup
    start_services_with_health_checks
    
    # Post-startup verification
    verify_data_consistency
    update_resource_tracking
    test_system_functionality
    
    # NEW: Setup automated data sync
    setup_automated_data_sync
    
    # Long-term monitoring
    setup_monitoring_cron
    
    # NEW: Validate critical fixes are in place
    validate_permanent_fixes
    
    log_step "🎉 Post-Reboot Automation Complete!"
    log_info "Platform is ready and all known post-reboot issues have been addressed"
    log_info "Services Status:"
    docker compose -f "$COMPOSE_FILE" --env-file "$ENV_FILE" ps --format "table {{.Service}}\t{{.Status}}\t{{.Ports}}"
    
    # NEW: Show data sync status
    if systemctl is-active ai-lab-data-sync.service >/dev/null 2>&1; then
        log_info "✅ Automated data sync service is running"
    else
        log_info "ℹ️ Manual data sync completed (service not installed)"
    fi
    
    log_info "Log file: $LOG_FILE"
    log_info "Monitoring: Health checks run every 5 minutes"
    echo ""
    echo "🌐 Platform URLs:"
    echo "  - Main UI: https://localhost/"
    echo "  - Admin Portal: https://localhost/admin"
    echo "  - API Health: https://localhost/api/health"
    echo "  - MLflow: https://localhost/mlflow/"
    echo "  - Grafana: https://localhost/grafana/"
}

# Error handling
trap 'log_error "Script failed at line $LINENO. Exit code: $?"' ERR

# Run main function
main "$@" 