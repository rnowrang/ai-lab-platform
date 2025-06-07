#!/usr/bin/env python3
"""
AI Lab User Platform Deployment Script
Deploys the complete user-facing platform with authentication and resource management
"""

import os
import sys
import subprocess
import time
import json
from pathlib import Path

def run_command(cmd, check=True, shell=True):
    """Run a command and return the result"""
    try:
        print(f"🔧 Running: {cmd}")
        result = subprocess.run(cmd, shell=shell, check=check, capture_output=True, text=True)
        if result.stdout:
            print(result.stdout)
        return result
    except subprocess.CalledProcessError as e:
        print(f"❌ Error running command: {cmd}")
        print(f"❌ Error: {e.stderr}")
        if check:
            sys.exit(1)
        return e

def check_prerequisites():
    """Check if required tools are installed"""
    print("🔍 Checking prerequisites...")
    
    # Check Docker
    try:
        subprocess.run(["docker", "--version"], check=True, capture_output=True)
        print("✅ Docker found")
    except:
        print("❌ Docker not found. Please install Docker first.")
        sys.exit(1)
    
    # Check Docker Compose
    try:
        subprocess.run(["docker", "compose", "version"], check=True, capture_output=True)
        print("✅ Docker Compose found")
    except:
        print("❌ Docker Compose not found. Please install Docker Compose first.")
        sys.exit(1)
    
    # Check Python
    try:
        subprocess.run([sys.executable, "--version"], check=True, capture_output=True)
        print("✅ Python found")
    except:
        print("❌ Python not found.")
        sys.exit(1)

def create_backend_requirements():
    """Create requirements.txt for the backend"""
    requirements = """
fastapi==0.104.1
uvicorn[standard]==0.24.0
pydantic[email]==2.5.0
sqlalchemy==2.0.23
asyncpg==0.29.0
alembic==1.12.1
bcrypt==4.1.1
python-jose[cryptography]==3.3.0
python-multipart==0.0.6
redis==5.0.1
celery==5.3.4
kubernetes==28.1.0
prometheus-client==0.19.0
psycopg2-binary==2.9.9
""".strip()
    
    with open("user-platform/backend/requirements.txt", "w") as f:
        f.write(requirements)
    
    print("✅ Created backend requirements.txt")

def create_user_platform_docker_compose():
    """Create Docker Compose file for the user platform"""
    compose_content = """
version: '3.8'

services:
  # Backend API
  user-platform-api:
    build: ./backend
    ports:
      - "8000:8000"
    environment:
      - DATABASE_URL=postgresql://postgres:password@postgres:5432/ai_lab_users
      - REDIS_URL=redis://redis:6379
      - JWT_SECRET_KEY=your-super-secret-jwt-key-change-in-production
      - KUBERNETES_IN_CLUSTER=false
    depends_on:
      - postgres
      - redis
    volumes:
      - ~/.kube:/root/.kube:ro  # For k8s access
      - /var/run/docker.sock:/var/run/docker.sock  # For Docker access
    networks:
      - ai-lab-network

  # Frontend
  user-platform-web:
    build: ./frontend
    ports:
      - "3000:3000"
    environment:
      - REACT_APP_API_URL=http://localhost:8000
    depends_on:
      - user-platform-api
    networks:
      - ai-lab-network

  # User Database (separate from MLflow)
  postgres:
    image: postgres:15
    environment:
      - POSTGRES_DB=ai_lab_users
      - POSTGRES_USER=postgres
      - POSTGRES_PASSWORD=password
    volumes:
      - user_platform_postgres_data:/var/lib/postgresql/data
    ports:
      - "5433:5432"  # Different port to avoid conflict
    networks:
      - ai-lab-network

  # Redis for session management and queues
  redis:
    image: redis:7-alpine
    ports:
      - "6380:6379"  # Different port to avoid conflict
    volumes:
      - user_platform_redis_data:/data
    networks:
      - ai-lab-network

  # Background worker for resource management
  worker:
    build: ./backend
    command: celery -A app.worker worker --loglevel=info
    environment:
      - DATABASE_URL=postgresql://postgres:password@postgres:5432/ai_lab_users
      - REDIS_URL=redis://redis:6379
      - JWT_SECRET_KEY=your-super-secret-jwt-key-change-in-production
    depends_on:
      - postgres
      - redis
    volumes:
      - ~/.kube:/root/.kube:ro
      - /var/run/docker.sock:/var/run/docker.sock
    networks:
      - ai-lab-network

volumes:
  user_platform_postgres_data:
  user_platform_redis_data:

networks:
  ai-lab-network:
    external: true
"""
    
    with open("user-platform/docker-compose.yml", "w") as f:
        f.write(compose_content.strip())
    
    print("✅ Created user platform docker-compose.yml")

