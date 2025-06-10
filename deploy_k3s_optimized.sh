#!/bin/bash

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_step() { echo -e "${BLUE}[STEP]${NC} $1"; }

# Configuration
DOMAIN=${DOMAIN:-"ml-platform.local"}
GITHUB_CLIENT_ID=${GITHUB_CLIENT_ID:-"your-github-client-id"}
GITHUB_CLIENT_SECRET=${GITHUB_CLIENT_SECRET:-"your-github-client-secret"}
DATA_PATH=${DATA_PATH:-"/opt/ai-lab-data"}

# Performance tuning
optimize_system() {
    log_step "Optimizing system for GPU workloads..."
    
    # Kernel parameters for better GPU performance
    cat >> /etc/sysctl.conf <<EOF
# GPU Performance Tuning
vm.swappiness=10
vm.dirty_ratio=15
vm.dirty_background_ratio=5
vm.overcommit_memory=1
kernel.numa_balancing=0
kernel.sched_migration_cost_ns=5000000
net.core.rmem_default=134217728
net.core.wmem_default=134217728
net.core.rmem_max=268435456
net.core.wmem_max=268435456
net.ipv4.tcp_rmem=4096 87380 134217728
net.ipv4.tcp_wmem=4096 65536 134217728
EOF
    sysctl -p
    
    # Disable CPU frequency scaling for consistent performance
    echo performance | tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor
    
    # Configure NVIDIA GPU settings
    nvidia-smi -pm 1  # Enable persistence mode
    nvidia-smi --auto-boost-default=0  # Disable auto boost for consistency
    nvidia-smi -pl 250  # Set power limit (adjust based on your GPUs)
}

# Install K3s with optimizations
install_k3s_optimized() {
    log_step "Installing K3s with performance optimizations..."
    
    # Create K3s config
    mkdir -p /etc/rancher/k3s
    cat > /etc/rancher/k3s/config.yaml <<EOF
# K3s Performance Configuration
write-kubeconfig-mode: "0644"
tls-san:
  - "${DOMAIN}"
  - "127.0.0.1"
disable:
  - traefik  # We'll use nginx-ingress instead
  - servicelb
  - metrics-server  # We'll install our own
cluster-init: true
etcd-expose-metrics: true

# Kubelet optimizations
kubelet-arg:
  - "cpu-manager-policy=static"
  - "topology-manager-policy=best-effort"
  - "topology-manager-scope=pod"
  - "kube-reserved=cpu=1,memory=2Gi"
  - "system-reserved=cpu=1,memory=2Gi"
  - "eviction-hard=memory.available<5%,nodefs.available<10%"
  - "max-pods=250"
  - "feature-gates=CPUManager=true,TopologyManager=true,DevicePlugins=true"

# API server optimizations
kube-apiserver-arg:
  - "max-requests-inflight=1000"
  - "max-mutating-requests-inflight=500"
  - "default-watch-cache-size=500"
  - "feature-gates=EphemeralContainers=true"

# Controller optimizations
kube-controller-manager-arg:
  - "node-monitor-period=5s"
  - "node-monitor-grace-period=20s"
  - "pod-eviction-timeout=30s"
  - "concurrent-deployment-syncs=50"
  - "concurrent-endpoint-syncs=50"

# Scheduler optimizations
kube-scheduler-arg:
  - "scheduling-algorithm=priority"
  - "feature-gates=PodTopologySpread=true"

# ETCD optimizations
etcd-arg:
  - "quota-backend-bytes=8589934592"  # 8GB
  - "max-request-bytes=33554432"      # 32MB
  - "grpc-keepalive-min-time=10s"
  - "grpc-keepalive-interval=30s"
  - "grpc-keepalive-timeout=10s"
EOF

    # Install K3s
    curl -sfL https://get.k3s.io | sh -s - server --config=/etc/rancher/k3s/config.yaml
    
    # Wait for K3s to be ready
    until kubectl get nodes | grep -q "Ready"; do
        log_info "Waiting for K3s to be ready..."
        sleep 5
    done
}

