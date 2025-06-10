#!/bin/bash

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$SCRIPT_DIR"

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

# Check if running as root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "This script must be run as root or with sudo"
        exit 1
    fi
}

# Load environment variables
load_env() {
    if [ ! -f "production.env" ]; then
        log_error "production.env file not found!"
        exit 1
    fi
    
    source production.env
    export $(grep -v '^#' production.env | xargs)
}

# Check system requirements
check_requirements() {
    log_step "Checking system requirements..."
    
    # Check for NVIDIA drivers
    if ! command -v nvidia-smi &> /dev/null; then
        log_error "NVIDIA drivers not found. Please install NVIDIA drivers first."
        exit 1
    fi
    
    # Check GPU availability
    GPU_COUNT=$(nvidia-smi --query-gpu=name --format=csv,noheader | wc -l)
    log_info "Found $GPU_COUNT GPUs"
}

# Install Docker if needed
install_docker() {
    log_step "Checking Docker installation..."
    
    # Install required utilities first
    log_info "Installing required utilities..."
    apt-get update
    apt-get install -y apache2-utils  # For htpasswd
    
    if command -v docker &> /dev/null; then
        log_info "Docker already installed"
        return
    fi
    
    log_info "Installing Docker..."
    
    # Add Docker's official GPG key
    apt-get install -y ca-certificates curl gnupg
    install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    chmod a+r /etc/apt/keyrings/docker.gpg
    
    # Add the repository
    echo \
      "deb [arch="$(dpkg --print-architecture)" signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
      "$(. /etc/os-release && echo "$VERSION_CODENAME")" stable" | \
      tee /etc/apt/sources.list.d/docker.list > /dev/null
    
    # Install Docker Engine
    apt-get update
    apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    
    # Start Docker
    systemctl enable docker
    systemctl start docker
}

# Install NVIDIA Docker runtime
install_nvidia_docker() {
    log_step "Installing NVIDIA Container Toolkit..."
    
    # Check if already installed
    if docker run --rm --gpus all nvidia/cuda:11.8.0-base-ubuntu22.04 nvidia-smi &>/dev/null; then
        log_info "NVIDIA Container Toolkit already working"
        return
    fi
    
    # Install NVIDIA Container Toolkit
    distribution=$(. /etc/os-release;echo $ID$VERSION_ID)
    curl -s -L https://nvidia.github.io/nvidia-docker/gpgkey | apt-key add -
    curl -s -L https://nvidia.github.io/nvidia-docker/$distribution/nvidia-docker.list | tee /etc/apt/sources.list.d/nvidia-docker.list
    
    apt-get update
    apt-get install -y nvidia-container-toolkit
    
    # Configure Docker to use NVIDIA runtime
    nvidia-ctk runtime configure --runtime=docker
    systemctl restart docker
    
    # Test NVIDIA Docker
    docker run --rm --gpus all nvidia/cuda:11.8.0-base-ubuntu22.04 nvidia-smi
}

# Setup storage directories
setup_storage() {
    log_step "Setting up storage directories..."
    
    # Create main data directory
    mkdir -p "$DATA_PATH"/{mlflow-artifacts,model-store,user-data,postgres-data,grafana-data,prometheus-data}
    
    # Set proper permissions
    chown -R 1000:1000 "$DATA_PATH"
    chmod -R 755 "$DATA_PATH"
    
    # Create backup directory
    mkdir -p "$BACKUP_PATH"
    chmod 700 "$BACKUP_PATH"
}

# Setup SSL certificates for IP-based deployment
setup_ssl_for_ip() {
    log_step "Setting up self-signed SSL certificates for IP-based deployment..."
    
    mkdir -p ssl
    
    # Generate self-signed certificate for IP address
    openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
        -keyout ssl/privkey.pem \
        -out ssl/fullchain.pem \
        -subj "/C=US/ST=State/L=City/O=Institution/CN=$DOMAIN" \
        -addext "subjectAltName = IP:$DOMAIN"
    
    log_info "Self-signed SSL certificate created for IP: $DOMAIN"
}