def create_backend_dockerfile():
    """Create Dockerfile for the backend"""
    dockerfile_content = """
FROM python:3.11-slim

WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y \\
    gcc \\
    libpq-dev \\
    curl \\
    && rm -rf /var/lib/apt/lists/*

# Install kubectl
RUN curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl" \\
    && chmod +x kubectl \\
    && mv kubectl /usr/local/bin/

# Copy requirements and install Python dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy application code
COPY . .

# Create non-root user
RUN useradd -m -u 1000 appuser && chown -R appuser:appuser /app
USER appuser

# Expose port
EXPOSE 8000

# Run the application
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
"""
    
    with open("user-platform/backend/Dockerfile", "w") as f:
        f.write(dockerfile_content.strip())
    
    print("✅ Created backend Dockerfile")

def create_frontend_dockerfile():
    """Create Dockerfile for the frontend"""
    dockerfile_content = """
FROM node:18-alpine

WORKDIR /app

# Copy package files
COPY package*.json ./

# Install dependencies
RUN npm install

# Copy source code
COPY . .

# Build the app
RUN npm run build

# Install serve to run the built app
RUN npm install -g serve

# Expose port
EXPOSE 3000

# Serve the built app
CMD ["serve", "-s", "build", "-l", "3000"]
"""
    
    with open("user-platform/frontend/Dockerfile", "w") as f:
        f.write(dockerfile_content.strip())
    
    print("✅ Created frontend Dockerfile")

def create_demo_script():
    """Create a demo script to show the platform features"""
    demo_script = """
#!/usr/bin/env python3
\"\"\"
AI Lab User Platform Demo
Demonstrates the key features of the platform
\"\"\"

import requests
import json
import time

API_BASE = "http://localhost:8000"

def demo_user_registration():
    \"\"\"Demo user registration\"\"\"
    print("\\n🔐 Demo: User Registration")
    
    user_data = {
        "name": "Demo User",
        "email": "demo@ailab.com", 
        "password": "demopassword123"
    }
    
    try:
        response = requests.post(f"{API_BASE}/api/auth/register", json=user_data)
        if response.status_code == 200:
            print("✅ User registered successfully")
            return response.json()
        else:
            print(f"❌ Registration failed: {response.text}")
            return None
    except Exception as e:
        print(f"❌ Error: {e}")
        return None

def demo_user_login():
    \"\"\"Demo user login\"\"\"
    print("\\n🔑 Demo: User Login")
    
    login_data = {
        "email": "demo@ailab.com",
        "password": "demopassword123"
    }
    
    try:
        response = requests.post(f"{API_BASE}/api/auth/login", json=login_data)
        if response.status_code == 200:
            token_data = response.json()
            print("✅ Login successful")
            return token_data["access_token"]
        else:
            print(f"❌ Login failed: {response.text}")
            return None
    except Exception as e:
        print(f"❌ Error: {e}")
        return None

def demo_resource_templates(token):
    \"\"\"Demo fetching resource templates\"\"\"
    print("\\n📋 Demo: Available Templates")
    
    headers = {"Authorization": f"Bearer {token}"}
    
    try:
        response = requests.get(f"{API_BASE}/api/resources/templates", headers=headers)
        if response.status_code == 200:
            templates = response.json()["templates"]
            print(f"✅ Found {len(templates)} templates:")
            for template in templates:
                print(f"   • {template['name']}: {template['description']}")
            return templates
        else:
            print(f"❌ Failed to fetch templates: {response.text}")
            return []
    except Exception as e:
        print(f"❌ Error: {e}")
        return []

def demo_resource_usage(token):
    \"\"\"Demo checking resource usage\"\"\"
    print("\\n📊 Demo: Resource Usage")
    
    headers = {"Authorization": f"Bearer {token}"}
    
    try:
        response = requests.get(f"{API_BASE}/api/resources/usage", headers=headers)
        if response.status_code == 200:
            usage = response.json()
            print("✅ Current resource usage:")
            print(f"   • GPUs: {usage['current_gpus']}/{usage['quota']['max_gpus']}")
            print(f"   • Memory: {usage['current_memory_gb']}GB/{usage['quota']['max_memory_gb']}GB")
            print(f"   • Environments: {usage['current_environments']}/{usage['quota']['max_environments']}")
            return usage
        else:
            print(f"❌ Failed to fetch usage: {response.text}")
            return None
    except Exception as e:
        print(f"❌ Error: {e}")
        return None

def demo_create_environment(token):
    \"\"\"Demo creating a new environment\"\"\"
    print("\\n🚀 Demo: Create Environment")
    
    headers = {"Authorization": f"Bearer {token}"}
    
    environment_request = {
        "environment_type": "jupyter",
        "gpu_count": 1,
        "gpu_type": "rtx-3090", 
        "cpu_cores": 4,
        "memory_gb": 16,
        "storage_gb": 50,
        "environment_name": "demo-jupyter-env"
    }
    
    try:
        response = requests.post(f"{API_BASE}/api/resources/request", 
                               json=environment_request, headers=headers)
        if response.status_code == 200:
            env = response.json()
            print("✅ Environment creation initiated:")
            print(f"   • Name: {env['name']}")
            print(f"   • Type: {env['environment_type']}")
            print(f"   • GPUs: {env['gpu_count']}x {env['gpu_type']}")
            print(f"   • Status: {env['status']}")
            return env
        else:
            print(f"❌ Failed to create environment: {response.text}")
            return None
    except Exception as e:
        print(f"❌ Error: {e}")
        return None

def main():
    \"\"\"Run the demo\"\"\"
    print("🎯 AI Lab User Platform Demo")
    print("=" * 50)
    
    # Check if API is running
    try:
        response = requests.get(f"{API_BASE}/health")
        if response.status_code != 200:
            print("❌ API is not running. Please start the user platform first.")
            return
    except:
        print("❌ Cannot connect to API. Please start the user platform first.")
        return
    
    print("✅ API is running")
    
    # Demo flow
    demo_user_registration()
    time.sleep(1)
    
    token = demo_user_login()
    if not token:
        print("❌ Cannot proceed without authentication")
        return
    
    time.sleep(1)
    demo_resource_templates(token)
    
    time.sleep(1)
    demo_resource_usage(token)
    
    time.sleep(1)
    demo_create_environment(token)
    
    print("\\n🎉 Demo completed!")
    print("📱 Open http://localhost:3000 to access the web interface")
    print("📚 Open http://localhost:8000/docs to explore the API")

if __name__ == "__main__":
    main()
"""
    
    with open("user-platform/demo.py", "w", encoding="utf-8") as f:
        f.write(demo_script.strip())
    
    os.chmod("user-platform/demo.py", 0o755)
    print("✅ Created demo script")

