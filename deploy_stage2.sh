#!/bin/bash

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
DOMAIN=${DOMAIN:-"ml-platform.local"}

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

check_stage1() {
    log_info "Checking if Stage 1 is deployed and running..."
    
    # Check if required namespaces exist
    for ns in jupyterhub mlflow monitoring; do
        if ! kubectl get namespace $ns &> /dev/null; then
            log_error "Namespace $ns not found. Please deploy Stage 1 first."
            exit 1
        fi
    done
    
    # Check if MLflow is running
    if ! kubectl get deployment mlflow-server -n mlflow &> /dev/null; then
        log_error "MLflow server not found. Please deploy Stage 1 first."
        exit 1
    fi
    
    # Check if MLflow is accessible
    local mlflow_ready=$(kubectl get deployment mlflow-server -n mlflow -o jsonpath='{.status.readyReplicas}')
    if [[ "$mlflow_ready" != "1" ]]; then
        log_error "MLflow server is not ready. Please ensure Stage 1 is fully deployed."
        exit 1
    fi
    
    log_info "Stage 1 verification passed."
}

build_torchserve_image() {
    log_info "Building TorchServe image..."
    
    # Build TorchServe image
    docker build -t localhost:5000/torchserve:latest -f Dockerfile.torchserve .
    docker push localhost:5000/torchserve:latest
    
    log_info "TorchServe image built and pushed."
}

