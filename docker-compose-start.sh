#!/bin/bash

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
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

check_requirements() {
    log_info "Checking Docker Compose requirements..."
    
    # Check for Docker
    if ! command -v docker &> /dev/null; then
        log_error "Docker is required but not installed."
        exit 1
    fi
    
    # Check for Docker Compose
    if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null; then
        log_error "Docker Compose is required but not installed."
        exit 1
    fi
    
    # Check for NVIDIA Docker runtime
    if ! docker info | grep -q nvidia; then
        log_warn "NVIDIA Docker runtime not detected. GPU support may not work."
    fi
    
    log_info "Requirements check passed."
}

start_services() {
    log_info "Starting ML Platform services with Docker Compose..."
    
    # Build and start services
    docker-compose up --build -d
    
    log_info "Services started. Waiting for health checks..."
    
    # Wait for services to be healthy
    sleep 30
    
    # Check service status
    docker-compose ps
}

print_access_info() {
    log_info "Docker Compose ML Platform started successfully!"
    echo
    echo "=== Access Information ==="
    echo "JupyterLab: http://localhost:8888"
    echo "VS Code Server: http://localhost:8080"
    echo "MLflow: http://localhost:5000"
    echo "TorchServe Inference: http://localhost:8081"
    echo "TorchServe Management: http://localhost:8082"
    echo "Prometheus: http://localhost:9090"
    echo "Grafana: http://localhost:3000 (admin/admin123)"
    echo
    echo "=== Usage ==="
    echo "1. Open JupyterLab or VS Code Server in your browser"
    echo "2. Create and train models with MLflow tracking"
    echo "3. Deploy models to TorchServe for inference"
    echo "4. Monitor everything in Grafana"
    echo
    echo "=== Stop Services ==="
    echo "docker-compose down"
    echo
    echo "=== View Logs ==="
    echo "docker-compose logs -f [service-name]"
}

# Main execution
main() {
    log_info "Starting Docker Compose ML Platform..."
    
    check_requirements
    start_services
    print_access_info
}

# Run main function
main "$@" 