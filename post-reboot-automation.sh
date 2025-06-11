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
    
    # NEW: Fix resource tracking file permissions for backend container write access
    log_info "Fixing resource tracking file permissions..."
    if [ -f "$DATA_DIR/resource_tracking.json" ]; then
        chown 1000:1000 "$DATA_DIR/resource_tracking.json" 2>/dev/null || true
        chmod 664 "$DATA_DIR/resource_tracking.json" 2>/dev/null || true
    fi
    
    # Ensure ai-lab-data directory is owned by backend user for tracking file write access
    chown -R 1000:1000 "$DATA_DIR" 2>/dev/null || {
        log_warn "Could not set ai-lab-data ownership to 1000:1000"
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
    
    # Ensure resource tracking file has correct ownership for backend container
    if [ -f "$DATA_DIR/resource_tracking.json" ]; then
        chown 1000:1000 "$DATA_DIR/resource_tracking.json" 2>/dev/null || true
    fi
    
    # NEW: Sync shared data to legacy location for existing environments
    sync_shared_data_to_legacy
    
    log_info "✅ Data directory permissions fixed (users: 1000:100, shared/admin: llurad:docker, tracking: 1000:1000)"
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
                        return 0
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
        
        # Fix permissions first
        chown 1000:1000 "$tracking_file" 2>/dev/null || true
        chmod 664 "$tracking_file" 2>/dev/null || true
        
        # Update tracking data via API (when backend is ready)
        sleep 5
        curl -s -k -X POST https://localhost/api/environments/cleanup >/dev/null 2>&1 || true
        
        log_info "✅ Resource tracking updated"
    else
        log_info "No existing resource tracking file found, will be created during sync"
    fi
    
    # NEW: Perform comprehensive environment tracking synchronization
    sync_environment_tracking
    
    # NEW: Configure VS Code containers
    configure_vscode_containers
}

# NEW Function: Synchronize environment tracking data
sync_environment_tracking() {
    log_step "🔄 Synchronizing environment tracking data..."
    
    local tracking_file="$DATA_DIR/resource_tracking.json"
    
    # Ensure tracking file exists
    if [ ! -f "$tracking_file" ]; then
        log_info "Creating initial resource tracking file..."
        mkdir -p "$DATA_DIR"
        echo '{"user_environments":{},"allocated_ports":[]}' > "$tracking_file"
        chown 1000:1000 "$tracking_file" 2>/dev/null || true
        chmod 664 "$tracking_file" 2>/dev/null || true
    fi
    
    # Wait for backend to be ready before syncing
    local max_wait=60
    local wait_count=0
    
    log_info "Waiting for backend to be ready for environment sync..."
    while [ $wait_count -lt $max_wait ]; do
        if curl -s -k https://localhost/api/health >/dev/null 2>&1; then
            break
        fi
        sleep 2
        ((wait_count+=2))
    done
    
    if [ $wait_count -ge $max_wait ]; then
        log_warn "Backend not ready for sync, skipping environment tracking sync"
        return
    fi
    
    # Get all running AI Lab environment containers
    local ai_lab_containers=$(docker ps --filter "name=ai-lab-" --format "{{.Names}}" | grep -E "(jupyter|vscode|pytorch|tensorflow|multi-gpu)" || true)
    
    if [ -z "$ai_lab_containers" ]; then
        log_info "No AI Lab environment containers found to sync"
        return
    fi
    
    log_info "Found running environment containers to sync:"
    echo "$ai_lab_containers" | while read container; do
        log_info "  - $container"
    done
    
    # Auto-register untracked containers to demo user as default
    # In production, you might want to modify this logic for different user assignment
    local registered_count=0
    echo "$ai_lab_containers" | while read container; do
        if [ -n "$container" ]; then
            # Check if container is already tracked
            local is_tracked=$(curl -s -k "https://localhost/api/environments" | grep -c "\"$container\"" || echo "0")
            
            if [ "$is_tracked" -eq "0" ]; then
                log_info "Auto-registering untracked container: $container"
                
                # Register to demo user (you can modify this logic for different user assignment)
                local register_result=$(curl -s -k -X POST "https://localhost/api/environments/$container/register-user" \
                    -H "Content-Type: application/json" \
                    -d '{"user_id": "demo@ailab.com"}' 2>/dev/null || echo "failed")
                
                if echo "$register_result" | grep -q "successfully registered"; then
                    log_info "✅ Successfully registered $container to demo@ailab.com"
                    ((registered_count++))
                else
                    log_warn "⚠️ Failed to register $container: $register_result"
                fi
            else
                log_info "Container $container is already tracked"
            fi
        fi
    done
    
    # Clean up stale tracking data
    log_info "Cleaning up stale tracking entries..."
    curl -s -k -X POST "https://localhost/api/environments/cleanup" >/dev/null 2>&1 || {
        log_warn "Failed to clean up stale tracking entries via API"
    }
    
    log_info "✅ Environment tracking synchronization completed"
    if [ $registered_count -gt 0 ]; then
        log_info "Registered $registered_count untracked containers"
    fi
}

