# Multi-User ML Platform

A comprehensive, self-hosted, scalable multi-user ML platform built on Kubernetes with GPU support, designed for teams to collaborate on machine learning projects with full MLOps capabilities.

## 🏗️ Architecture Overview

This platform provides:
- **Multi-user environment** with OAuth2 authentication (GitHub/Google)
- **GPU-accelerated containers** (4× NVIDIA 2080 Ti support)
- **Persistent storage** with data versioning (DVC)
- **Experiment tracking** (MLflow)
- **Model serving** (TorchServe with autoscaling)
- **Monitoring & observability** (Prometheus + Grafana)
- **Multiple development environments** (JupyterLab, VS Code Server, Terminal)

## 📋 Prerequisites

### 🐧 Linux (Production Deployment)
- **OS**: Ubuntu 22.04 LTS
- **GPUs**: 4× NVIDIA 2080 Ti with drivers installed
- **Storage**: 10 TB attached storage
- **Memory**: Minimum 64GB RAM
- **Software**: Docker, kubectl, helm
- **Network**: Internet connectivity for initial setup

### 🪟 Windows (Development Deployment)
- **OS**: Windows 10/11 with WSL2 or Docker Desktop
- **GPUs**: NVIDIA GPU with Windows drivers (optional)
- **Memory**: Minimum 16GB RAM
- **Software**: Docker Desktop or WSL2 + Docker
- **Network**: Internet connectivity

### 📋 Common Requirements
- **Credentials**: GitHub OAuth App (Client ID & Secret)
- **Domain**: Domain name or local hosts file configuration

## 🔧 Platform Compatibility

| Feature | Linux | Windows (Docker) | Windows (WSL2) |
|---------|-------|------------------|----------------|
| **Full Kubernetes** | ✅ | ❌ | ✅ |
| **Multi-user Hub** | ✅ | ❌ Single user | ✅ |
| **GPU Support** | ✅ Native | ⚠️ Limited | ✅ Via WSL2 |
| **Production Ready** | ✅ | ❌ Dev only | ⚠️ Limited |
| **Easy Setup** | ⭐⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐⭐ |

## 🚀 Quick Start

### 🐧 Linux Deployment (Production)

#### Stage 1: Multi-User Training Environment

1. **Clone and configure:**
   ```bash
   git clone <this-repo>
   cd ml-platform
   
   # Set environment variables
   export DOMAIN="your-domain.com"  # or "ml-platform.local" for local testing
   export GITHUB_CLIENT_ID="your-github-client-id"
   export GITHUB_CLIENT_SECRET="your-github-client-secret"
   ```

2. **Deploy Stage 1:**
   ```bash
   chmod +x deploy_stage1.sh
   ./deploy_stage1.sh
   ```

### 🪟 Windows Deployment (Development)

#### Option 1: Docker Compose (Recommended for Windows)
```powershell
# PowerShell
.\deploy_stage1.ps1 -Domain "ml-platform.local"

# Or using Docker Compose directly
docker-compose up --build -d
```

#### Option 2: WSL2 + Linux Scripts
```bash
# Install WSL2 with Ubuntu
wsl --install -d Ubuntu-22.04

# Then use Linux deployment commands
./deploy_stage1.sh
```

3. **Configure DNS (for local testing):**
   ```bash
   # Add to /etc/hosts
   echo "$(curl -s ifconfig.me) jupyterhub.$DOMAIN mlflow.$DOMAIN grafana.$DOMAIN" | sudo tee -a /etc/hosts
   ```

### Stage 2: Model Serving & Inference

1. **Deploy Stage 2:**
   ```bash
   chmod +x deploy_stage2.sh
   ./deploy_stage2.sh
   ```

2. **Update DNS:**
   ```bash
   # Add inference endpoint to /etc/hosts
   echo "$(curl -s ifconfig.me) inference.$DOMAIN" | sudo tee -a /etc/hosts
   ```

## 🔧 Platform Components

### Core Services

| Service | URL | Description |
|---------|-----|-------------|
| JupyterHub | `http://jupyterhub.$DOMAIN` | Multi-user Jupyter environment |
| MLflow | `http://mlflow.$DOMAIN` | Experiment tracking & model registry |
| Grafana | `http://grafana.$DOMAIN` | Monitoring dashboards |
| Inference API | `http://inference.$DOMAIN` | Model serving endpoint |