# Generate secure passwords
generate_passwords() {
    log_step "Generating secure passwords..."
    
    # Check and generate passwords without using sed on existing values
    if [ -z "$SECRET_KEY" ] || [ "$SECRET_KEY" == "" ]; then
        export SECRET_KEY=$(openssl rand -hex 32)
        log_info "Generated new SECRET_KEY"
    else
        log_info "Using existing SECRET_KEY"
    fi
    
    if [ -z "$POSTGRES_PASSWORD" ] || [ "$POSTGRES_PASSWORD" == "" ]; then
        export POSTGRES_PASSWORD=$(openssl rand -base64 24)
        log_info "Generated new POSTGRES_PASSWORD"
    else
        log_info "Using existing POSTGRES_PASSWORD"
    fi
    
    if [ -z "$REDIS_PASSWORD" ] || [ "$REDIS_PASSWORD" == "" ]; then
        export REDIS_PASSWORD=$(openssl rand -base64 24)
        log_info "Generated new REDIS_PASSWORD"
    else
        log_info "Using existing REDIS_PASSWORD"
    fi
    
    if [ -z "$GRAFANA_ADMIN_PASSWORD" ] || [ "$GRAFANA_ADMIN_PASSWORD" == "" ]; then
        export GRAFANA_ADMIN_PASSWORD=$(openssl rand -base64 16)
        log_info "Generated new GRAFANA_ADMIN_PASSWORD"
    else
        log_info "Using existing GRAFANA_ADMIN_PASSWORD"
    fi
    
    # Save the complete environment back to file if any were generated
    cat > production.env.tmp <<EOF
# Production Environment Configuration for AI Lab Platform

# Domain Configuration
# For on-premises deployment using IP address
DOMAIN=$DOMAIN

# Email for SSL certificates and alerts (Required)
ALERT_EMAIL=$ALERT_EMAIL

# ===== SECURITY CONFIGURATION =====

# PostgreSQL Database Password
POSTGRES_PASSWORD=$POSTGRES_PASSWORD

# Application Secret Key (for session encryption)
SECRET_KEY=$SECRET_KEY

# Redis Password (for session storage)
REDIS_PASSWORD=$REDIS_PASSWORD

# Grafana Admin Password
GRAFANA_ADMIN_PASSWORD=$GRAFANA_ADMIN_PASSWORD

# ===== OAUTH CONFIGURATION =====

# GitHub OAuth for user authentication (optional for now)
GITHUB_CLIENT_ID=$GITHUB_CLIENT_ID
GITHUB_CLIENT_SECRET=$GITHUB_CLIENT_SECRET

# ===== STORAGE CONFIGURATION =====

# Data storage path (must have sufficient space)
DATA_PATH=$DATA_PATH

# Host data path for Docker bind mounts (used by backend when creating containers)
HOST_DATA_PATH=${HOST_DATA_PATH:-$(pwd)/ai-lab-data}

# Backup storage path
BACKUP_PATH=$BACKUP_PATH

# ===== RESOURCE LIMITS =====

# Maximum resources per user
MAX_GPUS_PER_USER=$MAX_GPUS_PER_USER
MAX_MEMORY_GB_PER_USER=$MAX_MEMORY_GB_PER_USER
MAX_ENVIRONMENTS_PER_USER=$MAX_ENVIRONMENTS_PER_USER

# ===== EMAIL CONFIGURATION (Optional) =====

# SMTP settings for sending alerts
SMTP_HOST=$SMTP_HOST
SMTP_PORT=$SMTP_PORT
SMTP_USER=$SMTP_USER
SMTP_PASSWORD=$SMTP_PASSWORD

# ===== ADVANCED CONFIGURATION =====

# Backup retention in days
BACKUP_RETENTION_DAYS=$BACKUP_RETENTION_DAYS

# Log level (DEBUG, INFO, WARNING, ERROR)
LOG_LEVEL=$LOG_LEVEL
EOF
    
    # Replace the old file with the new one
    mv production.env.tmp production.env
    
    # Reload environment
    source production.env
}