def main():
    """Main deployment function"""
    print("🚀 AI Lab User Platform Deployment")
    print("=" * 50)
    
    # Check prerequisites
    check_prerequisites()
    
    # Create directory structure
    os.makedirs("user-platform/backend/app", exist_ok=True)
    os.makedirs("user-platform/frontend/src", exist_ok=True)
    
    print("📁 Created directory structure")
    
    # Create configuration files
    create_backend_requirements()
    create_user_platform_docker_compose()
    create_backend_dockerfile()
    create_frontend_dockerfile()
    create_demo_script()
    
    print("\n🔧 Building and starting services...")
    
    # Change to user platform directory
    os.chdir("user-platform")
    
    # Create network if it doesn't exist
    run_command("docker network create ai-lab-network", check=False)
    
    # Build and start services
    run_command("docker compose build")
    run_command("docker compose up -d")
    
    print("\n⏳ Waiting for services to start...")
    time.sleep(30)
    
    # Check service status
    run_command("docker compose ps")
    
    print("\n🎉 User Platform Deployment Complete!")
    print("=" * 50)
    print("🌐 Frontend Dashboard: http://localhost:3000")
    print("🔧 Backend API: http://localhost:8000")
    print("📚 API Documentation: http://localhost:8000/docs")
    print("🗄️ Database: postgresql://postgres:password@localhost:5433/ai_lab_users")
    print("\n🎯 Quick Start:")
    print("1. Open http://localhost:3000 in your browser")
    print("2. Register a new account")
    print("3. Create your first ML environment")
    print("4. Run: python demo.py for a guided demo")
    
    print("\n📋 Available Features:")
    print("✅ User authentication and registration")
    print("✅ GPU resource allocation (1-4 GPUs)")
    print("✅ Environment templates (PyTorch, TensorFlow, VS Code)")
    print("✅ Real-time resource monitoring")
    print("✅ Kubernetes integration for dynamic scaling")
    print("✅ User quotas and resource management")

if __name__ == "__main__":
    main() 