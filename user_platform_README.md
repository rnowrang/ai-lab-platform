# 🚀 AI Lab User Platform

## Multi-User ML Platform with Dynamic GPU Allocation

A comprehensive user-facing platform that transforms your AI Lab infrastructure into a service similar to RunPod.ai, allowing users to:

- **🔐 Authenticate and manage accounts**
- **🎯 Select GPU resources (1-4 GPUs)**  
- **🚀 Spin up containerized ML environments**
- **📊 Monitor usage and costs**
- **💻 Access JupyterLab, VS Code, or custom environments**

## 🎯 Quick Start

### Option 1: Standalone Interface (Immediate)
```bash
python setup_user_platform.py
# Opens ai_lab_user_platform.html in your browser
```

### Option 2: Full Platform Deployment
```bash
python user-platform/deploy_user_platform.py
# Deploys complete backend + frontend with Docker
```

## 🌟 Key Features

### **User Experience**
- **One-click environments**: Launch JupyterLab with GPUs in 30 seconds
- **Resource flexibility**: Choose 1-4 GPUs based on workload  
- **Cost transparency**: Real-time usage and cost tracking
- **Templates**: Pre-configured ML stacks (PyTorch, TensorFlow, etc.)
- **Collaboration**: Share environments and datasets

### **For Administrators**
- **Resource utilization**: Monitor GPU efficiency across users
- **User management**: Quotas, permissions, billing
- **Performance analytics**: Platform usage patterns
- **Cost optimization**: Automated resource scaling

## 🏗️ Architecture

```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   Frontend      │    │   Backend API    │    │   Kubernetes    │
│   Dashboard     │────│   & Auth         │────│   + GPU Sched   │
│   (React/Vue)   │    │   (FastAPI)      │    │   (k3s + NVIDIA) │
└─────────────────┘    └──────────────────┘    └─────────────────┘
         │                        │                        │
         │              ┌──────────────────┐              │
         └──────────────│   User Database  │──────────────┘
                        │   (PostgreSQL)   │
                        └──────────────────┘
```

## 🎮 Available Templates

### **PyTorch + JupyterLab**
- Pre-configured PyTorch environment
- JupyterLab interface
- 1 GPU • 16GB RAM recommended

### **TensorFlow + JupyterLab** 
- TensorFlow environment optimized for deep learning
- Keras integration
- 1 GPU • 16GB RAM recommended

### **VS Code Development**
- Full development environment
- VS Code Server
- 1 GPU • 8GB RAM recommended

### **Multi-GPU Training**
- Distributed training setup
- Multiple GPU support
- 4 GPU • 32GB RAM recommended

## 🔧 Technical Implementation

### **Backend (FastAPI)**
- **Authentication**: JWT tokens with refresh
- **Resource Management**: GPU allocation and scheduling
- **Kubernetes Integration**: Dynamic pod creation
- **Monitoring**: Real-time usage metrics
- **Database**: PostgreSQL for users and environments

### **Frontend (React)**
- **Dashboard**: Resource usage overview
- **Environment Creator**: GPU selection interface
- **Real-time Updates**: WebSocket integration
- **Responsive Design**: Mobile-friendly interface

### **Infrastructure**
- **Kubernetes**: k3s with NVIDIA GPU Operator
- **Container Registry**: Private Docker registry
- **Monitoring**: Prometheus + Grafana
- **Storage**: Persistent volumes for user data

## 📊 Resource Quotas

### **Default User Quotas**
- **GPUs**: 2 concurrent GPUs
- **Memory**: 32GB RAM
- **Storage**: 100GB persistent storage
- **Environments**: 5 concurrent environments

### **Premium User Quotas**
- **GPUs**: 4 concurrent GPUs
- **Memory**: 64GB RAM  
- **Storage**: 500GB persistent storage
- **Environments**: 10 concurrent environments

## 🚀 Deployment Options

### **Development (Docker Compose)**
```bash
cd user-platform
docker compose up -d
```

### **Production (Kubernetes)**
```bash
kubectl apply -f deployment/k8s/
```

### **Cloud (AWS/GCP/Azure)**
```bash
# Terraform configurations included
terraform apply
```

## 🔗 Integration with Existing AI Lab

This user platform integrates seamlessly with your existing AI Lab infrastructure:

- **✅ Uses existing MLflow tracking**
- **✅ Connects to existing Grafana monitoring**
- **✅ Leverages existing Docker images**
- **✅ Integrates with existing GPU resources**

## 📈 Scaling

### **Single Server (4 GPUs)**
- Support for 10-20 concurrent users
- Fair-share GPU scheduling
- Local storage optimization

### **Multi-Server Cluster**
- Horizontal scaling across nodes
- Distributed GPU allocation
- Shared storage (NFS/Ceph)

### **Cloud Hybrid**
- Burst to cloud during peak usage
- Cost optimization algorithms
- Multi-cloud support

## 🎯 Use Cases

### **Research Teams**
- **Individual workspaces**: Isolated environments per researcher
- **Shared datasets**: Common data access patterns
- **Experiment tracking**: Integration with MLflow
- **Collaboration**: Shared notebooks and models

### **Educational Institutions**
- **Student accounts**: Resource quotas per student
- **Course templates**: Pre-configured environments for classes
- **Assignment submission**: Integration with academic workflows
- **Cost management**: Budget tracking per department

### **Enterprise ML Teams**
- **Project-based access**: Environments per project
- **Resource governance**: Admin controls and approvals
- **Compliance**: Audit trails and security
- **Cost allocation**: Chargeback to business units

## 🔒 Security Features

- **🔐 JWT Authentication**: Secure token-based auth
- **🛡️ Role-based Access**: Admin, user, and guest roles
- **🔒 Network Isolation**: User namespaces in Kubernetes
- **📝 Audit Logging**: Complete activity tracking
- **🚫 Resource Limits**: Prevent resource abuse

## 📞 Support

For questions, issues, or feature requests:
- **📚 Documentation**: See `/docs` folder
- **🐛 Issues**: GitHub Issues
- **💬 Discussions**: GitHub Discussions
- **📧 Email**: support@ai-lab.com

## 🚀 Future Roadmap

- **🤝 Collaboration features**: Real-time notebook sharing
- **💰 Billing integration**: Cost tracking and invoicing  
- **🔌 Plugin system**: Custom environment extensions
- **📱 Mobile app**: iOS/Android management app
- **🤖 AI assistant**: Automated environment recommendations

---

**Transform your ML infrastructure into a world-class user platform! 🌟**