### Default Credentials

- **Grafana**: admin / admin123 (configurable via `GRAFANA_ADMIN_PASSWORD`)
- **JupyterHub**: Use your GitHub/Google account
- **PostgreSQL**: postgres / mlflow123 (configurable via `POSTGRES_PASSWORD`)

## 👥 User Workflow

### 1. Development Environment Access

1. Navigate to `http://jupyterhub.$DOMAIN`
2. Login with GitHub/Google OAuth
3. Choose your environment:
   - **JupyterLab**: Full notebook environment
   - **VS Code Server**: Browser-based VS Code
   - **Terminal**: Command-line access

Each user gets:
- 1 dedicated GPU
- 50GB persistent home directory
- Access to shared projects folder
- Pre-installed ML libraries (PyTorch, scikit-learn, MLflow, DVC)

### 2. Model Development & Tracking

```python
import mlflow
import mlflow.pytorch

# Set tracking URI (automatically configured in containers)
mlflow.set_tracking_uri("http://mlflow-service.mlflow:5000")

# Start experiment
with mlflow.start_run():
    # Log parameters
    mlflow.log_param("learning_rate", 0.01)
    mlflow.log_param("epochs", 100)
    
    # Train your model
    model = train_model()
    
    # Log metrics
    mlflow.log_metric("accuracy", 0.95)
    
    # Log model
    mlflow.pytorch.log_model(model, "model")
```

### 3. Data Versioning with DVC

```bash
# Initialize DVC in your project
cd /shared/projects/my-project
dvc init

# Add data to version control
dvc add data/dataset.csv
git add data/dataset.csv.dvc .gitignore
git commit -m "Add dataset"

# Push data to shared remote
dvc push
```

### 4. Model Deployment

```bash
# Deploy model from MLflow to TorchServe
./deploy-model.py --model-name my_model --model-version 1

# Make inference requests
./inference_client.py --model my_model --data '[1,2,3,4,5]'
```

## 📊 Monitoring & Observability

### Grafana Dashboards

Access Grafana at `http://grafana.$DOMAIN` with admin/admin123:

1. **ML Platform Overview**: User activity, GPU utilization, system resources
2. **GPU Monitoring**: Real-time GPU metrics per user/pod
3. **Kubernetes Cluster**: Node health, pod status, resource usage
4. **Model Inference**: Request rates, latency, model performance

### Key Metrics

- **GPU Utilization**: `DCGM_FI_DEV_GPU_UTIL`
- **GPU Memory**: `DCGM_FI_DEV_FB_USED / DCGM_FI_DEV_FB_TOTAL * 100`
- **Active Users**: `count(kube_pod_info{namespace="jupyterhub"})`
- **Inference Requests**: `rate(ts_inference_requests_total[5m])`

## 🔧 Administration

### Managing Users

Users are automatically created when they first login via OAuth. To manage access:

1. **GitHub OAuth**: Configure organization restrictions in your GitHub OAuth app
2. **Resource Limits**: Modify `values-jupyterhub.yaml` to adjust CPU/memory/GPU limits
3. **Storage Quotas**: Adjust PVC sizes in storage configurations

### Scaling Resources

#### Add More GPUs
```bash
# Update node labels
kubectl label nodes <node-name> node.kubernetes.io/instance-type=gpu

# Modify JupyterHub values to allow more concurrent users
helm upgrade jupyterhub jupyterhub/jupyterhub \
  --namespace jupyterhub \
  --values values-jupyterhub.yaml \
  --set hub.config.KubeSpawner.extra_resource_limits.nvidia\.com/gpu=2
```

#### Scale Inference Service
```bash
# Manually scale TorchServe
kubectl scale deployment torchserve --replicas=3 -n model-serving

# Or modify HPA limits
kubectl patch hpa torchserve-hpa -n model-serving --patch '{"spec":{"maxReplicas":8}}'
```

### Backup & Recovery

#### Database Backup
```bash
# Backup PostgreSQL
kubectl exec -n mlflow postgresql-0 -- pg_dump -U postgres mlflowdb > mlflow_backup.sql

# Restore
kubectl exec -i -n mlflow postgresql-0 -- psql -U postgres mlflowdb < mlflow_backup.sql
```

