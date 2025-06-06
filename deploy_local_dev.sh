#!/bin/bash

# Local Development Deployment for Single Machine with RTX 3090
# This script adapts the full platform for local development

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Configuration for local development
DOMAIN=${DOMAIN:-"ml-platform.local"}
GITHUB_CLIENT_ID=${GITHUB_CLIENT_ID:-"your-github-client-id"}
GITHUB_CLIENT_SECRET=${GITHUB_CLIENT_SECRET:-"your-github-client-secret"}

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

check_local_requirements() {
    log_info "Checking local development requirements..."
    
    # Check for NVIDIA GPU
    if ! nvidia-smi &> /dev/null; then
        log_warn "NVIDIA drivers not found. GPU support will be limited."
    else
        log_info "NVIDIA GPU detected: $(nvidia-smi --query-gpu=name --format=csv,noheader,nounits)"
    fi
    
    # Check available GPU memory
    if nvidia-smi &> /dev/null; then
        GPU_MEMORY=$(nvidia-smi --query-gpu=memory.total --format=csv,noheader,nounits | head -1)
        log_info "GPU Memory: ${GPU_MEMORY} MB"
        
        if [ "$GPU_MEMORY" -gt 20000 ]; then
            log_info "High-memory GPU detected. Enabling larger batch sizes."
            export LARGE_GPU_MODE=true
        fi
    fi
}

setup_local_storage() {
    log_info "Setting up local storage structure..."
    
    # Create local data structure
    mkdir -p ./local-data/{homes,projects,mlflow-artifacts,postgres-data,dvc_remote,registry}
    
    # Set permissions
    chmod 755 ./local-data
    
    log_info "Local storage setup completed at ./local-data/"
}

create_local_k3s_config() {
    log_info "Creating local k3s configuration..."
    
    # Create k3s config for single node
    cat > k3s-local.yaml <<EOF
# k3s configuration for local development
cluster-init: true
disable:
  - traefik  # We'll use our own ingress
write-kubeconfig-mode: 644
node-label:
  - "node.kubernetes.io/instance-type=gpu-dev"
  - "ml-platform.local/gpu-type=rtx3090"
EOF
    
    log_info "k3s configuration created."
}

install_local_k3s() {
    log_info "Installing k3s for local development..."
    
    # Install k3s with local config
    curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="--config k3s-local.yaml" sh -s -
    
    # Setup kubeconfig
    mkdir -p ~/.kube
    sudo cp /etc/rancher/k3s/k3s.yaml ~/.kube/config
    sudo chown $USER:$USER ~/.kube/config
    export KUBECONFIG=~/.kube/config
    
    # Wait for node to be ready
    until kubectl get nodes | grep -q "Ready"; do
        log_info "Waiting for k3s node to be ready..."
        sleep 10
    done
    
    log_info "k3s installed and ready for local development."
}

update_jupyterhub_for_local() {
    log_info "Adapting JupyterHub configuration for local development..."
    
    # Create local JupyterHub values
    cat > values-jupyterhub-local.yaml <<EOF
# JupyterHub configuration for local development
hub:
  config:
    JupyterHub:
      authenticator_class: jupyterhub.auth.DummyAuthenticator  # No OAuth for local
      spawner_class: kubespawner.KubeSpawner
    DummyAuthenticator:
      password: "dev"  # Simple password for local development
    KubeSpawner:
      image: "localhost:5000/ml-base:latest"
      image_pull_policy: "Always"
      
      # GPU allocation - flexible for local development
      profile_list:
        - display_name: "Light Development (No GPU)"
          description: "CPU-only development"
          default: false
          kubespawner_override:
            extra_resource_limits: {}
            extra_resource_guarantees: {}
            
        - display_name: "GPU Development (RTX 3090)"
          description: "Full GPU access for training"
          default: true
          kubespawner_override:
            extra_resource_limits:
              nvidia.com/gpu: "1"
            extra_resource_guarantees:
              nvidia.com/gpu: "1"
            environment:
              NVIDIA_VISIBLE_DEVICES: "all"
              
        - display_name: "Shared GPU (for testing)"
          description: "Shared GPU access for light workloads"
          default: false
          kubespawner_override:
            extra_resource_limits:
              nvidia.com/gpu: "1"
            extra_resource_guarantees: {}
            environment:
              NVIDIA_VISIBLE_DEVICES: "0"
              CUDA_MPS_ENABLE: "1"  # Enable Multi-Process Service
      
      # Larger resource limits for RTX 3090
      memory_limit: "32G"    # More memory for local development
      memory_guarantee: "16G"
      cpu_limit: 8           # More CPU cores
      cpu_guarantee: 4
      
      # Local storage
      storage_pvc_ensure: true
      storage_capacity: "100Gi"  # Larger storage for local
      storage_class: "local-storage"
      
      # Mount local projects
      volumes:
        - name: shared-projects
          hostPath:
            path: $(pwd)/local-data/projects
        - name: local-workspace
          hostPath:
            path: $(pwd)
      volume_mounts:
        - name: shared-projects
          mountPath: /shared/projects
        - name: local-workspace
          mountPath: /workspace
          readOnly: false

  # Local database
  db:
    type: sqlite-pvc
    pvc:
      storageClassName: local-storage
      storage: 10Gi

# Simpler proxy for local
proxy:
  service:
    type: NodePort
    nodePorts:
      http: 30080

# No RBAC needed for local development
rbac:
  enabled: false

# Disable culling for development
cull:
  enabled: false
EOF

    log_info "Local JupyterHub configuration created."
}

