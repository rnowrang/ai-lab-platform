#!/bin/bash

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
DOMAIN=${DOMAIN:-"ml-platform.local"}
GITHUB_CLIENT_ID=${GITHUB_CLIENT_ID:-"your-github-client-id"}
GITHUB_CLIENT_SECRET=${GITHUB_CLIENT_SECRET:-"your-github-client-secret"}
POSTGRES_PASSWORD=${POSTGRES_PASSWORD:-"mlflow123"}
GRAFANA_ADMIN_PASSWORD=${GRAFANA_ADMIN_PASSWORD:-"admin123"}

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
    log_info "Checking system requirements..."
    
    # Check if running as root
    if [[ $EUID -eq 0 ]]; then
        log_error "Please do not run this script as root. Use a user with sudo privileges."
        exit 1
    fi
    
    # Check Ubuntu version
    if ! grep -q "22.04" /etc/os-release; then
        log_warn "This script is designed for Ubuntu 22.04. Continuing anyway..."
    fi
    
    # Check for required commands
    for cmd in curl wget git docker; do
        if ! command -v $cmd &> /dev/null; then
            log_error "$cmd is required but not installed. Please install it first."
            exit 1
        fi
    done
    
    # Check for NVIDIA GPUs
    if ! nvidia-smi &> /dev/null; then
        log_error "NVIDIA drivers not found. Please install NVIDIA drivers first."
        exit 1
    fi
    
    log_info "System requirements check passed."
}

setup_storage() {
    log_info "Setting up storage at /mnt/data..."
    
    sudo mkdir -p /mnt/data/{homes,projects,mlflow-artifacts,postgres-data,dvc_remote,registry}
    sudo chown -R $USER:$USER /mnt/data
    chmod 755 /mnt/data
    
    # Create example project structure
    mkdir -p /mnt/data/projects/example-project/{data,src,models}
    
    log_info "Storage setup completed."
}

install_k3s() {
    log_info "Installing k3s Kubernetes..."
    
    # Install k3s with GPU support
    curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="--disable=traefik" sh -s -
    
    # Wait for k3s to be ready
    sudo systemctl enable k3s
    sudo systemctl start k3s
    
    # Setup kubeconfig for current user
    mkdir -p ~/.kube
    sudo cp /etc/rancher/k3s/k3s.yaml ~/.kube/config
    sudo chown $USER:$USER ~/.kube/config
    export KUBECONFIG=~/.kube/config
    
    # Wait for node to be ready
    until kubectl get nodes | grep -q "Ready"; do
        log_info "Waiting for k3s node to be ready..."
        sleep 10
    done
    
    log_info "k3s installed and ready."
}

install_helm() {
    log_info "Installing Helm..."
    
    curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
    
    # Add required Helm repositories
    helm repo add jupyterhub https://hub.jupyter.org/helm-chart/
    helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
    helm repo add grafana https://grafana.github.io/helm-charts
    helm repo add bitnami https://charts.bitnami.com/bitnami
    helm repo add nvidia https://helm.ngc.nvidia.com/nvidia
    helm repo update
    
    log_info "Helm installed with required repositories."
}

setup_nvidia_gpu_operator() {
    log_info "Setting up NVIDIA GPU Operator..."
    
    # Install NVIDIA GPU Operator
    helm upgrade --install gpu-operator nvidia/gpu-operator \
        --namespace gpu-operator-resources \
        --create-namespace \
        --set driver.enabled=false \
        --wait
    
    log_info "NVIDIA GPU Operator installed."
}