#### Storage Backup
```bash
# Backup user data and projects
rsync -av /mnt/data/ /backup/ml-platform-$(date +%Y%m%d)/
```

### Updating Components

#### Update JupyterHub
```bash
helm repo update
helm upgrade jupyterhub jupyterhub/jupyterhub \
  --namespace jupyterhub \
  --values values-jupyterhub.yaml
```

#### Update MLflow
```bash
# Build new image with updated MLflow version
docker build -t localhost:5000/mlflow:latest -f Dockerfile.mlflow .
docker push localhost:5000/mlflow:latest

# Restart deployment
kubectl rollout restart deployment/mlflow-server -n mlflow
```

## 🐛 Troubleshooting

### Common Issues

#### GPU Not Available in Pods
```bash
# Check GPU operator status
kubectl get pods -n gpu-operator-resources

# Verify node has GPU labels
kubectl describe node <node-name> | grep nvidia.com/gpu

# Check device plugin logs
kubectl logs -n gpu-operator-resources -l app=nvidia-device-plugin-daemonset
```

#### JupyterHub Pods Failing to Start
```bash
# Check spawner logs
kubectl logs -n jupyterhub -l component=hub

# Verify storage permissions
ls -la /mnt/data/homes/

# Check resource availability
kubectl describe node <node-name>
```

#### MLflow Connection Issues
```bash
# Check MLflow service
kubectl get svc -n mlflow

# Test connectivity from user pod
kubectl exec -it <jupyter-pod> -n jupyterhub -- curl http://mlflow-service.mlflow:5000/health

# Check PostgreSQL connection
kubectl exec -it -n mlflow postgresql-0 -- psql -U postgres -d mlflowdb -c "SELECT 1;"
```

#### Storage Issues
```bash
# Check PV/PVC status
kubectl get pv,pvc --all-namespaces

# Verify mount points
df -h /mnt/data

# Check permissions
ls -la /mnt/data/
```

### Log Locations

- **JupyterHub**: `kubectl logs -n jupyterhub -l component=hub`
- **MLflow**: `kubectl logs -n mlflow -l app=mlflow-server`
- **TorchServe**: `kubectl logs -n model-serving -l app=torchserve`
- **GPU Metrics**: `kubectl logs -n gpu-operator-resources -l app=nvidia-dcgm-exporter`

## 🔒 Security Considerations

### Production Deployment

1. **Enable TLS/HTTPS**:
   ```bash
   # Install cert-manager for automatic TLS
   kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.0/cert-manager.yaml
   
   # Configure Let's Encrypt issuer
   # Update ingress manifests with TLS configuration
   ```

2. **Network Policies**:
   ```bash
   # Enable network policies in values-jupyterhub.yaml
   networkPolicy:
     enabled: true
   ```

3. **RBAC Hardening**:
   - Review and minimize service account permissions
   - Implement pod security policies
   - Enable admission controllers

4. **Secrets Management**:
   ```bash
   # Use external secret management (e.g., Vault)
   # Rotate OAuth credentials regularly
   # Use strong passwords for all services
   ```

### Access Control

- OAuth2 provides authentication
- Kubernetes RBAC controls resource access
- Network policies isolate namespaces
- Resource quotas prevent resource exhaustion

## 📈 Performance Optimization

### GPU Utilization
- Monitor GPU usage in Grafana
- Adjust batch sizes and worker counts
- Consider GPU sharing for development workloads

### Storage Performance
- Use SSD storage for better I/O performance
- Consider distributed storage solutions for larger deployments
- Implement data caching strategies

### Network Optimization
- Use local container registry to reduce pull times
- Implement image caching strategies
- Consider CDN for static assets

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

## 📄 License

This project is licensed under the MIT License - see the LICENSE file for details.

## 🆘 Support

For issues and questions:
1. Check the troubleshooting section
2. Review logs for error messages
3. Open an issue on GitHub
4. Join our community discussions

---

**Stage 1 complete—ready for Stage 2.**

This platform provides a complete MLOps environment with multi-user support, GPU acceleration, experiment tracking, model serving, and comprehensive monitoring. The modular design allows for easy customization and scaling based on your team's needs. 