# Install high-performance ingress
install_nginx_ingress() {
    log_step "Installing NGINX Ingress with performance tuning..."
    
    cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: nginx-configuration
  namespace: ingress-nginx
data:
  worker-processes: "auto"
  worker-connections: "65536"
  use-forwarded-headers: "true"
  compute-full-forwarded-for: "true"
  keep-alive: "75"
  keep-alive-requests: "10000"
  upstream-keepalive-connections: "10000"
  upstream-keepalive-requests: "10000"
  upstream-keepalive-timeout: "60"
  ssl-protocols: "TLSv1.2 TLSv1.3"
  ssl-ciphers: "ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256"
  enable-brotli: "true"
  brotli-level: "6"
  gzip-level: "6"
  client-body-buffer-size: "1m"
  client-header-buffer-size: "16k"
  large-client-header-buffers: "8 32k"
  proxy-body-size: "5g"
  proxy-buffer-size: "16k"
  proxy-buffers: "8 32k"
EOF

    # Install NGINX ingress with custom values
    helm upgrade --install ingress-nginx ingress-nginx \
        --repo https://kubernetes.github.io/ingress-nginx \
        --namespace ingress-nginx \
        --create-namespace \
        --set controller.replicaCount=2 \
        --set controller.resources.requests.cpu=500m \
        --set controller.resources.requests.memory=512Mi \
        --set controller.resources.limits.cpu=2000m \
        --set controller.resources.limits.memory=2Gi \
        --set controller.autoscaling.enabled=true \
        --set controller.autoscaling.minReplicas=2 \
        --set controller.autoscaling.maxReplicas=10 \
        --set controller.metrics.enabled=true \
        --set controller.admissionWebhooks.enabled=false \
        --wait
}

# Setup GPU operator with optimizations
setup_gpu_operator_optimized() {
    log_step "Installing NVIDIA GPU Operator with optimizations..."
    
    # Apply optimized GPU configurations
    kubectl apply -f k3s-production-optimized.yaml
    
    # Install GPU operator with custom settings
    helm upgrade --install gpu-operator nvidia/gpu-operator \
        --namespace gpu-operator \
        --create-namespace \
        --set driver.enabled=false \
        --set toolkit.enabled=true \
        --set devicePlugin.config.name=nvidia-device-plugin-config \
        --set devicePlugin.config.default=all \
        --set gfd.enabled=true \
        --set migManager.enabled=true \
        --set nodeStatusExporter.enabled=true \
        --set dcgmExporter.enabled=true \
        --set dcgmExporter.serviceMonitor.enabled=true \
        --wait
}

# Setup high-performance storage
setup_storage_optimized() {
    log_step "Setting up optimized storage..."
    
    # Create directories with optimal permissions
    mkdir -p "$DATA_PATH"/{homes,projects,mlflow,models,scratch}
    
    # Mount with performance options if using separate disk
    # mount -o noatime,nodiratime,nobarrier /dev/nvme0n1 "$DATA_PATH"
    
    # Create local-path provisioner with optimizations
    kubectl apply -f - <<EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: local-path-config
  namespace: local-path-storage
data:
  config.json: |-
    {
      "nodePathMap": [
        {
          "node": "DEFAULT_PATH_FOR_NON_LISTED_NODES",
          "paths": ["${DATA_PATH}/dynamic"]
        }
      ]
    }
  setup: |-
    #!/bin/sh
    set -eu
    mkdir -m 0755 -p "\$VOL_DIR"
    chmod 0755 "\$VOL_DIR"
  teardown: |-
    #!/bin/sh
    set -eu
    rm -rf "\$VOL_DIR"
---
apiVersion: v1
kind: StorageClass
metadata:
  name: fast-local
  annotations:
    storageclass.kubernetes.io/is-default-class: "true"
provisioner: rancher.io/local-path
volumeBindingMode: WaitForFirstConsumer
reclaimPolicy: Delete
parameters:
  nodePath: "${DATA_PATH}/dynamic"
EOF
}

# Install monitoring with performance focus
setup_monitoring_optimized() {
    log_step "Installing optimized monitoring stack..."
    
    # Prometheus with tuned retention and resources
    helm upgrade --install prometheus prometheus-community/prometheus \
        --namespace monitoring \
        --create-namespace \
        --set server.retention=30d \
        --set server.resources.requests.cpu=500m \
        --set server.resources.requests.memory=2Gi \
        --set server.resources.limits.cpu=2000m \
        --set server.resources.limits.memory=8Gi \
        --set server.persistentVolume.size=100Gi \
        --set server.global.scrape_interval=15s \
        --set nodeExporter.enabled=true \
        --set pushgateway.enabled=false \
        --set alertmanager.enabled=true \
        --wait
    
    # Grafana optimized for dashboards
    helm upgrade --install grafana grafana/grafana \
        --namespace monitoring \
        --set persistence.enabled=true \
        --set persistence.size=10Gi \
        --set resources.requests.cpu=250m \
        --set resources.requests.memory=512Mi \
        --set resources.limits.cpu=1000m \
        --set resources.limits.memory=1Gi \
        --set adminPassword="$GRAFANA_ADMIN_PASSWORD" \
        --wait
}