setup_storage_classes() {
    log_info "Creating storage classes and persistent volumes..."
    
    kubectl apply -f - <<EOF
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: local-storage
provisioner: kubernetes.io/no-provisioner
volumeBindingMode: WaitForFirstConsumer
---
apiVersion: v1
kind: PersistentVolume
metadata:
  name: pv-homes
spec:
  capacity:
    storage: 1Ti
  accessModes:
    - ReadWriteOnce
  persistentVolumeReclaimPolicy: Retain
  storageClassName: local-storage
  hostPath:
    path: /mnt/data/homes
---
apiVersion: v1
kind: PersistentVolume
metadata:
  name: pv-projects
spec:
  capacity:
    storage: 2Ti
  accessModes:
    - ReadWriteMany
  persistentVolumeReclaimPolicy: Retain
  storageClassName: local-storage
  hostPath:
    path: /mnt/data/projects
---
apiVersion: v1
kind: PersistentVolume
metadata:
  name: pv-mlflow-artifacts
spec:
  capacity:
    storage: 1Ti
  accessModes:
    - ReadWriteMany
  persistentVolumeReclaimPolicy: Retain
  storageClassName: local-storage
  hostPath:
    path: /mnt/data/mlflow-artifacts
---
apiVersion: v1
kind: PersistentVolume
metadata:
  name: pv-postgres-data
spec:
  capacity:
    storage: 100Gi
  accessModes:
    - ReadWriteOnce
  persistentVolumeReclaimPolicy: Retain
  storageClassName: local-storage
  hostPath:
    path: /mnt/data/postgres-data
---
apiVersion: v1
kind: PersistentVolume
metadata:
  name: pv-registry
spec:
  capacity:
    storage: 500Gi
  accessModes:
    - ReadWriteOnce
  persistentVolumeReclaimPolicy: Retain
  storageClassName: local-storage
  hostPath:
    path: /mnt/data/registry
EOF
    
    log_info "Storage classes and persistent volumes created."
}

setup_private_registry() {
    log_info "Setting up private Docker registry..."
    
    kubectl create namespace registry || true
    
    kubectl apply -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: registry
  namespace: registry
spec:
  replicas: 1
  selector:
    matchLabels:
      app: registry
  template:
    metadata:
      labels:
        app: registry
    spec:
      containers:
      - name: registry
        image: registry:2
        ports:
        - containerPort: 5000
        env:
        - name: REGISTRY_STORAGE_FILESYSTEM_ROOTDIRECTORY
          value: /var/lib/registry
        volumeMounts:
        - name: registry-storage
          mountPath: /var/lib/registry
      volumes:
      - name: registry-storage
        persistentVolumeClaim:
          claimName: registry-pvc
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: registry-pvc
  namespace: registry
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 500Gi
  storageClassName: local-storage
---
apiVersion: v1
kind: Service
metadata:
  name: registry-service
  namespace: registry
spec:
  selector:
    app: registry
  ports:
  - port: 5000
    targetPort: 5000
  type: ClusterIP
EOF
    
    # Wait for registry to be ready
    kubectl wait --for=condition=available --timeout=300s deployment/registry -n registry
    
    # Port forward for local access (run in background)
    kubectl port-forward -n registry svc/registry-service 5000:5000 &
    
    log_info "Private Docker registry setup completed."
}

build_and_push_images() {
    log_info "Building and pushing custom Docker images..."
    
    # Wait a moment for port-forward to establish
    sleep 10
    
    # Build ML base image
    docker build -t localhost:5000/ml-base:latest -f Dockerfile.ml .
    docker push localhost:5000/ml-base:latest
    
    # Build MLflow image
    docker build -t localhost:5000/mlflow:latest -f Dockerfile.mlflow .
    docker push localhost:5000/mlflow:latest
    
    log_info "Custom images built and pushed to registry."
}

setup_secrets() {
    log_info "Setting up Kubernetes secrets..."
    
    kubectl create namespace jupyterhub || true
    kubectl create namespace mlflow || true
    
    # JupyterHub OAuth secrets
    kubectl create secret generic github-oauth \
        --from-literal=clientId="$GITHUB_CLIENT_ID" \
        --from-literal=clientSecret="$GITHUB_CLIENT_SECRET" \
        -n jupyterhub || true
    
    # PostgreSQL password
    kubectl create secret generic postgres-secret \
        --from-literal=postgres-password="$POSTGRES_PASSWORD" \
        -n mlflow || true
    
    log_info "Kubernetes secrets created."
}