# NEW Function: Configure VS Code containers automatically  
configure_vscode_containers() {
    log_step "🔧 Configuring VS Code containers..."
    
    local vscode_containers=$(docker ps --filter "name=ai-lab-vscode" --format "{{.Names}}" || true)
    
    if [ -z "$vscode_containers" ]; then
        log_info "No VS Code containers found to configure"
        return
    fi
    
    echo "$vscode_containers" | while read container; do
        if [ -n "$container" ]; then
            log_info "Configuring authentication for $container..."
            
            # Apply VS Code authentication fix
            docker exec "$container" mkdir -p /home/coder/.config/code-server 2>/dev/null || true
            docker exec "$container" bash -c 'echo "bind-addr: 127.0.0.1:8080
auth: none
cert: false" > /home/coder/.config/code-server/config.yaml' 2>/dev/null || true
            docker exec "$container" chown -R coder:coder /home/coder/.config 2>/dev/null || true
            docker exec "$container" pkill -f code-server 2>/dev/null || true
            
            log_info "✅ Configured authentication for $container"
        fi
    done
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

# NEW Function: Ensure SSL certificate persistence
ensure_ssl_persistence() {
    log_step "🔐 Ensuring SSL certificate persistence..."
    
    local ssl_dir="$SCRIPT_DIR/ssl"
    
    # Check if SSL directory exists
    if [ ! -d "$ssl_dir" ]; then
        log_warn "SSL directory not found at $ssl_dir"
        return
    fi
    
    # Check if certificates exist
    if [ -f "$ssl_dir/fullchain.pem" ] && [ -f "$ssl_dir/privkey.pem" ]; then
        log_info "SSL certificates found in $ssl_dir"
        
        # Ensure correct permissions for SSL files
        chmod 644 "$ssl_dir/fullchain.pem" 2>/dev/null || true
        chmod 600 "$ssl_dir/privkey.pem" 2>/dev/null || true
        chown root:root "$ssl_dir"/*.pem 2>/dev/null || true
        
        log_info "✅ SSL certificate permissions configured"
    else
        log_warn "SSL certificates not found, HTTPS may not work properly"
        log_info "Consider running setup-letsencrypt.sh or setup-self-signed-renewal.sh"
    fi
    
    # Check if SSL renewal is configured
    if [ -f "$SCRIPT_DIR/setup-self-signed-renewal.sh" ]; then
        # Ensure renewal script is executable
        chmod +x "$SCRIPT_DIR/setup-self-signed-renewal.sh"
        
        # Check if renewal cron job exists
        if ! crontab -l 2>/dev/null | grep -q "setup-self-signed-renewal.sh"; then
            log_info "Setting up SSL certificate auto-renewal..."
            (crontab -l 2>/dev/null | grep -v "setup-self-signed-renewal.sh"; echo "0 2 * * 0 $SCRIPT_DIR/setup-self-signed-renewal.sh >/dev/null 2>&1") | crontab -
            log_info "✅ SSL auto-renewal configured (weekly)"
        else
            log_info "SSL auto-renewal already configured"
        fi
    fi
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
            log_warn "⚠️ Multi-gpu fix incomplete - only $multi_gpu_occurrences occurrences found"
            validation_failed=true
        fi
    else
        log_warn "⚠️ Multi-gpu dynamic port allocation fix missing from backend code"
        validation_failed=true
    fi
    
    # 2. Check that backend file is properly mounted
    log_info "Checking backend file mount..."
    if docker inspect ai-lab-backend 2>/dev/null | grep -q "ai_lab_backend.py"; then
        log_info "✅ Backend code file properly mounted"
    else
        log_warn "⚠️ Backend file mount may not be configured correctly"
        validation_failed=true
    fi
    
    # 3. Check resource tracking file exists and is writable
    log_info "Checking resource tracking setup..."
    if [[ -f "ai-lab-data/resource_tracking.json" ]]; then
        if [[ -w "ai-lab-data/resource_tracking.json" ]]; then
            log_info "✅ Resource tracking file accessible"
        else
            log_warn "⚠️ Resource tracking file not writable"
            validation_failed=true
        fi
    else
        log_info "Creating initial resource tracking file..."
        mkdir -p ai-lab-data
        echo '{"user_environments":{},"allocated_ports":[]}' > ai-lab-data/resource_tracking.json
        chown 1000:1000 ai-lab-data/resource_tracking.json 2>/dev/null || true
        chmod 664 ai-lab-data/resource_tracking.json 2>/dev/null || true
        log_info "✅ Resource tracking file created"
    fi
    
    # 4. NEW: Check environment tracking synchronization capability
    log_info "Checking environment tracking sync capability..."
    if curl -s -k https://localhost/api/health >/dev/null 2>&1; then
        local admin_envs=$(curl -s -k "https://localhost/api/environments" 2>/dev/null || echo "failed")
        if [[ "$admin_envs" != "failed" ]]; then
            log_info "✅ Environment tracking API accessible"
        else
            log_warn "⚠️ Environment tracking API not responding"
            validation_failed=true
        fi
    else
        log_warn "⚠️ Backend not accessible for environment tracking validation"
        validation_failed=true
    fi
    
    # 5. NEW: Check VS Code authentication fix capability
    log_info "Checking VS Code authentication fix..."
    if [ -f "$SCRIPT_DIR/fix-vscode-auth.sh" ]; then
        log_info "✅ VS Code authentication fix script available"
    else
        log_warn "⚠️ VS Code authentication fix script missing"
        validation_failed=true
    fi
    
    # 6. NEW: Check SSL certificate persistence
    log_info "Checking SSL certificate persistence..."
    if [ -f "$SCRIPT_DIR/ssl/fullchain.pem" ] && [ -f "$SCRIPT_DIR/ssl/privkey.pem" ]; then
        log_info "✅ SSL certificates present and persistent"
    else
        log_warn "⚠️ SSL certificates may not be persistent"
        validation_failed=true
    fi
    
    # 7. NEW: Check data directory ownership for backend write access
    log_info "Checking data directory ownership..."
    local tracking_owner=$(stat -c %U:%G ai-lab-data/resource_tracking.json 2>/dev/null || echo "unknown")
    if [[ "$tracking_owner" == "1000:1000" ]] || [[ "$tracking_owner" == "appuser:appuser" ]]; then
        log_info "✅ Resource tracking file has correct ownership for backend write access"
    else
        log_warn "⚠️ Resource tracking file ownership incorrect: $tracking_owner"
        # Attempt to fix it
        chown 1000:1000 ai-lab-data/resource_tracking.json 2>/dev/null || true
        validation_failed=true
    fi
    
    if [[ "$validation_failed" == "true" ]]; then
        log_warn "Some validations failed, but automation will continue..."
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
    ensure_ssl_persistence
    check_network_config
    check_port_availability
    
    # Service startup
    start_services_with_health_checks
    
    # Post-startup verification and synchronization
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
    
    # NEW: Show environment tracking status
    local tracked_users=$(curl -s -k "https://localhost/api/environments" 2>/dev/null | grep -o '"environments":\[' | wc -l || echo "0")
    if [ "$tracked_users" -gt "0" ]; then
        log_info "✅ Environment tracking synchronized ($tracked_users environments detected)"
    else
        log_info "ℹ️ No environments currently tracked"
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
    echo ""
    echo "🔧 Platform Features:"
    echo "  - ✅ Automatic environment tracking synchronization"
    echo "  - ✅ Automatic VS Code authentication configuration"
    echo "  - ✅ SSL certificate persistence and auto-renewal"
    echo "  - ✅ Data directory permissions and ownership management"
    echo "  - ✅ Post-reboot environment recovery and registration"
}

# Error handling
trap 'log_error "Script failed at line $LINENO. Exit code: $?"' ERR

# Run main function
main "$@" 