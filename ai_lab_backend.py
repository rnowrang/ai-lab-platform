from flask import Flask, jsonify, request, send_file
from flask_cors import CORS
import docker
import subprocess
import json
import os
from datetime import datetime

app = Flask(__name__)
CORS(app)

# Initialize Docker client
try:
    docker_client = docker.from_env()
except Exception as e:
    print(f"⚠️ Docker client initialization failed: {e}")
    docker_client = None

# Environment configurations
ENVIRONMENT_CONFIGS = {
    "pytorch-jupyter": {
        "name": "PyTorch + JupyterLab",
        "image": "ai-lab-jupyter",
        "ports": {"8888": "8888"},
        "access_url": "http://localhost:8888",
        "type": "jupyter"
    },
    "tensorflow-jupyter": {
        "name": "TensorFlow + JupyterLab", 
        "image": "ai-lab-jupyter",
        "ports": {"8889": "8888"},
        "access_url": "http://localhost:8889",
        "type": "jupyter"
    },
    "vscode": {
        "name": "VS Code Development",
        "image": "ai-lab-vscode",
        "ports": {"8080": "8080"},
        "access_url": "http://localhost:8080",
        "type": "vscode"
    },
    "multi-gpu": {
        "name": "Multi-GPU Training",
        "image": "ai-lab-jupyter",
        "ports": {"8890": "8888"},
        "access_url": "http://localhost:8890",
        "type": "jupyter"
    }
}

@app.route('/api/health')
def health_check():
    return {"status": "healthy", "timestamp": datetime.now().isoformat()}

@app.route('/api/environments')
def get_environments():
    """Get list of running environments"""
    environments = []
    
    if not docker_client:
        return jsonify({"environments": [], "error": "Docker not available"})
    
    try:
        containers = docker_client.containers.list(all=True)
        
        for container in containers:
            if container.name.startswith('ai-lab-'):
                # Map container names to environment types
                env_type = "unknown"
                access_url = "N/A"
                
                if "jupyter" in container.name:
                    env_type = "jupyter"
                    access_url = "http://localhost:8888"
                elif "vscode" in container.name:
                    env_type = "vscode"
                    access_url = "http://localhost:8080"
                elif "mlflow" in container.name:
                    env_type = "mlflow"
                    access_url = "http://localhost:5000"
                
                environments.append({
                    "id": container.name,
                    "name": container.name.replace('ai-lab-', '').replace('-1', ''),
                    "status": container.status,
                    "type": env_type,
                    "access_url": access_url,
                    "created": container.attrs.get('Created', ''),
                    "image": container.image.tags[0] if container.image.tags else 'unknown'
                })
        
        return jsonify({"environments": environments})
        
    except Exception as e:
        return jsonify({"environments": [], "error": str(e)})

@app.route('/api/environments/<env_id>/start', methods=['POST'])
def start_environment(env_id):
    """Start a specific environment"""
    if not docker_client:
        return jsonify({"error": "Docker not available"}), 500
    
    try:
        container = docker_client.containers.get(env_id)
        container.start()
        return jsonify({"message": f"Environment {env_id} started successfully"})
    except docker.errors.NotFound:
        return jsonify({"error": f"Environment {env_id} not found"}), 404
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@app.route('/api/environments/<env_id>/stop', methods=['POST'])
def stop_environment(env_id):
    """Stop a specific environment"""
    if not docker_client:
        return jsonify({"error": "Docker not available"}), 500
    
    try:
        container = docker_client.containers.get(env_id)
        container.stop()
        return jsonify({"message": f"Environment {env_id} stopped successfully"})
    except docker.errors.NotFound:
        return jsonify({"error": f"Environment {env_id} not found"}), 404
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@app.route('/api/environments/<env_id>/restart', methods=['POST'])
def restart_environment(env_id):
    """Restart a specific environment"""
    if not docker_client:
        return jsonify({"error": "Docker not available"}), 500
    
    try:
        container = docker_client.containers.get(env_id)
        container.restart()
        return jsonify({"message": f"Environment {env_id} restarted successfully"})
    except docker.errors.NotFound:
        return jsonify({"error": f"Environment {env_id} not found"}), 404
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@app.route('/api/environments/create', methods=['POST'])
def create_environment():
    """Create a new environment"""
    data = request.json
    env_type = data.get('type', 'pytorch-jupyter')
    
    if env_type not in ENVIRONMENT_CONFIGS:
        return jsonify({"error": "Invalid environment type"}), 400
    
    config = ENVIRONMENT_CONFIGS[env_type]
    
    if not docker_client:
        return jsonify({"error": "Docker not available"}), 500
    
    try:
        # Generate unique name
        timestamp = int(datetime.now().timestamp())
        container_name = f"ai-lab-{env_type}-{timestamp}"
        
        # Create and start container
        container = docker_client.containers.run(
            config["image"],
            name=container_name,
            ports=config["ports"],
            detach=True,
            restart_policy={"Name": "unless-stopped"}
        )
        
        return jsonify({
            "message": f"Environment {container_name} created successfully",
            "container_id": container.id,
            "access_url": config["access_url"]
        })
        
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@app.route('/api/resources/usage')
def get_resource_usage():
    """Get current resource usage"""
    if not docker_client:
        return jsonify({"error": "Docker not available"}), 500
    
    try:
        containers = docker_client.containers.list()
        running_containers = len([c for c in containers if c.name.startswith('ai-lab-')])
        
        # Mock GPU usage (you can enhance this with nvidia-smi)
        gpu_usage = min(running_containers, 4)  # Assuming max 4 GPUs
        
        return jsonify({
            "current_gpus": gpu_usage,
            "current_environments": running_containers,
            "quota": {
                "max_gpus": 4,
                "max_environments": 10,
                "max_memory_gb": 64
            }
        })
        
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@app.route('/api/environments/<env_id>/access')
def get_environment_access(env_id):
    """Get access URL for a specific environment"""
    if not docker_client:
        return jsonify({"error": "Docker not available"}), 500
    
    try:
        container = docker_client.containers.get(env_id)
        
        # Determine access URL based on container type
        access_url = "http://localhost:8888"  # Default
        
        if "vscode" in container.name:
            access_url = "http://localhost:8080"
        elif "jupyter" in container.name:
            access_url = "http://localhost:8888"
        elif "mlflow" in container.name:
            access_url = "http://localhost:5000"
        
        return jsonify({
            "access_url": access_url,
            "status": container.status,
            "type": "vscode" if "vscode" in container.name else "jupyter"
        })
        
    except docker.errors.NotFound:
        return jsonify({"error": f"Environment {env_id} not found"}), 404
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@app.route('/')
def serve_frontend():
    """Serve the HTML frontend"""
    return send_file('ai_lab_user_platform.html')

if __name__ == '__main__':
    print("🚀 Starting AI Lab Backend API")
    print("🌐 Frontend: http://localhost:5555")
    print("🔧 API: http://localhost:5555/api/health")
    print("📋 Environments: http://localhost:5555/api/environments")
    
    app.run(host='0.0.0.0', port=5555, debug=True) 