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
        log_info "Please copy production.env.example to production.env and configure it"
        exit 1
    fi
    
    source production.env
    export $(grep -v '^#' production.env | xargs)
}

# Check system requirements
check_requirements() {
    log_step "Checking system requirements..."
    
    # Check Ubuntu version
    if ! grep -q "Ubuntu" /etc/os-release; then
        log_warn "This script is designed for Ubuntu. Continuing anyway..."
    fi
    
    # Check for NVIDIA drivers
    if ! command -v nvidia-smi &> /dev/null; then
        log_error "NVIDIA drivers not found. Please install NVIDIA drivers first."
        log_info "Run: sudo apt install nvidia-driver-530"
        exit 1
    fi
    
    # Check GPU availability
    GPU_COUNT=$(nvidia-smi --query-gpu=name --format=csv,noheader | wc -l)
    log_info "Found $GPU_COUNT GPUs"
    
    if [ $GPU_COUNT -lt 4 ]; then
        log_warn "Less than 4 GPUs detected. The platform expects 4 GPUs for optimal performance."
    fi
}

# Install system dependencies
install_dependencies() {
    log_step "Installing system dependencies..."
    
    apt-get update
    apt-get install -y \
        curl \
        wget \
        git \
        htop \
        iotop \
        net-tools \
        software-properties-common \
        apt-transport-https \
        ca-certificates \
        gnupg \
        lsb-release \
        ufw \
        fail2ban \
        unattended-upgrades
}

# Install Docker
install_docker() {
    log_step "Installing Docker..."
    
    if command -v docker &> /dev/null; then
        log_info "Docker already installed"
        return
    fi
    
    # Add Docker's official GPG key
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
    
    # Add Docker repository
    echo \
        "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu \
        $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
    
    # Install Docker
    apt-get update
    apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
    
    # Enable and start Docker
    systemctl enable docker
    systemctl start docker
}

# Install NVIDIA Docker runtime
install_nvidia_docker() {
    log_step "Installing NVIDIA Docker runtime..."
    
    # Add NVIDIA Docker repository
    distribution=$(. /etc/os-release;echo $ID$VERSION_ID)
    curl -s -L https://nvidia.github.io/nvidia-docker/gpgkey | apt-key add -
    curl -s -L https://nvidia.github.io/nvidia-docker/$distribution/nvidia-docker.list | tee /etc/apt/sources.list.d/nvidia-docker.list
    
    # Install nvidia-docker2
    apt-get update
    apt-get install -y nvidia-docker2
    
    # Restart Docker to apply changes
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

# Configure firewall
configure_firewall() {
    log_step "Configuring firewall..."
    
    # Enable UFW
    ufw --force enable
    
    # Allow SSH (adjust port if needed)
    ufw allow 22/tcp
    
    # Allow HTTP and HTTPS
    ufw allow 80/tcp
    ufw allow 443/tcp
    
    # Deny all other incoming traffic by default
    ufw default deny incoming
    ufw default allow outgoing
    
    # Reload firewall
    ufw reload
}

# Setup SSL certificates
setup_ssl() {
    log_step "Setting up SSL certificates..."
    
    # Install certbot
    apt-get install -y certbot
    
    # Check if we should use Let's Encrypt or self-signed
    if [ "$DOMAIN" == "localhost" ] || [[ "$DOMAIN" == *.local ]]; then
        log_info "Using self-signed certificates for local domain"
        
        mkdir -p ssl
        openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
            -keyout ssl/privkey.pem \
            -out ssl/fullchain.pem \
            -subj "/C=US/ST=State/L=City/O=Organization/CN=$DOMAIN"
    else
        log_info "Obtaining Let's Encrypt certificates for $DOMAIN"
        
        # Stop any services on port 80
        docker-compose down 2>/dev/null || true
        
        # Get certificates
        certbot certonly --standalone \
            --non-interactive \
            --agree-tos \
            --email "$ALERT_EMAIL" \
            -d "$DOMAIN" \
            -d "*.${DOMAIN}"
        
        # Create symlinks
        mkdir -p ssl
        ln -sf "/etc/letsencrypt/live/$DOMAIN/fullchain.pem" ssl/fullchain.pem
        ln -sf "/etc/letsencrypt/live/$DOMAIN/privkey.pem" ssl/privkey.pem
    fi
}

# Generate secure passwords
generate_passwords() {
    log_step "Generating secure passwords..."
    
    # Only generate if not already set
    if [ -z "$SECRET_KEY" ] || [ "$SECRET_KEY" == "your-very-long-random-secret-key-here" ]; then
        SECRET_KEY=$(openssl rand -hex 32)
        sed -i "s/SECRET_KEY=.*/SECRET_KEY=$SECRET_KEY/" production.env
    fi
    
    if [ -z "$POSTGRES_PASSWORD" ] || [ "$POSTGRES_PASSWORD" == "your-secure-postgres-password-here" ]; then
        POSTGRES_PASSWORD=$(openssl rand -base64 24)
        sed -i "s/POSTGRES_PASSWORD=.*/POSTGRES_PASSWORD=$POSTGRES_PASSWORD/" production.env
    fi
    
    if [ -z "$REDIS_PASSWORD" ] || [ "$REDIS_PASSWORD" == "your-secure-redis-password-here" ]; then
        REDIS_PASSWORD=$(openssl rand -base64 24)
        sed -i "s/REDIS_PASSWORD=.*/REDIS_PASSWORD=$REDIS_PASSWORD/" production.env
    fi
    
    if [ -z "$GRAFANA_ADMIN_PASSWORD" ] || [ "$GRAFANA_ADMIN_PASSWORD" == "your-secure-grafana-password-here" ]; then
        GRAFANA_ADMIN_PASSWORD=$(openssl rand -base64 16)
        sed -i "s/GRAFANA_ADMIN_PASSWORD=.*/GRAFANA_ADMIN_PASSWORD=$GRAFANA_ADMIN_PASSWORD/" production.env
    fi
    
    # Reload environment
    source production.env
}

# Create monitoring configuration
setup_monitoring() {
    log_step "Setting up monitoring configuration..."
    
    # Create Prometheus configuration
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

  - job_name: 'node-exporter'
    static_configs:
      - targets: ['node-exporter:9100']
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

# Build and start services
deploy_services() {
    log_step "Building and deploying services..."
    
    # Use production compose file
    export COMPOSE_FILE=docker-compose.production.yml
    
    # Pull latest images
    docker-compose pull
    
    # Build custom images
    docker-compose build --no-cache
    
    # Start services
    docker-compose up -d
    
    # Wait for services to be healthy
    log_info "Waiting for services to be ready..."
    sleep 30
    
    # Check service health
    docker-compose ps
}

# Setup cron jobs
setup_cron() {
    log_step "Setting up cron jobs..."
    
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
    echo "0 2 * * * /usr/local/bin/ai-lab-backup.sh >> /var/log/ai-lab-backup.log 2>&1" | crontab -
    
    # SSL renewal (if using Let's Encrypt)
    if [ -f "/etc/letsencrypt/live/$DOMAIN/fullchain.pem" ]; then
        echo "0 3 * * 1 certbot renew --quiet && docker-compose restart nginx" | crontab -
    fi
}

# Create systemd service
create_systemd_service() {
    log_step "Creating systemd service..."
    
    cat > /etc/systemd/system/ai-lab-platform.service <<EOF
[Unit]
Description=AI Lab Platform
Requires=docker.service
After=docker.service

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=$SCRIPT_DIR
ExecStart=/usr/bin/docker compose -f docker-compose.production.yml up -d
ExecStop=/usr/bin/docker compose -f docker-compose.production.yml down
ExecReload=/usr/bin/docker compose -f docker-compose.production.yml restart
StandardOutput=journal

[Install]
WantedBy=multi-user.target
EOF
    
    systemctl daemon-reload
    systemctl enable ai-lab-platform.service
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

Domain: https://$DOMAIN

Admin Portal: https://$DOMAIN/admin
Username: admin
Password: $ADMIN_PASS

Grafana: https://grafana.$DOMAIN
Username: admin
Password: $GRAFANA_ADMIN_PASSWORD

PostgreSQL:
Host: localhost:5432
Username: postgres
Password: $POSTGRES_PASSWORD

Default Platform Admin:
Username: admin
Password: admin123 (CHANGE IMMEDIATELY!)

IMPORTANT: 
1. Change all default passwords immediately
2. Store this file securely and delete from server
3. Set up proper OAuth authentication
EOF
    
    chmod 600 credentials.txt
    
    log_info "Credentials saved to credentials.txt"
}

# Main deployment flow
main() {
    log_info "Starting AI Lab Platform production deployment..."
    
    check_root
    load_env
    check_requirements
    install_dependencies
    install_docker
    install_nvidia_docker
    setup_storage
    configure_firewall
    setup_ssl
    generate_passwords
    setup_monitoring
    deploy_services
    setup_cron
    create_systemd_service
    final_setup
    
    log_info "🎉 Deployment completed successfully!"
    log_info "Access your platform at: https://$DOMAIN"
    log_warn "Please review credentials.txt and secure all passwords"
}

# Run main function
main "$@" 