# Install JupyterHub with GPU optimizations
install_jupyterhub_optimized() {
    log_step "Installing JupyterHub with GPU optimizations..."
    
    # Create optimized values file
    cat > jupyterhub-values-optimized.yaml <<EOF
hub:
  resources:
    requests:
      cpu: 1
      memory: 2Gi
    limits:
      cpu: 2
      memory: 4Gi
  extraConfig:
    performance: |
      c.JupyterHub.concurrent_spawn_limit = 20
      c.JupyterHub.spawner_class = 'kubespawner.KubeSpawner'
      c.KubeSpawner.start_timeout = 300
      c.KubeSpawner.http_timeout = 120
      c.KubeSpawner.cpu_guarantee = 2
      c.KubeSpawner.cpu_limit = 8
      c.KubeSpawner.mem_guarantee = '8G'
      c.KubeSpawner.mem_limit = '32G'
      c.KubeSpawner.extra_resource_limits = {"nvidia.com/gpu": "1"}
      c.KubeSpawner.node_selector = {'node.kubernetes.io/gpu': 'true'}
      c.KubeSpawner.tolerations = [
          {
              'key': 'nvidia.com/gpu',
              'operator': 'Exists',
              'effect': 'NoSchedule'
          }
      ]
  db:
    type: postgres
    
proxy:
  service:
    type: ClusterIP
  chp:
    resources:
      requests:
        cpu: 500m
        memory: 512Mi
      limits:
        cpu: 1000m
        memory: 1Gi
        
singleuser:
  defaultUrl: "/lab"
  image:
    name: localhost:5000/ml-base
    tag: latest
  profileList:
    - display_name: "PyTorch GPU (1x GPU, 32GB RAM)"
      description: "PyTorch environment with 1 GPU and 32GB RAM"
      kubespawner_override:
        cpu_limit: 8
        cpu_guarantee: 4
        mem_limit: "32G"
        mem_guarantee: "16G"
        extra_resource_limits:
          nvidia.com/gpu: "1"
    - display_name: "TensorFlow GPU (1x GPU, 32GB RAM)"
      description: "TensorFlow environment with 1 GPU and 32GB RAM"
      kubespawner_override:
        cpu_limit: 8
        cpu_guarantee: 4
        mem_limit: "32G"
        mem_guarantee: "16G"
        extra_resource_limits:
          nvidia.com/gpu: "1"
    - display_name: "Multi-GPU Training (2x GPU, 64GB RAM)"
      description: "For distributed training with 2 GPUs"
      kubespawner_override:
        cpu_limit: 16
        cpu_guarantee: 8
        mem_limit: "64G"
        mem_guarantee: "32G"
        extra_resource_limits:
          nvidia.com/gpu: "2"
          
  extraEnv:
    MLFLOW_TRACKING_URI: http://mlflow-service.mlflow:5000
    NVIDIA_VISIBLE_DEVICES: all
    
  storage:
    capacity: 100Gi
    homeMountPath: /home/jovyan
    dynamic:
      storageClass: fast-local
    extraVolumes:
      - name: shm-volume
        emptyDir:
          medium: Memory
          sizeLimit: 32Gi
      - name: projects
        hostPath:
          path: ${DATA_PATH}/projects
          type: Directory
    extraVolumeMounts:
      - name: shm-volume
        mountPath: /dev/shm
      - name: projects
        mountPath: /projects
        
scheduling:
  userScheduler:
    enabled: true
    resources:
      requests:
        cpu: 50m
        memory: 256Mi
        
cull:
  enabled: true
  timeout: 7200
  every: 300
  
prePuller:
  enabled: true
  continuous:
    enabled: true
EOF

    # Install JupyterHub
    helm upgrade --install jupyterhub jupyterhub/jupyterhub \
        --namespace jupyterhub \
        --create-namespace \
        --values jupyterhub-values-optimized.yaml \
        --timeout 10m \
        --wait
}

# Main installation flow
main() {
    log_info "Starting optimized K3s deployment for AI Lab Platform..."
    
    # Check requirements
    if ! command -v nvidia-smi &> /dev/null; then
        log_error "NVIDIA drivers not installed!"
        exit 1
    fi
    
    # Optimize system
    optimize_system
    
    # Install components
    install_k3s_optimized
    install_nginx_ingress
    setup_gpu_operator_optimized
    setup_storage_optimized
    setup_monitoring_optimized
    install_jupyterhub_optimized
    
    log_info "🚀 Optimized K3s deployment complete!"
    log_info "Access JupyterHub at: https://${DOMAIN}"
}

# Run if not sourced
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi 