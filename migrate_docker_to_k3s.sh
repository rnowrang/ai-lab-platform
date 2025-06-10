#!/bin/bash

set -e

# Migration script from Docker Compose to K3s deployment

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_step() { echo -e "${BLUE}[STEP]${NC} $1"; }

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   log_error "This script must be run as root"
   exit 1
fi

# Configuration
DATA_PATH=${DATA_PATH:-"/opt/ai-lab-data"}
BACKUP_PATH=${BACKUP_PATH:-"/opt/backups"}

# Step 1: Backup current Docker deployment
backup_docker_deployment() {
    log_step "Backing up Docker deployment..."
    
    BACKUP_DIR="$BACKUP_PATH/docker_to_k3s_$(date +%Y%m%d_%H%M%S)"
    mkdir -p "$BACKUP_DIR"
    
    # Export Docker volumes
    log_info "Exporting PostgreSQL data..."
    docker exec ai-lab-postgres pg_dumpall -U postgres > "$BACKUP_DIR/postgres_full_backup.sql"
    
    log_info "Backing up MLflow artifacts..."
    cp -r "$DATA_PATH/mlflow-artifacts" "$BACKUP_DIR/"
    
    log_info "Backing up user data..."
    cp -r "$DATA_PATH/user-data" "$BACKUP_DIR/" 2>/dev/null || true
    
    log_info "Saving Docker Compose configuration..."
    cp docker-compose*.yml "$BACKUP_DIR/"
    cp production.env "$BACKUP_DIR/" 2>/dev/null || true
    
    # Save current container states
    docker ps -a > "$BACKUP_DIR/container_states.txt"
    
    log_info "Backup completed: $BACKUP_DIR"
}

# Step 2: Stop Docker Compose services
stop_docker_services() {
    log_step "Stopping Docker Compose services..."
    
    docker-compose -f docker-compose.production.yml down || \
    docker-compose -f docker-compose.yml down || \
    log_warn "Docker Compose services may already be stopped"
    
    # Stop any remaining containers
    docker ps -q | xargs -r docker stop
}

# Step 3: Prepare for K3s installation
prepare_k3s_migration() {
    log_step "Preparing for K3s installation..."
    
    # Create K3s data structure
    mkdir -p "$DATA_PATH"/{homes,projects,mlflow-artifacts,postgres-data}
    
    # Copy critical configuration
    if [ -f "production.env" ]; then
        source production.env
        export DOMAIN
        export GITHUB_CLIENT_ID
        export GITHUB_CLIENT_SECRET
    fi
    
    # Save migration state
    cat > migration_state.json <<EOF
{
    "migration_date": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
    "from": "docker-compose",
    "to": "k3s",
    "data_path": "$DATA_PATH",
    "backup_location": "$BACKUP_DIR"
}
EOF
}

# Step 4: Install K3s (using optimized script)
install_k3s_platform() {
    log_step "Installing K3s platform..."
    
    if [ -f "deploy_k3s_optimized.sh" ]; then
        chmod +x deploy_k3s_optimized.sh
        ./deploy_k3s_optimized.sh
    else
        log_error "K3s deployment script not found!"
        exit 1
    fi
}

# Step 5: Migrate data to K3s
migrate_data_to_k3s() {
    log_step "Migrating data to K3s..."
    
    # Wait for K3s PostgreSQL to be ready
    log_info "Waiting for K3s PostgreSQL..."
    kubectl wait --for=condition=ready pod -l app=postgresql -n mlflow --timeout=300s
    
    # Restore PostgreSQL data
    log_info "Restoring PostgreSQL data..."
    kubectl exec -i -n mlflow postgresql-0 -- psql -U postgres < "$BACKUP_DIR/postgres_full_backup.sql"
    
    # Create PVCs for data migration
    kubectl apply -f - <<EOF
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: mlflow-artifacts-migration
  namespace: mlflow
spec:
  accessModes:
    - ReadWriteMany
  resources:
    requests:
      storage: 100Gi
  storageClassName: local-storage
EOF
    
    log_info "Data migration completed"
}

# Step 6: Verify migration
verify_migration() {
    log_step "Verifying migration..."
    
    # Check K3s cluster
    kubectl get nodes
    kubectl get pods --all-namespaces
    
    # Test services
    SERVICES=(
        "jupyterhub"
        "mlflow"
        "monitoring"
    )
    
    for ns in "${SERVICES[@]}"; do
        log_info "Checking $ns namespace..."
        kubectl get pods -n "$ns"
    done
    
    log_info "Migration verification complete"
}

# Step 7: Update DNS/networking
update_networking() {
    log_step "Updating networking configuration..."
    
    # Get K3s ingress IP
    INGRESS_IP=$(kubectl get svc -n ingress-nginx ingress-nginx-controller -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "localhost")
    
    log_info "Update your DNS records to point to: $INGRESS_IP"
    log_info "Or update /etc/hosts with:"
    echo "$INGRESS_IP $DOMAIN jupyterhub.$DOMAIN mlflow.$DOMAIN grafana.$DOMAIN"
}

# Main migration flow
main() {
    log_info "Starting Docker to K3s migration..."
    
    # Confirm migration
    read -p "This will migrate your Docker deployment to K3s. Continue? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_info "Migration cancelled"
        exit 0
    fi
    
    # Run migration steps
    backup_docker_deployment
    stop_docker_services
    prepare_k3s_migration
    install_k3s_platform
    migrate_data_to_k3s
    verify_migration
    update_networking
    
    log_info "🎉 Migration completed successfully!"
    log_info "Your platform is now running on K3s"
    log_info "Access JupyterHub at: https://$DOMAIN"
    
    # Cleanup options
    log_warn "Docker containers have been stopped but not removed"
    log_warn "To remove old Docker data after verifying K3s is working:"
    log_warn "  docker system prune -a"
    log_warn "  rm -rf /var/lib/docker/volumes/ai-lab-platform_*"
}

# Run main
main "$@" 