install_postgresql() {
    log_info "Installing PostgreSQL for MLflow..."
    
    helm upgrade --install postgresql bitnami/postgresql \
        --namespace mlflow \
        --create-namespace \
        --set auth.postgresPassword="$POSTGRES_PASSWORD" \
        --set auth.database=mlflowdb \
        --set persistence.existingClaim=postgres-pvc \
        --set persistence.storageClass=local-storage \
        --wait
    
    # Create PVC for PostgreSQL
    kubectl apply -f - <<EOF
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: postgres-pvc
  namespace: mlflow
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 100Gi
  storageClassName: local-storage
EOF
    
    log_info "PostgreSQL installed."
}

install_mlflow() {
    log_info "Installing MLflow tracking server..."
    
    kubectl apply -f mlflow-manifests/
    
    log_info "MLflow tracking server installed."
}

install_jupyterhub() {
    log_info "Installing JupyterHub..."
    
    helm upgrade --install jupyterhub jupyterhub/jupyterhub \
        --namespace jupyterhub \
        --create-namespace \
        --values values-jupyterhub.yaml \
        --wait
    
    log_info "JupyterHub installed."
}

install_monitoring() {
    log_info "Installing Prometheus and Grafana..."
    
    # Install Prometheus
    helm upgrade --install prometheus prometheus-community/prometheus \
        --namespace monitoring \
        --create-namespace \
        --values prometheus-values.yaml \
        --wait
    
    # Install Grafana
    helm upgrade --install grafana grafana/grafana \
        --namespace monitoring \
        --values grafana-values.yaml \
        --set adminPassword="$GRAFANA_ADMIN_PASSWORD" \
        --wait
    
    # Install NVIDIA DCGM Exporter
    kubectl apply -f monitoring/dcgm-exporter.yaml
    
    log_info "Monitoring stack installed."
}

setup_ingress() {
    log_info "Setting up NGINX Ingress Controller..."
    
    # Install NGINX Ingress
    kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.8.1/deploy/static/provider/cloud/deploy.yaml
    
    # Wait for ingress controller to be ready
    kubectl wait --namespace ingress-nginx \
        --for=condition=ready pod \
        --selector=app.kubernetes.io/component=controller \
        --timeout=120s
    
    # Apply ingress configurations
    kubectl apply -f ingress/
    
    log_info "Ingress controller and routes configured."
}