# Create monitoring configuration
setup_monitoring() {
    log_step "Setting up monitoring configuration..."
    
    # Create Prometheus configuration for IP-based deployment
    mkdir -p monitoring
    cat > monitoring/prometheus-prod.yml <<EOF
global:
  scrape_interval: 15s
  evaluation_interval: 15s

scrape_configs:
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']

  - job_name: 'backend'
    static_configs:
      - targets: ['backend:5555']

  - job_name: 'mlflow'
    static_configs:
      - targets: ['mlflow:5000']

  - job_name: 'torchserve'
    static_configs:
      - targets: ['torchserve:8082']

  - job_name: 'nvidia-gpu'
    static_configs:
      - targets: ['nvidia-dcgm-exporter:9400']
EOF

    # Create Grafana provisioning
    mkdir -p monitoring/grafana/provisioning/{dashboards,datasources}
    
    cat > monitoring/grafana/provisioning/datasources/prometheus.yml <<EOF
apiVersion: 1

datasources:
  - name: Prometheus
    type: prometheus
    access: proxy
    url: http://prometheus:9090
    isDefault: true
EOF
}

# Deploy services
deploy_services() {
    log_step "Building and deploying services..."
    
    # Use production compose file
    export COMPOSE_FILE=docker-compose.production.yml
    
    # Pull base images
    log_info "Pulling Docker images..."
    docker compose pull
    
    # Build custom images
    log_info "Building custom images..."
    docker compose build
    
    # Start services
    log_info "Starting services..."
    docker compose up -d
    
    # Wait for services to be healthy
    log_info "Waiting for services to be ready..."
    sleep 30
    
    # Check service health
    docker compose ps
}

# Setup backup cron
setup_cron() {
    log_step "Setting up automated backups..."
    
    # Create backup script
    cat > /usr/local/bin/ai-lab-backup.sh <<'EOF'
#!/bin/bash
BACKUP_DIR="${BACKUP_PATH}/$(date +%Y%m%d_%H%M%S)"
mkdir -p "$BACKUP_DIR"

# Backup PostgreSQL
docker exec ai-lab-postgres pg_dumpall -U postgres > "$BACKUP_DIR/postgres_backup.sql"

# Backup data directories
tar -czf "$BACKUP_DIR/mlflow_artifacts.tar.gz" -C "$DATA_PATH" mlflow-artifacts/
tar -czf "$BACKUP_DIR/user_data.tar.gz" -C "$DATA_PATH" user-data/

# Remove old backups
find "$BACKUP_PATH" -type d -mtime +${BACKUP_RETENTION_DAYS} -exec rm -rf {} +

echo "Backup completed: $BACKUP_DIR"
EOF
    
    chmod +x /usr/local/bin/ai-lab-backup.sh
    
    # Add cron job for daily backups
    (crontab -l 2>/dev/null; echo "0 2 * * * /usr/local/bin/ai-lab-backup.sh >> /var/log/ai-lab-backup.log 2>&1") | crontab -
}

# Final setup and validation
final_setup() {
    log_step "Performing final setup..."
    
    # Create admin htpasswd file for Nginx
    ADMIN_PASS=$(openssl rand -base64 12)
    htpasswd -bc nginx/.htpasswd admin "$ADMIN_PASS"
    
    log_info "Admin password for restricted areas: $ADMIN_PASS"
    
    # Save credentials
    cat > credentials.txt <<EOF
AI Lab Platform Production Credentials
======================================

Access URL: https://$DOMAIN
(Note: You'll get a browser warning about the self-signed certificate - this is normal)

Admin Portal: https://$DOMAIN/admin
Username: admin
Password: $ADMIN_PASS

Grafana: https://$DOMAIN:3000
Username: admin
Password: $GRAFANA_ADMIN_PASSWORD

PostgreSQL:
Host: localhost:5432
Username: postgres
Password: $POSTGRES_PASSWORD

MLflow: https://$DOMAIN:5000

IMPORTANT: 
1. Store this file securely
2. Accept the self-signed certificate warning in your browser
3. Consider setting up proper authentication
EOF
    
    chmod 600 credentials.txt
    
    log_info "Credentials saved to credentials.txt"
}

# Main deployment flow
main() {
    log_info "Starting AI Lab Platform deployment for on-premises IP-based access..."
    
    check_root
    load_env
    check_requirements
    install_docker
    install_nvidia_docker
    setup_storage
    setup_ssl_for_ip
    generate_passwords
    setup_monitoring
    deploy_services
    setup_cron
    final_setup
    
    log_info "🎉 Deployment completed successfully!"
    log_info ""
    log_info "Access your platform at: https://$DOMAIN"
    log_info "Note: You'll see a certificate warning - this is normal for self-signed certificates"
    log_info ""
    log_warn "Please review credentials.txt for all login information"
}

# Run main function
main "$@" 