setup_model_serving_namespace() {
    log_info "Setting up model serving namespace..."
    
    kubectl create namespace model-serving || true
    
    # Create service account with necessary permissions
    kubectl apply -f - <<EOF
apiVersion: v1
kind: ServiceAccount
metadata:
  name: model-serving-sa
  namespace: model-serving
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: model-serving-reader
rules:
- apiGroups: [""]
  resources: ["secrets", "configmaps"]
  verbs: ["get", "list"]
- apiGroups: [""]
  resources: ["persistentvolumeclaims"]
  verbs: ["get", "list"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: model-serving-binding
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: model-serving-reader
subjects:
- kind: ServiceAccount
  name: model-serving-sa
  namespace: model-serving
EOF
    
    log_info "Model serving namespace and RBAC setup completed."
}

deploy_torchserve() {
    log_info "Deploying TorchServe inference service..."
    
    kubectl apply -f torchserve-manifests/
    
    # Wait for deployment to be ready
    kubectl wait --for=condition=available --timeout=300s deployment/torchserve -n model-serving
    
    log_info "TorchServe deployed successfully."
}

setup_model_registry_integration() {
    log_info "Setting up model registry integration..."
    
    # Create configmap with model registry configuration
    kubectl apply -f - <<EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: model-registry-config
  namespace: model-serving
data:
  mlflow_tracking_uri: "http://mlflow-service.mlflow:5000"
  model_store_path: "/mnt/models"
  models_config: |
    [
      {
        "model_name": "example_model",
        "model_version": "latest",
        "model_path": "/mnt/models/example_model"
      }
    ]
EOF
    
    log_info "Model registry integration configured."
}

setup_autoscaling() {
    log_info "Setting up autoscaling for inference service..."
    
    # Install metrics server if not present
    if ! kubectl get deployment metrics-server -n kube-system &> /dev/null; then
        kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
        
        # Patch metrics server for insecure TLS (for development)
        kubectl patch deployment metrics-server -n kube-system --type='json' \
            -p='[{"op": "add", "path": "/spec/template/spec/containers/0/args/-", "value": "--kubelet-insecure-tls"}]'
        
        # Wait for metrics server to be ready
        kubectl wait --for=condition=available --timeout=120s deployment/metrics-server -n kube-system
    fi
    
    # Create HPA for TorchServe
    kubectl apply -f - <<EOF
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: torchserve-hpa
  namespace: model-serving
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: torchserve
  minReplicas: 1
  maxReplicas: 4
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70
  - type: Resource
    resource:
      name: memory
      target:
        type: Utilization
        averageUtilization: 80
  behavior:
    scaleDown:
      stabilizationWindowSeconds: 300
      policies:
      - type: Percent
        value: 50
        periodSeconds: 60
    scaleUp:
      stabilizationWindowSeconds: 60
      policies:
      - type: Percent
        value: 100
        periodSeconds: 30
EOF
    
    log_info "Autoscaling configured."
}

setup_inference_monitoring() {
    log_info "Setting up inference monitoring..."
    
    # Add TorchServe metrics to Prometheus
    kubectl apply -f - <<EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: prometheus-torchserve-config
  namespace: monitoring
data:
  torchserve_scrape_config.yml: |
    - job_name: 'torchserve'
      kubernetes_sd_configs:
        - role: endpoints
          namespaces:
            names:
            - model-serving
      relabel_configs:
        - source_labels: [__meta_kubernetes_service_name]
          action: keep
          regex: torchserve-service
        - source_labels: [__meta_kubernetes_endpoint_port_name]
          action: keep
          regex: metrics
EOF
    
    # Update Grafana with inference dashboard
    kubectl apply -f - <<EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: inference-dashboard
  namespace: monitoring
  labels:
    grafana_dashboard: "1"
data:
  inference-dashboard.json: |
    {
      "dashboard": {
        "id": null,
        "title": "Model Inference Dashboard",
        "description": "Monitoring for TorchServe inference service",
        "tags": ["inference", "torchserve"],
        "timezone": "browser",
        "panels": [
          {
            "title": "Inference Requests/sec",
            "type": "graph",
            "targets": [
              {
                "expr": "rate(ts_inference_requests_total[5m])",
                "legendFormat": "{{model_name}} - {{method}}"
              }
            ],
            "gridPos": {"h": 8, "w": 12, "x": 0, "y": 0}
          },
          {
            "title": "Inference Latency",
            "type": "graph",
            "targets": [
              {
                "expr": "ts_inference_latency_microseconds",
                "legendFormat": "{{model_name}} - p{{quantile}}"
              }
            ],
            "gridPos": {"h": 8, "w": 12, "x": 12, "y": 0}
          },
          {
            "title": "Model Queue Size",
            "type": "graph",
            "targets": [
              {
                "expr": "ts_queue_latency_microseconds",
                "legendFormat": "{{model_name}}"
              }
            ],
            "gridPos": {"h": 8, "w": 12, "x": 0, "y": 8}
          },
          {
            "title": "Active Workers",
            "type": "stat",
            "targets": [
              {
                "expr": "ts_worker_thread_total",
                "legendFormat": "Workers"
              }
            ],
            "gridPos": {"h": 8, "w": 12, "x": 12, "y": 8}
          }
        ],
        "time": {
          "from": "now-1h",
          "to": "now"
        },
        "refresh": "30s"
      }
    }
EOF
    
    log_info "Inference monitoring configured."
}

setup_inference_ingress() {
    log_info "Setting up inference service ingress..."
    
    kubectl apply -f - <<EOF
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: inference-ingress
  namespace: model-serving
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /
    nginx.ingress.kubernetes.io/proxy-body-size: "50m"
    nginx.ingress.kubernetes.io/proxy-read-timeout: "300"
    nginx.ingress.kubernetes.io/proxy-send-timeout: "300"
spec:
  ingressClassName: nginx
  rules:
  - host: inference.${DOMAIN}
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: torchserve-service
            port:
              number: 8080
EOF
    
    log_info "Inference ingress configured."
}

create_model_deployment_script() {
    log_info "Creating model deployment helper script..."
    
    cat > deploy-model.py <<'EOF'
#!/usr/bin/env python3
"""
Helper script to deploy models from MLflow to TorchServe
"""
import os
import sys
import mlflow
import argparse
import subprocess
import tempfile
import shutil
from pathlib import Path

def download_model_from_mlflow(model_name, model_version, output_dir):
    """Download model from MLflow Model Registry"""
    try:
        # Set MLflow tracking URI
        mlflow.set_tracking_uri(os.getenv('MLFLOW_TRACKING_URI', 'http://mlflow.ml-platform.local'))
        
        # Get model version
        client = mlflow.tracking.MlflowClient()
        model_version_info = client.get_model_version(model_name, model_version)
        
        # Download model
        model_uri = f"models:/{model_name}/{model_version}"
        local_path = mlflow.artifacts.download_artifacts(model_uri, dst_path=output_dir)
        
        print(f"Model downloaded to: {local_path}")
        return local_path
        
    except Exception as e:
        print(f"Error downloading model: {e}")
        sys.exit(1)

def create_torchserve_archive(model_path, model_name, output_dir):
    """Create TorchServe model archive (.mar file)"""
    try:
        # Create handler file
        handler_content = '''
import torch
import torch.nn.functional as F
from ts.torch_handler.base_handler import BaseHandler
import json
import logging

logger = logging.getLogger(__name__)

class ModelHandler(BaseHandler):
    def __init__(self):
        super(ModelHandler, self).__init__()
        self.initialized = False

    def initialize(self, context):
        """Initialize model"""
        properties = context.system_properties
        model_dir = properties.get("model_dir")
        
        # Load model
        serialized_file = os.path.join(model_dir, "model.pth")
        if os.path.isfile(serialized_file):
            self.model = torch.jit.load(serialized_file)
        else:
            # Try to load PyTorch model
            self.model = torch.load(os.path.join(model_dir, "pytorch_model.bin"))
        
        self.model.eval()
        self.initialized = True
        logger.info('Model initialized successfully')

    def preprocess(self, data):
        """Preprocess input data"""
        preprocessed_data = []
        for row in data:
            input_data = row.get("data") or row.get("body")
            if isinstance(input_data, str):
                input_data = json.loads(input_data)
            
            # Convert to tensor
            tensor = torch.FloatTensor(input_data)
            preprocessed_data.append(tensor)
        
        return torch.stack(preprocessed_data)

    def inference(self, data):
        """Run inference"""
        with torch.no_grad():
            results = self.model(data)
        return results

    def postprocess(self, data):
        """Postprocess results"""
        return data.tolist()
'''
        
        handler_file = os.path.join(output_dir, "handler.py")
        with open(handler_file, 'w') as f:
            f.write(handler_content)
        
        # Create model archive
        archive_cmd = [
            "torch-model-archiver",
            "--model-name", model_name,
            "--version", "1.0",
            "--serialized-file", os.path.join(model_path, "model.pth"),
            "--handler", handler_file,
            "--export-path", output_dir
        ]
        
        subprocess.run(archive_cmd, check=True)
        mar_file = os.path.join(output_dir, f"{model_name}.mar")
        
        print(f"Model archive created: {mar_file}")
        return mar_file
        
    except Exception as e:
        print(f"Error creating model archive: {e}")
        sys.exit(1)

def deploy_to_torchserve(mar_file, model_name):
    """Deploy model to TorchServe"""
    try:
        # Copy MAR file to TorchServe model store
        model_store = "/mnt/models"
        shutil.copy2(mar_file, model_store)
        
        # Register model with TorchServe management API
        register_url = "http://torchserve-service.model-serving:8081/models"
        register_data = {
            "model_name": model_name,
            "url": f"{model_name}.mar",
            "initial_workers": 1,
            "synchronous": True
        }
        
        import requests
        response = requests.post(register_url, json=register_data)
        
        if response.status_code == 200:
            print(f"Model {model_name} deployed successfully!")
        else:
            print(f"Error deploying model: {response.text}")
            
    except Exception as e:
        print(f"Error deploying to TorchServe: {e}")
        sys.exit(1)

def main():
    parser = argparse.ArgumentParser(description="Deploy MLflow model to TorchServe")
    parser.add_argument("--model-name", required=True, help="MLflow model name")
    parser.add_argument("--model-version", default="latest", help="Model version")
    
    args = parser.parse_args()
    
    with tempfile.TemporaryDirectory() as temp_dir:
        # Download model from MLflow
        model_path = download_model_from_mlflow(args.model_name, args.model_version, temp_dir)
        
        # Create TorchServe archive
        mar_file = create_torchserve_archive(model_path, args.model_name, temp_dir) 
        
        # Deploy to TorchServe
        deploy_to_torchserve(mar_file, args.model_name)

if __name__ == "__main__":
    main()
EOF
    
    chmod +x deploy-model.py
    
    log_info "Model deployment script created."
}

create_inference_examples() {
    log_info "Creating inference examples..."
    
    # Create inference client example
    cat > inference_client.py <<'EOF'
#!/usr/bin/env python3
"""
Example client for making inference requests to TorchServe
"""
import requests
import json
import numpy as np
import argparse

def make_prediction(model_name, data, endpoint="http://inference.ml-platform.local"):
    """Make prediction request to TorchServe"""
    url = f"{endpoint}/predictions/{model_name}"
    
    headers = {"Content-Type": "application/json"}
    payload = {"data": data.tolist() if isinstance(data, np.ndarray) else data}
    
    try:
        response = requests.post(url, json=payload, headers=headers, timeout=30)
        response.raise_for_status()
        
        result = response.json()
        print(f"Prediction result: {result}")
        return result
        
    except requests.exceptions.RequestException as e:
        print(f"Error making prediction: {e}")
        return None

def main():
    parser = argparse.ArgumentParser(description="Make inference request")
    parser.add_argument("--model", required=True, help="Model name")
    parser.add_argument("--data", help="JSON data for prediction")
    parser.add_argument("--endpoint", default="http://inference.ml-platform.local", 
                       help="Inference endpoint")
    
    args = parser.parse_args()
    
    # Parse input data
    if args.data:
        data = json.loads(args.data)
    else:
        # Generate sample data for demonstration
        data = np.random.randn(1, 20).tolist()  # Assuming 20 features
        print(f"Using sample data: {data}")
    
    # Make prediction
    result = make_prediction(args.model, data, args.endpoint)
    
    if result:
        print("Prediction successful!")
    else:
        print("Prediction failed!")

if __name__ == "__main__":
    main()
EOF
    
    chmod +x inference_client.py
    
    log_info "Inference examples created."
}

print_stage2_info() {
    log_info "Stage 2 deployment completed successfully!"
    echo
    echo "=== Model Serving Access Information ==="
    echo "Inference API: http://inference.${DOMAIN}/"
    echo "TorchServe Management: http://inference.${DOMAIN}:8081/"
    echo
    echo "=== Model Deployment ==="
    echo "1. Use deploy-model.py to deploy models from MLflow:"
    echo "   ./deploy-model.py --model-name my_model --model-version 1"
    echo
    echo "2. Make inference requests:"
    echo "   ./inference_client.py --model my_model --data '[1,2,3,4,5]'"
    echo
    echo "=== Monitoring ==="
    echo "- Check Grafana for inference metrics dashboard"
    echo "- HPA will automatically scale inference pods based on CPU/memory"
    echo
    echo "=== Test the Inference Pipeline ==="
    echo "1. Train a model using JupyterLab and log to MLflow"
    echo "2. Register the model in MLflow Model Registry"
    echo "3. Deploy the model using deploy-model.py"
    echo "4. Make inference requests using inference_client.py"
    echo "5. Monitor performance in Grafana"
}

# Main execution
main() {
    log_info "Starting ML Platform Stage 2 deployment..."
    
    check_stage1
    build_torchserve_image
    setup_model_serving_namespace
    deploy_torchserve
    setup_model_registry_integration
    setup_autoscaling
    setup_inference_monitoring
    setup_inference_ingress
    create_model_deployment_script
    create_inference_examples
    
    print_stage2_info
}

# Run main function
main "$@" 