setup_example_project() {
    log_info "Setting up example project with DVC..."
    
    cd /mnt/data/projects/example-project
    
    # Initialize git and DVC
    git init
    git config user.email "admin@${DOMAIN}"
    git config user.name "ML Platform Admin"
    
    # Install DVC if not present
    if ! command -v dvc &> /dev/null; then
        pip3 install dvc[local]
    fi
    
    dvc init
    dvc remote add -d localremote /mnt/data/dvc_remote
    
    # Create example files
    cat > src/train.py <<'EOF'
import torch
import torch.nn as nn
import torch.optim as optim
import mlflow
import mlflow.pytorch
import numpy as np
from sklearn.datasets import make_classification
from sklearn.model_selection import train_test_split
import os

# Set MLflow tracking URI
mlflow.set_tracking_uri(os.getenv('MLFLOW_TRACKING_URI', 'http://mlflow-service.mlflow:5000'))

# Simple neural network
class SimpleNet(nn.Module):
    def __init__(self, input_size, hidden_size, output_size):
        super(SimpleNet, self).__init__()
        self.fc1 = nn.Linear(input_size, hidden_size)
        self.fc2 = nn.Linear(hidden_size, output_size)
        self.relu = nn.ReLU()
        self.sigmoid = nn.Sigmoid()
    
    def forward(self, x):
        x = self.relu(self.fc1(x))
        x = self.sigmoid(self.fc2(x))
        return x

def train_model():
    # Generate sample data
    X, y = make_classification(n_samples=1000, n_features=20, n_classes=2, random_state=42)
    X_train, X_test, y_train, y_test = train_test_split(X, y, test_size=0.2, random_state=42)
    
    # Convert to tensors
    X_train_tensor = torch.FloatTensor(X_train)
    y_train_tensor = torch.FloatTensor(y_train).unsqueeze(1)
    X_test_tensor = torch.FloatTensor(X_test)
    y_test_tensor = torch.FloatTensor(y_test).unsqueeze(1)
    
    # Model parameters
    input_size = X_train.shape[1]
    hidden_size = 64
    output_size = 1
    learning_rate = 0.001
    epochs = 100
    
    # Start MLflow run
    with mlflow.start_run():
        # Log parameters
        mlflow.log_param("input_size", input_size)
        mlflow.log_param("hidden_size", hidden_size)
        mlflow.log_param("learning_rate", learning_rate)
        mlflow.log_param("epochs", epochs)
        
        # Initialize model
        model = SimpleNet(input_size, hidden_size, output_size)
        criterion = nn.BCELoss()
        optimizer = optim.Adam(model.parameters(), lr=learning_rate)
        
        # Training loop
        for epoch in range(epochs):
            optimizer.zero_grad()
            outputs = model(X_train_tensor)
            loss = criterion(outputs, y_train_tensor)
            loss.backward()
            optimizer.step()
            
            if epoch % 20 == 0:
                # Evaluate on test set
                with torch.no_grad():
                    test_outputs = model(X_test_tensor)
                    test_loss = criterion(test_outputs, y_test_tensor)
                    test_predictions = (test_outputs > 0.5).float()
                    test_accuracy = (test_predictions == y_test_tensor).float().mean()
                
                print(f'Epoch [{epoch}/{epochs}], Loss: {loss.item():.4f}, Test Loss: {test_loss.item():.4f}, Test Acc: {test_accuracy.item():.4f}')
                
                # Log metrics
                mlflow.log_metric("train_loss", loss.item(), step=epoch)
                mlflow.log_metric("test_loss", test_loss.item(), step=epoch)
                mlflow.log_metric("test_accuracy", test_accuracy.item(), step=epoch)
        
        # Save model
        torch.save(model.state_dict(), 'model.pth')
        mlflow.log_artifact('model.pth')
        mlflow.pytorch.log_model(model, "model")
        
        print("Training completed and logged to MLflow!")

if __name__ == "__main__":
    train_model()
EOF
    
    # Create DVC pipeline
    cat > dvc.yaml <<'EOF'
stages:
  train:
    cmd: python src/train.py
    deps:
    - src/train.py
    outs:
    - models/
EOF
    
    # Create .gitignore
    cat > .gitignore <<'EOF'
/models/
*.pth
__pycache__/
.ipynb_checkpoints/
EOF
    
    git add .
    git commit -m "Initial project setup"
    
    cd - > /dev/null
    
    log_info "Example project setup completed."
}

print_access_info() {
    log_info "Stage 1 deployment completed successfully!"
    echo
    echo "=== Access Information ==="
    echo "JupyterHub: http://jupyterhub.${DOMAIN}/"
    echo "MLflow: http://mlflow.${DOMAIN}/"
    echo "Grafana: http://grafana.${DOMAIN}/"
    echo "  - Username: admin"
    echo "  - Password: ${GRAFANA_ADMIN_PASSWORD}"
    echo
    echo "=== Next Steps ==="
    echo "1. Add the following to your /etc/hosts file:"
    echo "   $(curl -s ifconfig.me) jupyterhub.${DOMAIN} mlflow.${DOMAIN} grafana.${DOMAIN}"
    echo
    echo "2. Configure your OAuth application with redirect URI:"
    echo "   http://jupyterhub.${DOMAIN}/hub/oauth-callback"
    echo
    echo "3. Update the GitHub OAuth credentials in the script or as environment variables"
    echo
    echo "=== Test the Platform ==="
    echo "1. Login to JupyterHub with your GitHub account"
    echo "2. Start a JupyterLab session"
    echo "3. Run the example training script at /mnt/data/projects/example-project/src/train.py"
    echo "4. Check MLflow for logged experiments"
    echo "5. Monitor GPU usage in Grafana"
}

# Main execution
main() {
    log_info "Starting ML Platform Stage 1 deployment..."
    
    check_requirements
    setup_storage
    install_k3s
    install_helm
    setup_nvidia_gpu_operator
    setup_storage_classes
    setup_private_registry
    build_and_push_images
    setup_secrets
    install_postgresql
    install_mlflow
    install_jupyterhub
    install_monitoring
    setup_ingress
    setup_example_project
    
    print_access_info
}

# Run main function
main "$@" 