deploy_local_platform() {
    log_info "Deploying ML platform for local development..."
    
    # Use modified deployment scripts
    export LOCAL_DEV_MODE=true
    export STORAGE_PATH=$(pwd)/local-data
    
    # Deploy with local configurations
    ./deploy_stage1.sh --local-dev
    
    log_info "Local ML platform deployed."
}

create_gpu_scheduler_config() {
    log_info "Creating flexible GPU scheduling configuration..."
    
    cat > gpu-scheduler-config.yaml <<EOF
# GPU Scheduler Configuration for Flexible Allocation
apiVersion: v1
kind: ConfigMap
metadata:
  name: gpu-scheduler-config
  namespace: jupyterhub
data:
  gpu_allocation.py: |
    """
    Dynamic GPU allocation based on user requests and availability
    """
    import os
    import subprocess
    import json
    
    def get_gpu_availability():
        """Get current GPU usage and availability"""
        try:
            result = subprocess.run(['nvidia-smi', '--query-gpu=index,memory.used,memory.total,utilization.gpu', 
                                   '--format=csv,noheader,nounits'], 
                                   capture_output=True, text=True)
            gpus = []
            for line in result.stdout.strip().split('\n'):
                if line:
                    idx, mem_used, mem_total, util = line.split(', ')
                    gpus.append({
                        'index': int(idx),
                        'memory_used': int(mem_used),
                        'memory_total': int(mem_total),
                        'memory_free': int(mem_total) - int(mem_used),
                        'utilization': int(util),
                        'available': int(util) < 50  # Consider available if <50% utilized
                    })
            return gpus
        except Exception as e:
            print(f"Error getting GPU info: {e}")
            return []
    
    def allocate_gpus(requested_gpus, user_priority='normal'):
        """Allocate GPUs based on request and availability"""
        available_gpus = get_gpu_availability()
        allocated = []
        
        # Sort by availability (least used first)
        available_gpus.sort(key=lambda x: (x['utilization'], x['memory_used']))
        
        # Allocate requested number of GPUs
        for gpu in available_gpus:
            if len(allocated) >= requested_gpus:
                break
            if gpu['available'] or user_priority == 'high':
                allocated.append(gpu['index'])
        
        return allocated
    
    def get_recommended_batch_size(allocated_gpus):
        """Recommend batch size based on allocated GPU memory"""
        if not allocated_gpus:
            return 32  # CPU-only default
        
        # RTX 3090 has 24GB, can handle larger batches
        total_memory = sum(gpu['memory_total'] for gpu in allocated_gpus)
        
        if total_memory > 20000:  # >20GB
            return 128
        elif total_memory > 10000:  # >10GB
            return 64
        else:
            return 32
EOF

    kubectl apply -f gpu-scheduler-config.yaml || true
    
    log_info "GPU scheduler configuration created."
}

print_local_access_info() {
    log_info "Local ML Platform deployed successfully!"
    echo
    echo "=== Local Development Access ==="
    echo "JupyterHub: http://localhost:30080 (user: any, password: dev)"
    echo "MLflow: http://mlflow.ml-platform.local/"
    echo "Grafana: http://grafana.ml-platform.local/"
    echo
    echo "=== GPU Information ==="
    if nvidia-smi &> /dev/null; then
        nvidia-smi --query-gpu=name,memory.total --format=csv
    fi
    echo
    echo "=== GPU Allocation Profiles ==="
    echo "- Light Development: No GPU (CPU-only)"
    echo "- GPU Development: Full RTX 3090 access"  
    echo "- Shared GPU: Shared access with MPS"
    echo
    echo "=== Local Data ==="
    echo "Projects: $(pwd)/local-data/projects/"
    echo "User Homes: $(pwd)/local-data/homes/"
    echo "MLflow Artifacts: $(pwd)/local-data/mlflow-artifacts/"
}

# Main execution for local development
main() {
    log_info "Starting Local ML Platform Development Setup..."
    
    check_local_requirements
    setup_local_storage
    create_local_k3s_config
    install_local_k3s
    update_jupyterhub_for_local
    create_gpu_scheduler_config
    deploy_local_platform
    
    print_local_access_info
}

# Handle command line arguments
case "${1:-}" in
    --docker-compose)
        log_info "Using Docker Compose for local development..."
        docker-compose up --build -d
        ;;
    --wsl2)
        log_info "WSL2 mode detected, using full Linux deployment..."
        main
        ;;
    *)
        log_info "Local development with k3s..."
        main
        ;;
esac 