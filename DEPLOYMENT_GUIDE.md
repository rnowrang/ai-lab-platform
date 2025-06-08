# AI Lab Platform - Deployment Guide

## Quick Start (Windows)

### Prerequisites
- **Docker Desktop** installed and running
- **Python 3.8+** with pip
- **Git** (for cloning)
- **PowerShell** (for deployment script)

### 1. Automated Deployment (Recommended)

```powershell
# Start Docker Desktop first, then run:
.\deploy_full_stack.ps1
```

This script will:
- ✅ Check Docker Desktop status
- ✅ Install Python dependencies
- ✅ Build and start all Docker services
- ✅ Start the backend API server

### 2. Manual Deployment

If you prefer manual control:

```powershell
# 1. Start Docker Desktop and verify it's running
docker ps

# 2. Install Python dependencies
pip install -r requirements.txt

# 3. Start the full stack with Docker Compose
docker-compose up -d --build

# 4. Start the backend API (in a new terminal)
python ai_lab_backend.py
```

### 3. Validate Deployment

Run the validation script to check all services:

```powershell
python validate_deployment.py
```

## Service Access URLs

Once deployed, access these services:

| Service | URL | Credentials |
|---------|-----|-------------|
| **Frontend** | http://localhost:5555 | None |
| **Backend API** | http://localhost:5555/api/health | None |
| **MLflow** | http://localhost:5000 | None |
| **Grafana** | http://localhost:3000 | admin/admin123 |
| **Prometheus** | http://localhost:9090 | None |
| **Jupyter** | http://localhost:8888 | Token in logs |
| **VS Code** | http://localhost:8080 | None |

## Testing the Platform

### Run Full Test Suite
```powershell
python test_environment_management.py
```

### Test Individual Components
```powershell
# Test backend API
curl http://localhost:5555/api/health

# Test environment templates
curl http://localhost:5555/api/environments/templates

# Test resource usage
curl http://localhost:5555/api/resources/usage
```

## Platform Features

### Environment Management
- **10 specialized ML templates** (PyTorch, TensorFlow, NLP, CV, etc.)
- **Resource quota management** (default, premium, enterprise tiers)
- **Health monitoring** with detailed metrics
- **Auto-recovery** for failing environments
- **Environment cloning** and templating

### Resource Management
- **GPU allocation** and monitoring
- **Memory and CPU limits** per environment
- **Runtime limits** and automatic cleanup
- **User quota enforcement**

### Monitoring & Observability
- **Grafana dashboards** for system metrics
- **Prometheus** for metrics collection
- **Environment health checks**
- **Resource usage tracking**

### ML Workflow
- **MLflow** for experiment tracking
- **TorchServe** for model serving
- **Shared storage** for collaboration
- **Multiple development environments**

## Troubleshooting

### Docker Issues
```powershell
# Check Docker status
docker ps

# Restart Docker Desktop if needed
# Then re-run deployment
```

### Backend Issues
```powershell
# Check backend logs
python ai_lab_backend.py

# Look for "Docker client initialization failed"
# This means Docker is not accessible
```

### Service Issues
```powershell
# Check all services
docker-compose ps

# Restart specific service
docker-compose restart <service-name>

# View service logs
docker-compose logs <service-name>
```

### Port Conflicts
If ports are already in use:
```powershell
# Check what's using ports
netstat -ano | findstr :5555
netstat -ano | findstr :5000

# Kill processes if needed
taskkill /PID <process-id> /F
```

## Development Mode

For development without the full stack:

```powershell
# Just start the backend API
python ai_lab_backend.py

# Access at http://localhost:5555
```

## Architecture Overview

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Frontend      │    │   Backend API   │    │   Docker        │
│   (HTML/JS)     │◄──►│   (Flask)       │◄──►│   Containers    │
│   Port 5555     │    │   Port 5555     │    │   Various Ports │
└─────────────────┘    └─────────────────┘    └─────────────────┘
                                │
                                ▼
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   MLflow        │    │   Prometheus    │    │   Grafana       │
│   Port 5000     │    │   Port 9090     │    │   Port 3000     │
└─────────────────┘    └─────────────────┘    └─────────────────┘
```

## Next Steps

1. **Access the frontend** at http://localhost:5555
2. **Create your first environment** using a template
3. **Monitor resources** via Grafana dashboards
4. **Track experiments** with MLflow
5. **Deploy models** using TorchServe

For issues or questions, check the logs and run the validation script. 