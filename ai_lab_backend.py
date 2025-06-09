from flask import Flask, jsonify, request, send_file
from flask_cors import CORS
import docker
import subprocess
import json
import os
from datetime import datetime
import psutil
import GPUtil
import shutil
import zipfile
from werkzeug.utils import secure_filename
from pathlib import Path

app = Flask(__name__)
CORS(app)

# Initialize Docker client
try:
    docker_client = docker.from_env()
except Exception as e:
    print(f"⚠️ Docker client initialization failed: {e}")
    docker_client = None

# Resource quota configurations
RESOURCE_QUOTAS = {
    "default": {
        "max_gpus": 1,
        "max_memory_gb": 8,
        "max_cpu_cores": 2,
        "max_storage_gb": 50,
        "max_environments": 2,
        "max_runtime_hours": 24,
        "priority": 1
    },
    "premium": {
        "max_gpus": 2,
        "max_memory_gb": 16,
        "max_cpu_cores": 4,
        "max_storage_gb": 100,
        "max_environments": 4,
        "max_runtime_hours": 48,
        "priority": 2
    },
    "enterprise": {
        "max_gpus": 4,
        "max_memory_gb": 32,
        "max_cpu_cores": 8,
        "max_storage_gb": 200,
        "max_environments": 8,
        "max_runtime_hours": 168,  # 1 week
        "priority": 3
    }
}

# Environment configurations
ENVIRONMENT_CONFIGS = {
    "pytorch-jupyter": {
        "name": "PyTorch + JupyterLab",
        "image": "ai-lab-jupyter",
        "ports": {"8888": "8888"},  # Map host port 8888 to container port 8888
        "access_url": "http://localhost:8888/lab",
        "type": "jupyter",
        "resource_requirements": {
            "min_memory_gb": 4,
            "min_cpu_cores": 1,
            "gpu_required": True
        }
    },
    "tensorflow-jupyter": {
        "name": "TensorFlow + JupyterLab", 
        "image": "ai-lab-jupyter",
        "ports": {"8889": "8888"},  # Map host port 8889 to container port 8888
        "access_url": "http://localhost:8889/lab",
        "type": "jupyter",
        "resource_requirements": {
            "min_memory_gb": 4,
            "min_cpu_cores": 1,
            "gpu_required": True
        }
    },
    "vscode": {
        "name": "VS Code Development",
        "image": "ai-lab-vscode",
        "ports": {"8080": "8080"},  # Map host port 8080 to container port 8080
        "access_url": "http://localhost:8080",
        "type": "vscode",
        "resource_requirements": {
            "min_memory_gb": 2,
            "min_cpu_cores": 1,
            "gpu_required": False
        }
    },
    "multi-gpu": {
        "name": "Multi-GPU Training",
        "image": "ai-lab-jupyter",
        "ports": {"8890": "8888"},  # Map host port 8890 to container port 8888
        "access_url": "http://localhost:8890/lab",
        "type": "jupyter",
        "resource_requirements": {
            "min_memory_gb": 8,
            "min_cpu_cores": 2,
            "gpu_required": True,
            "min_gpus": 2
        }
    }
}

# Environment templates
ENVIRONMENT_TEMPLATES = {
    "pytorch-basic": {
        "base_type": "pytorch-jupyter",
        "packages": [
            "torch",
            "torchvision",
            "numpy",
            "pandas",
            "matplotlib"
        ],
        "description": "Basic PyTorch environment for deep learning"
    },
    "pytorch-advanced": {
        "base_type": "pytorch-jupyter",
        "packages": [
            "torch",
            "torchvision",
            "torchaudio",
            "transformers",
            "numpy",
            "pandas",
            "matplotlib",
            "scikit-learn",
            "tensorboard"
        ],
        "description": "Advanced PyTorch environment with NLP and CV support"
    },
    "pytorch-nlp": {
        "base_type": "pytorch-jupyter",
        "packages": [
            "torch",
            "transformers",
            "datasets",
            "tokenizers",
            "numpy",
            "pandas",
            "matplotlib",
            "tensorboard",
            "wandb",
            "nltk",
            "spacy"
        ],
        "description": "Specialized PyTorch environment for NLP tasks"
    },
    "pytorch-cv": {
        "base_type": "pytorch-jupyter",
        "packages": [
            "torch",
            "torchvision",
            "albumentations",
            "opencv-python",
            "numpy",
            "pandas",
            "matplotlib",
            "tensorboard",
            "wandb",
            "pillow"
        ],
        "description": "Specialized PyTorch environment for Computer Vision"
    },
    "tensorflow-basic": {
        "base_type": "tensorflow-jupyter",
        "packages": [
            "tensorflow",
            "numpy",
            "pandas",
            "matplotlib"
        ],
        "description": "Basic TensorFlow environment for deep learning"
    },
    "tensorflow-advanced": {
        "base_type": "tensorflow-jupyter",
        "packages": [
            "tensorflow",
            "tensorflow-hub",
            "tensorflow-datasets",
            "numpy",
            "pandas",
            "matplotlib",
            "scikit-learn",
            "tensorboard",
            "wandb"
        ],
        "description": "Advanced TensorFlow environment with additional tools"
    },
    "data-science": {
        "base_type": "vscode",
        "packages": [
            "numpy",
            "pandas",
            "scikit-learn",
            "matplotlib",
            "seaborn",
            "jupyter",
            "statsmodels",
            "plotly"
        ],
        "description": "Data science environment with common ML libraries"
    },
    "mlops": {
        "base_type": "vscode",
        "packages": [
            "mlflow",
            "dvc",
            "pytest",
            "black",
            "flake8",
            "pre-commit",
            "hydra-core",
            "wandb",
            "prometheus-client"
        ],
        "description": "MLOps environment with experiment tracking and versioning"
    },
    "reinforcement-learning": {
        "base_type": "pytorch-jupyter",
        "packages": [
            "torch",
            "gymnasium",
            "stable-baselines3",
            "numpy",
            "pandas",
            "matplotlib",
            "tensorboard"
        ],
        "description": "Environment for reinforcement learning research"
    },
    "distributed-training": {
        "base_type": "multi-gpu",
        "packages": [
            "torch",
            "torchvision",
            "torch.distributed",
            "horovod",
            "numpy",
            "pandas",
            "matplotlib",
            "tensorboard"
        ],
        "description": "Environment for distributed model training"
    }
}

# Data management configuration
DATA_BASE_PATH = Path("ai-lab-data")
USER_DATA_PATH = DATA_BASE_PATH / "users"
SHARED_DATA_PATH = DATA_BASE_PATH / "shared"
ADMIN_DATA_PATH = DATA_BASE_PATH / "admin"

# Ensure data directories exist
for path in [USER_DATA_PATH, SHARED_DATA_PATH, ADMIN_DATA_PATH]:
    path.mkdir(parents=True, exist_ok=True)

# Configure file uploads after DATA_BASE_PATH is defined
app.config['MAX_CONTENT_LENGTH'] = 500 * 1024 * 1024  # 500MB max file size
app.config['UPLOAD_FOLDER'] = str(DATA_BASE_PATH)

class DataManager:
    def __init__(self, base_path=DATA_BASE_PATH):
        self.base_path = Path(base_path)
        self.user_data_path = self.base_path / "users"
        self.shared_data_path = self.base_path / "shared"
        self.admin_data_path = self.base_path / "admin"
        
        # Ensure all base directories exist
        for path in [self.user_data_path, self.shared_data_path, self.admin_data_path]:
            path.mkdir(parents=True, exist_ok=True)
    
    def get_user_data_path(self, user_id):
        """Get the data directory path for a specific user"""
        user_path = self.user_data_path / self._sanitize_user_id(user_id)
        user_path.mkdir(parents=True, exist_ok=True)
        
        # Create standard subdirectories
        for subdir in ["datasets", "notebooks", "models", "workspace"]:
            (user_path / subdir).mkdir(parents=True, exist_ok=True)
        
        return user_path
    
    def _sanitize_user_id(self, user_id):
        """Sanitize user ID to be filesystem safe"""
        return secure_filename(user_id.replace("@", "_at_").replace(".", "_"))
    
    def get_user_storage_info(self, user_id):
        """Get storage usage information for a user"""
        user_path = self.get_user_data_path(user_id)
        
        def get_dir_size(path):
            if not path.exists():
                return 0
            return sum(f.stat().st_size for f in path.rglob('*') if f.is_file())
        
        storage_info = {
            "total_bytes": get_dir_size(user_path),
            "datasets_bytes": get_dir_size(user_path / "datasets"),
            "notebooks_bytes": get_dir_size(user_path / "notebooks"),
            "models_bytes": get_dir_size(user_path / "models"),
            "workspace_bytes": get_dir_size(user_path / "workspace"),
        }
        
        # Convert to human readable - create new dict to avoid modifying during iteration
        human_readable = {}
        for key, value in storage_info.items():
            human_readable[key.replace('_bytes', '_human')] = self._bytes_to_human(value)
        
        # Add human readable values to storage_info
        storage_info.update(human_readable)
        
        return storage_info
    
    def _bytes_to_human(self, bytes_count):
        """Convert bytes to human readable format"""
        for unit in ['B', 'KB', 'MB', 'GB', 'TB']:
            if bytes_count < 1024.0:
                return f"{bytes_count:.1f} {unit}"
            bytes_count /= 1024.0
        return f"{bytes_count:.1f} PB"
    
    def list_user_files(self, user_id, category="all"):
        """List files in user's data directory"""
        user_path = self.get_user_data_path(user_id)
        
        if category == "all":
            search_paths = [user_path / subdir for subdir in ["datasets", "notebooks", "models", "workspace"]]
        else:
            search_paths = [user_path / category]
        
        files = []
        for search_path in search_paths:
            if search_path.exists():
                for file_path in search_path.rglob('*'):
                    if file_path.is_file():
                        relative_path = file_path.relative_to(user_path)
                        files.append({
                            "name": file_path.name,
                            "path": str(relative_path),
                            "category": str(relative_path.parts[0]),
                            "size_bytes": file_path.stat().st_size,
                            "size_human": self._bytes_to_human(file_path.stat().st_size),
                            "modified": file_path.stat().st_mtime,
                        })
        
        return sorted(files, key=lambda x: x['modified'], reverse=True)
    
    def list_shared_datasets(self):
        """List available shared datasets"""
        shared_datasets_path = self.shared_data_path / "datasets"
        datasets = []
        
        if shared_datasets_path.exists():
            for dataset_path in shared_datasets_path.iterdir():
                if dataset_path.is_dir():
                    def get_dir_size(path):
                        return sum(f.stat().st_size for f in path.rglob('*') if f.is_file())
                    
                    size_bytes = get_dir_size(dataset_path)
                    datasets.append({
                        "name": dataset_path.name,
                        "path": str(dataset_path.relative_to(self.shared_data_path)),
                        "size_bytes": size_bytes,
                        "size_human": self._bytes_to_human(size_bytes),
                        "file_count": len(list(dataset_path.rglob('*'))),
                    })
        
        return sorted(datasets, key=lambda x: x['name'])
    
    def copy_shared_dataset_to_user(self, dataset_name, user_id):
        """Copy a shared dataset to user's datasets directory"""
        shared_dataset_path = self.shared_data_path / "datasets" / dataset_name
        user_dataset_path = self.get_user_data_path(user_id) / "datasets" / dataset_name
        
        if not shared_dataset_path.exists():
            raise FileNotFoundError(f"Shared dataset '{dataset_name}' not found")
        
        if user_dataset_path.exists():
            raise FileExistsError(f"Dataset '{dataset_name}' already exists in user's directory")
        
        shutil.copytree(shared_dataset_path, user_dataset_path)
        return True
    
    def create_user_backup(self, user_id):
        """Create a backup of user's data"""
        user_path = self.get_user_data_path(user_id)
        backup_path = self.admin_data_path / "backups"
        backup_path.mkdir(parents=True, exist_ok=True)
        
        backup_filename = f"backup_{self._sanitize_user_id(user_id)}_{int(datetime.now().timestamp())}.zip"
        backup_file_path = backup_path / backup_filename
        
        with zipfile.ZipFile(backup_file_path, 'w', zipfile.ZIP_DEFLATED) as zipf:
            for file_path in user_path.rglob('*'):
                if file_path.is_file():
                    arcname = file_path.relative_to(user_path)
                    zipf.write(file_path, arcname)
        
        return {
            "backup_filename": backup_filename,
            "backup_path": str(backup_file_path),
            "size_bytes": backup_file_path.stat().st_size,
            "size_human": self._bytes_to_human(backup_file_path.stat().st_size),
        }

# Initialize data manager
data_manager = DataManager()

class ResourceManager:
    def __init__(self, docker_client):
        self.docker_client = docker_client
        self.user_environments = {}  # Track environments per user
        self.environment_start_times = {}  # Track environment runtime
        self.allocated_ports = set()  # Track allocated ports to prevent conflicts
    
    def check_user_quota(self, user_id, quota_type="default"):
        """Check if user has reached their quota limits"""
        if user_id not in self.user_environments:
            self.user_environments[user_id] = []
        
        quota = RESOURCE_QUOTAS[quota_type]
        current_environments = len(self.user_environments[user_id])
        
        if current_environments >= quota["max_environments"]:
            return False, f"Maximum number of environments ({quota['max_environments']}) reached"
        
        return True, "Quota check passed"
    
    def track_environment(self, user_id, container_id):
        """Track a new environment for a user"""
        if user_id not in self.user_environments:
            self.user_environments[user_id] = []
        
        self.user_environments[user_id].append(container_id)
        self.environment_start_times[container_id] = datetime.now()
    
    def get_environment_owner(self, container_id):
        """Get the owner of a specific environment"""
        for user_id, environments in self.user_environments.items():
            if container_id in environments:
                return user_id
        return None
    
    def user_owns_environment(self, user_id, container_id):
        """Check if a user owns a specific environment"""
        if user_id not in self.user_environments:
            return False
        return container_id in self.user_environments[user_id]
    
    def untrack_environment(self, user_id, container_id):
        """Remove environment tracking for a user"""
        if user_id in self.user_environments:
            self.user_environments[user_id].remove(container_id)
        if container_id in self.environment_start_times:
            del self.environment_start_times[container_id]
    
    def allocate_port(self, start_port=8888, max_attempts=100):
        """Allocate an available port and track it"""
        import socket
        
        # Get all ports currently used by Docker containers
        used_docker_ports = set()
        if self.docker_client:
            try:
                containers = self.docker_client.containers.list()
                for container in containers:
                    ports = container.attrs.get('NetworkSettings', {}).get('Ports', {})
                    for container_port, host_bindings in ports.items():
                        if host_bindings:
                            for binding in host_bindings:
                                if binding.get('HostPort'):
                                    used_docker_ports.add(int(binding['HostPort']))
            except Exception:
                pass  # Continue even if we can't get Docker port info
        
        for port in range(start_port, start_port + max_attempts):
            # Skip if we've already allocated this port
            if port in self.allocated_ports:
                continue
            
            # Skip if Docker is already using this port
            if port in used_docker_ports:
                continue
                
            # Check if port is actually available
            try:
                with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
                    s.bind(('localhost', port))
                    # Port is available, allocate it
                    self.allocated_ports.add(port)
                    return port
            except OSError:
                continue
        
        raise Exception(f"No available port found in range {start_port}-{start_port + max_attempts}")
    
    def release_port(self, port):
        """Release a port from tracking"""
        self.allocated_ports.discard(port)
    
    def check_runtime_limits(self, container_id, quota_type="default"):
        """Check if environment has exceeded runtime limit"""
        if container_id not in self.environment_start_times:
            return True, "No runtime tracking"
        
        start_time = self.environment_start_times[container_id]
        runtime = datetime.now() - start_time
        max_runtime = RESOURCE_QUOTAS[quota_type]["max_runtime_hours"]
        
        if runtime.total_seconds() / 3600 > max_runtime:
            return False, f"Environment has exceeded maximum runtime of {max_runtime} hours"
        
        return True, "Runtime check passed"
    
    def get_user_resource_usage(self, user_id):
        """Get current resource usage for a user"""
        if user_id not in self.user_environments:
            return {
                "environments": 0,
                "running_environments": 0,
                "paused_environments": 0,
                "total_memory_gb": 0,
                "total_cpu_cores": 0,
                "total_gpus": 0
            }
        
        total_memory = 0
        total_cpu = 0
        total_gpus = 0
        running_count = 0
        paused_count = 0
        
        for container_id in self.user_environments[user_id]:
            try:
                container = self.docker_client.containers.get(container_id)
                
                # Count environment statuses
                if container.status == 'running':
                    running_count += 1
                    # Only count resources for running containers
                    stats = container.stats(stream=False)
                    
                    # Get memory usage
                    memory_usage = stats['memory_stats']['usage'] / (1024 ** 3)
                    total_memory += memory_usage
                    
                    # Get CPU usage
                    cpu_count = len(stats['cpu_stats']['cpu_usage']['percpu_usage'])
                    total_cpu += cpu_count
                    
                    # Get GPU usage (if available)
                    try:
                        gpus = GPUtil.getGPUs()
                        total_gpus += len([gpu for gpu in gpus if gpu.memoryUtil > 0])
                    except:
                        pass
                        
                elif container.status == 'paused':
                    paused_count += 1
                    # Paused containers don't consume CPU/memory resources
                    
            except Exception:
                continue
        
        return {
            "environments": len(self.user_environments[user_id]),
            "running_environments": running_count,
            "paused_environments": paused_count,
            "total_memory_gb": round(total_memory, 2),
            "total_cpu_cores": total_cpu,
            "total_gpus": total_gpus
        }

# Initialize resource manager
resource_manager = ResourceManager(docker_client)

def check_resource_availability(env_type, user_quota="default"):
    """Check if requested resources are available"""
    if not docker_client:
        return False, "Docker not available"
    
    config = ENVIRONMENT_CONFIGS[env_type]
    quota = RESOURCE_QUOTAS[user_quota]
    
    # Check GPU availability
    if config["resource_requirements"].get("gpu_required", False):
        try:
            gpus = GPUtil.getGPUs()
            available_gpus = len([gpu for gpu in gpus if gpu.memoryUtil < 0.9])
            required_gpus = config["resource_requirements"].get("min_gpus", 1)
            
            if available_gpus < required_gpus:
                return False, f"Not enough GPUs available. Required: {required_gpus}, Available: {available_gpus}"
        except Exception as e:
            return False, f"Error checking GPU availability: {str(e)}"
    
    # Check memory availability
    memory = psutil.virtual_memory()
    available_memory_gb = memory.available / (1024 ** 3)
    required_memory_gb = config["resource_requirements"]["min_memory_gb"]
    
    if available_memory_gb < required_memory_gb:
        return False, f"Not enough memory available. Required: {required_memory_gb}GB, Available: {available_memory_gb:.1f}GB"
    
    return True, "Resources available"

def check_environment_health(container):
    """Check the health of an environment with comprehensive monitoring"""
    try:
        # Get container stats
        stats = container.stats(stream=False)
        
        # Check if container is running
        if container.status != 'running':
            return False, "Container is not running"
        
        # Check memory usage
        memory_usage = stats['memory_stats']['usage'] / (1024 ** 3)  # Convert to GB
        memory_limit = stats['memory_stats']['limit'] / (1024 ** 3)
        memory_percent = (memory_usage / memory_limit) * 100
        
        # Check CPU usage
        cpu_delta = stats['cpu_stats']['cpu_usage']['total_usage'] - stats['precpu_stats']['cpu_usage']['total_usage']
        system_delta = stats['cpu_stats']['system_cpu_usage'] - stats['precpu_stats']['system_cpu_usage']
        cpu_percent = (cpu_delta / system_delta) * 100 if system_delta > 0 else 0
        
        # Check disk I/O
        disk_io = stats.get('blkio_stats', {}).get('io_service_bytes_recursive', [])
        read_bytes = sum(item['value'] for item in disk_io if item['op'] == 'Read')
        write_bytes = sum(item['value'] for item in disk_io if item['op'] == 'Write')
        
        # Check network I/O
        net_stats = stats.get('networks', {}).get('eth0', {})
        rx_bytes = net_stats.get('rx_bytes', 0)
        tx_bytes = net_stats.get('tx_bytes', 0)
        
        # Check GPU usage if available
        gpu_stats = {}
        try:
            gpus = GPUtil.getGPUs()
            for gpu in gpus:
                gpu_stats[f"gpu_{gpu.id}"] = {
                    "utilization": gpu.load * 100,
                    "memory_used": gpu.memoryUsed,
                    "memory_total": gpu.memoryTotal,
                    "temperature": gpu.temperature
                }
        except Exception as e:
            gpu_stats = {"error": str(e)}
        
        # Check process health
        try:
            processes = container.top()
            process_count = len(processes['Processes'])
            zombie_processes = sum(1 for p in processes['Processes'] if p[2] == 'Z')
        except Exception as e:
            process_count = 0
            zombie_processes = 0
        
        # Determine overall health
        health_status = {
            "healthy": True,
            "warnings": [],
            "errors": []
        }
        
        # Memory checks
        if memory_percent > 90:
            health_status["healthy"] = False
            health_status["errors"].append(f"Critical memory usage: {memory_percent:.1f}%")
        elif memory_percent > 80:
            health_status["warnings"].append(f"High memory usage: {memory_percent:.1f}%")
        
        # CPU checks
        if cpu_percent > 90:
            health_status["healthy"] = False
            health_status["errors"].append(f"Critical CPU usage: {cpu_percent:.1f}%")
        elif cpu_percent > 80:
            health_status["warnings"].append(f"High CPU usage: {cpu_percent:.1f}%")
        
        # Process checks
        if zombie_processes > 0:
            health_status["healthy"] = False
            health_status["errors"].append(f"Found {zombie_processes} zombie processes")
        
        # GPU checks
        for gpu_id, gpu_stat in gpu_stats.items():
            if isinstance(gpu_stat, dict) and "utilization" in gpu_stat:
                if gpu_stat["utilization"] > 90:
                    health_status["warnings"].append(f"High GPU {gpu_id} utilization: {gpu_stat['utilization']:.1f}%")
                if gpu_stat["temperature"] > 80:
                    health_status["warnings"].append(f"High GPU {gpu_id} temperature: {gpu_stat['temperature']}°C")
        
        # Prepare detailed stats
        detailed_stats = {
            "memory": {
                "usage_gb": round(memory_usage, 2),
                "limit_gb": round(memory_limit, 2),
                "percent": round(memory_percent, 1)
            },
            "cpu": {
                "usage_percent": round(cpu_percent, 1)
            },
            "disk": {
                "read_bytes": read_bytes,
                "write_bytes": write_bytes
            },
            "network": {
                "rx_bytes": rx_bytes,
                "tx_bytes": tx_bytes
            },
            "gpu": gpu_stats,
            "processes": {
                "total": process_count,
                "zombies": zombie_processes
            }
        }
        
        return health_status["healthy"], {
            "status": "healthy" if health_status["healthy"] else "unhealthy",
            "warnings": health_status["warnings"],
            "errors": health_status["errors"],
            "stats": detailed_stats
        }
        
    except Exception as e:
        return False, {
            "status": "error",
            "error": str(e),
            "stats": {}
        }

@app.route('/api/health')
def health_check():
    return {"status": "healthy", "timestamp": datetime.now().isoformat()}

@app.route('/api/environments')
def get_environments():
    """Get list of running environments (admin view - all environments)"""
    user_id = request.args.get('user_id')
    
    if user_id:
        # Redirect to user-specific endpoint
        return get_user_environments(user_id)
    
    # Admin view - show all environments
    environments = []
    
    if not docker_client:
        return jsonify({"environments": [], "error": "Docker not available"})
    
    try:
        containers = docker_client.containers.list(all=True)
        
        for container in containers:
            if container.name.startswith('ai-lab-'):
                # Skip system containers (docker-compose services)
                if container.name in ['ai-lab-postgres-1', 'ai-lab-prometheus-1', 'ai-lab-grafana-1']:
                    continue
                
                # Filter out containers that are user-created environments
                # Only include containers that are actually user environments (jupyter, vscode, etc.)
                if not any(x in container.name for x in ['jupyter', 'vscode', 'pytorch', 'tensorflow']):
                    # These are system containers, skip unless they're mlflow or torchserve
                    if not any(x in container.name for x in ['mlflow', 'torchserve']):
                        continue
                
                # Map container names to environment types and get dynamic ports
                env_type = "unknown"
                access_url = "N/A"
                
                # Get actual port mappings from container
                ports = container.attrs.get('NetworkSettings', {}).get('Ports', {})
                host_port = None
                
                if "jupyter" in container.name or "pytorch" in container.name or "tensorflow" in container.name:
                    env_type = "jupyter"
                    # Look for port 8888 mapping
                    if '8888/tcp' in ports and ports['8888/tcp']:
                        host_port = ports['8888/tcp'][0]['HostPort']
                        access_url = f"http://localhost:{host_port}/lab"
                    else:
                        access_url = "http://localhost:8888/lab"  # Fallback
                elif "vscode" in container.name:
                    env_type = "vscode"
                    # Look for port 8080 mapping
                    if '8080/tcp' in ports and ports['8080/tcp']:
                        host_port = ports['8080/tcp'][0]['HostPort']
                        access_url = f"http://localhost:{host_port}"
                    else:
                        access_url = "http://localhost:8080"  # Fallback
                elif "mlflow" in container.name:
                    env_type = "mlflow"
                    if '5000/tcp' in ports and ports['5000/tcp']:
                        host_port = ports['5000/tcp'][0]['HostPort']
                        access_url = f"http://localhost:{host_port}"
                    else:
                        access_url = "http://localhost:5000"  # Fallback
                elif "torchserve" in container.name:
                    env_type = "model-serving"
                    if '8080/tcp' in ports and ports['8080/tcp']:
                        host_port = ports['8080/tcp'][0]['HostPort']
                        access_url = f"http://localhost:{host_port}"
                    else:
                        access_url = "http://localhost:8081"  # Fallback
                
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

@app.route('/api/users/<user_id>/environments')
def get_user_environments(user_id):
    """Get list of environments belonging to a specific user"""
    environments = []
    
    if not docker_client:
        return jsonify({"environments": [], "error": "Docker not available"})
    
    try:
        # Get user's tracked environments
        user_container_ids = resource_manager.user_environments.get(user_id, [])
        
        containers = docker_client.containers.list(all=True)
        
        for container in containers:
            # Only include containers that belong to this user
            if container.id in user_container_ids or container.name in user_container_ids:
                # Map container names to environment types and get dynamic ports
                env_type = "unknown"
                access_url = "N/A"
                
                # Get actual port mappings from container
                ports = container.attrs.get('NetworkSettings', {}).get('Ports', {})
                host_port = None
                
                if "jupyter" in container.name or "pytorch" in container.name or "tensorflow" in container.name:
                    env_type = "jupyter"
                    # Look for port 8888 mapping
                    if '8888/tcp' in ports and ports['8888/tcp']:
                        host_port = ports['8888/tcp'][0]['HostPort']
                        access_url = f"http://localhost:{host_port}/lab"
                    else:
                        access_url = "http://localhost:8888/lab"  # Fallback
                elif "vscode" in container.name:
                    env_type = "vscode"
                    # Look for port 8080 mapping
                    if '8080/tcp' in ports and ports['8080/tcp']:
                        host_port = ports['8080/tcp'][0]['HostPort']
                        access_url = f"http://localhost:{host_port}"
                    else:
                        access_url = "http://localhost:8080"  # Fallback
                elif "mlflow" in container.name:
                    env_type = "mlflow"
                    if '5000/tcp' in ports and ports['5000/tcp']:
                        host_port = ports['5000/tcp'][0]['HostPort']
                        access_url = f"http://localhost:{host_port}"
                    else:
                        access_url = "http://localhost:5000"  # Fallback
                elif "torchserve" in container.name:
                    env_type = "model-serving"
                    if '8080/tcp' in ports and ports['8080/tcp']:
                        host_port = ports['8080/tcp'][0]['HostPort']
                        access_url = f"http://localhost:{host_port}"
                    else:
                        access_url = "http://localhost:8081"  # Fallback
                
                environments.append({
                    "id": container.name,
                    "name": container.name.replace('ai-lab-', '').replace('-1', ''),
                    "status": container.status,
                    "type": env_type,
                    "access_url": access_url,
                    "created": container.attrs.get('Created', ''),
                    "image": container.image.tags[0] if container.image.tags else 'unknown',
                    "owner": user_id
                })
        
        return jsonify({"environments": environments, "user_id": user_id})
        
    except Exception as e:
        return jsonify({"environments": [], "error": str(e)})

@app.route('/api/environments/<env_id>/start', methods=['POST'])
def start_environment(env_id):
    """Start a specific environment"""
    if not docker_client:
        return jsonify({"error": "Docker not available"}), 500
    
    # Check user ownership
    data = request.json or {}
    user_id = data.get('user_id')
    
    if user_id and not resource_manager.user_owns_environment(user_id, env_id):
        return jsonify({"error": "Access denied - you don't own this environment"}), 403
    
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
    """Stop a specific environment and update resource tracking"""
    if not docker_client:
        return jsonify({"error": "Docker not available"}), 500
    
    # Check user ownership
    data = request.json or {}
    user_id = data.get('user_id')
    
    if user_id and not resource_manager.user_owns_environment(user_id, env_id):
        return jsonify({"error": "Access denied - you don't own this environment"}), 403
    
    try:
        container = docker_client.containers.get(env_id)
        container.stop()
        
        # Update resource tracking
        for user_id, environments in resource_manager.user_environments.items():
            if env_id in environments:
                resource_manager.untrack_environment(user_id, env_id)
                break
        
        return jsonify({"message": f"Environment {env_id} stopped successfully"})
    except docker.errors.NotFound:
        return jsonify({"error": f"Environment {env_id} not found"}), 404
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@app.route('/api/environments/<env_id>/delete', methods=['DELETE'])
def delete_environment(env_id):
    """Delete a specific environment (stop and remove container)"""
    if not docker_client:
        return jsonify({"error": "Docker not available"}), 500
    
    # Check user ownership
    user_id = request.args.get('user_id') or (request.json or {}).get('user_id')
    
    if user_id and not resource_manager.user_owns_environment(user_id, env_id):
        return jsonify({"error": "Access denied - you don't own this environment"}), 403
    
    try:
        container = docker_client.containers.get(env_id)
        
        # Stop the container if it's running
        if container.status == 'running':
            try:
                container.stop(timeout=10)
            except Exception as e:
                print(f"Warning: Could not stop container {env_id}: {e}")
        
        # Remove the container forcefully to handle all states
        try:
            container.remove(force=True)
        except Exception as e:
            print(f"Warning: Could not remove container {env_id}: {e}")
            # Try to remove without force flag as backup
            container.remove()
        
        # Get the port to release before tracking cleanup
        port_to_release = None
        try:
            # Get port info from container before deletion
            ports = container.attrs.get('NetworkSettings', {}).get('Ports', {})
            if '8888/tcp' in ports and ports['8888/tcp']:
                port_to_release = int(ports['8888/tcp'][0]['HostPort'])
            elif '8080/tcp' in ports and ports['8080/tcp']:
                port_to_release = int(ports['8080/tcp'][0]['HostPort'])
        except Exception:
            pass  # Continue even if we can't get port info
        
        # Update resource tracking
        for user_id, environments in resource_manager.user_environments.items():
            if env_id in environments:
                resource_manager.untrack_environment(user_id, env_id)
                break
        
        # Release the port if we found one
        if port_to_release:
            resource_manager.release_port(port_to_release)
        
        return jsonify({"message": f"Environment {env_id} deleted successfully"})
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

def find_available_port(start_port=8888, max_attempts=100):
    """Find an available port starting from start_port"""
    import socket
    
    for port in range(start_port, start_port + max_attempts):
        try:
            with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
                s.bind(('localhost', port))
                return port
        except OSError:
            continue
    
    raise Exception(f"No available port found in range {start_port}-{start_port + max_attempts}")

def _create_environment_core(env_type, user_id, user_quota='default'):
    """Core environment creation logic - returns (result_dict, status_code)"""
    if env_type not in ENVIRONMENT_CONFIGS:
        return {"error": "Invalid environment type"}, 400
    
    # Check user quota
    quota_ok, quota_message = resource_manager.check_user_quota(user_id, user_quota)
    if not quota_ok:
        return {"error": quota_message}, 400
    
    # Check resource availability
    available, message = check_resource_availability(env_type, user_quota)
    if not available:
        return {"error": message}, 400
    
    config = ENVIRONMENT_CONFIGS[env_type]
    
    if not docker_client:
        return {"error": "Docker not available"}, 500
    
    try:
        # Generate unique name
        timestamp = int(datetime.now().timestamp())
        container_name = f"ai-lab-{env_type}-{timestamp}"
        
        # Set resource limits based on quota
        quota = RESOURCE_QUOTAS[user_quota]
        resource_limits = {
            "memory": f"{quota['max_memory_gb']}g",
            "cpu_count": quota['max_cpu_cores']  # Keep as integer
        }
        
        # Set environment variables based on container type
        environment = {}
        if env_type == "vscode":
            environment["SERVICE_TYPE"] = "vscode"
        elif "jupyter" in env_type:
            environment["SERVICE_TYPE"] = "jupyter"
        
        # Dynamic port allocation using ResourceManager
        if env_type == "vscode":
            host_port = resource_manager.allocate_port(8080)
            container_port = "8080"
        elif "jupyter" in env_type:
            host_port = resource_manager.allocate_port(8888)
            container_port = "8888"
        else:
            # Use original port configuration for other types
            original_ports = config["ports"]
            host_port = int(list(original_ports.keys())[0])
            container_port = list(original_ports.values())[0]
        
        # Create port mapping
        ports = {container_port: host_port}
        
        # Generate dynamic access URL
        if "jupyter" in env_type:
            access_url = f"http://localhost:{host_port}/lab"
        elif env_type == "vscode":
            access_url = f"http://localhost:{host_port}"
        else:
            access_url = f"http://localhost:{host_port}"
        
        # Set up user data volumes with absolute paths
        user_data_path = data_manager.get_user_data_path(user_id).resolve()
        shared_data_path = data_manager.shared_data_path.resolve()
        
        volumes = {
            str(user_data_path): {'bind': '/home/jovyan/data', 'mode': 'rw'},
            str(shared_data_path): {'bind': '/home/jovyan/shared', 'mode': 'ro'}
        }
        
        try:
            # Create and start container with resource limits and data volumes
            container = docker_client.containers.run(
                config["image"],
                name=container_name,
                ports=ports,
                environment=environment,
                volumes=volumes,
                detach=True,
                restart_policy={"Name": "unless-stopped"},
                mem_limit=resource_limits["memory"],
                cpu_count=resource_limits["cpu_count"]
            )
            
            # Track the new environment
            resource_manager.track_environment(user_id, container.name)
            
            return {
                "message": f"Environment {container_name} created successfully",
                "container_id": container.id,
                "container_name": container.name,
                "access_url": access_url,
                "host_port": host_port,
                "resource_limits": {
                    "memory": resource_limits["memory"],
                    "cpu_count": resource_limits["cpu_count"]
                },
                "user_quota": user_quota
            }, 200
            
        except Exception as container_error:
            # Release the allocated port if container creation failed
            resource_manager.release_port(host_port)
            raise container_error
        
    except Exception as e:
        return {"error": str(e)}, 500

@app.route('/api/environments/create', methods=['POST'])
def create_environment():
    """Create a new environment with enhanced resource management"""
    data = request.json
    env_type = data.get('type', 'pytorch-jupyter')
    user_id = data.get('user_id', 'default')
    user_quota = data.get('quota', 'default')
    
    result, status_code = _create_environment_core(env_type, user_id, user_quota)
    return jsonify(result), status_code

@app.route('/api/resources/usage')
def get_resource_usage():
    """Get current system-wide resource usage"""
    if not docker_client:
        return jsonify({"error": "Docker not available"}), 500
    
    try:
        containers = docker_client.containers.list()
        
        # Count only actual user environments (not system services)
        user_environments = []
        for container in containers:
            if (container.name.startswith('ai-lab-') and 
                any(x in container.name for x in ['jupyter', 'vscode', 'pytorch', 'tensorflow']) and
                container.name not in ['ai-lab-postgres-1', 'ai-lab-prometheus-1', 'ai-lab-grafana-1']):
                user_environments.append(container)
        
        running_user_environments = len([c for c in user_environments if c.status == 'running'])
        paused_user_environments = len([c for c in user_environments if c.status == 'paused'])
        total_user_environments = len(user_environments)
        
        # Get real GPU usage and availability
        gpu_stats = {
            "total_gpus": 0,
            "available_gpus": 0,
            "gpu_utilization": 0,
            "gpu_memory_used": 0,
            "gpu_memory_total": 0
        }
        
        try:
            import GPUtil
            gpus = GPUtil.getGPUs()
            gpu_stats["total_gpus"] = len(gpus)
            gpu_stats["available_gpus"] = len([gpu for gpu in gpus if gpu.memoryUtil < 0.9])
            
            if gpus:
                avg_utilization = sum(gpu.load for gpu in gpus) / len(gpus) * 100
                total_memory_used = sum(gpu.memoryUsed for gpu in gpus)
                total_memory_total = sum(gpu.memoryTotal for gpu in gpus)
                
                gpu_stats["gpu_utilization"] = round(avg_utilization, 1)
                gpu_stats["gpu_memory_used"] = round(total_memory_used, 1)
                gpu_stats["gpu_memory_total"] = round(total_memory_total, 1)
        except Exception as e:
            # Fallback if GPUtil not available or no GPUs
            gpu_stats["error"] = str(e)
        
        # Get memory usage
        import psutil
        memory = psutil.virtual_memory()
        memory_stats = {
            "total_gb": round(memory.total / (1024**3), 1),
            "available_gb": round(memory.available / (1024**3), 1),
            "used_gb": round((memory.total - memory.available) / (1024**3), 1),
            "percent_used": round(memory.percent, 1)
        }
        
        # Get CPU usage
        cpu_count = psutil.cpu_count()
        cpu_percent = psutil.cpu_percent(interval=1)
        
        # Calculate available resources based on system limits and current usage
        max_environments = 10  # Default system limit
        max_memory_gb = memory_stats["total_gb"]
        max_gpus = gpu_stats["total_gpus"] if gpu_stats["total_gpus"] > 0 else 4  # Fallback
        
        return jsonify({
            "environments": {
                "running": running_user_environments,
                "paused": paused_user_environments,
                "total": total_user_environments,
                "available": max(0, max_environments - total_user_environments)
            },
            "gpu": gpu_stats,
            "memory": memory_stats,
            "cpu": {
                "cores": cpu_count,
                "utilization_percent": round(cpu_percent, 1)
            },
            "limits": {
                "max_environments": max_environments,
                "max_gpus": max_gpus,
                "max_memory_gb": max_memory_gb
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
        
        # Get the actual port mappings from the container
        ports = container.attrs.get('NetworkSettings', {}).get('Ports', {})
        
        # Find the host port for the container
        host_port = None
        container_type = "unknown"
        
        if "vscode" in container.name:
            container_type = "vscode"
            # Look for port 8080 mapping
            if '8080/tcp' in ports and ports['8080/tcp']:
                host_port = ports['8080/tcp'][0]['HostPort']
        elif any(x in container.name for x in ["pytorch", "tensorflow", "jupyter"]):
            container_type = "jupyter"
            # Look for port 8888 mapping
            if '8888/tcp' in ports and ports['8888/tcp']:
                host_port = ports['8888/tcp'][0]['HostPort']
        elif "mlflow" in container.name:
            container_type = "mlflow"
            if '5000/tcp' in ports and ports['5000/tcp']:
                host_port = ports['5000/tcp'][0]['HostPort']
        elif "torchserve" in container.name:
            container_type = "model-serving"
            if '8080/tcp' in ports and ports['8080/tcp']:
                host_port = ports['8080/tcp'][0]['HostPort']
        
        # Generate access URL based on actual port
        if host_port:
            if container_type == "jupyter":
                access_url = f"http://localhost:{host_port}/lab"
            elif container_type == "vscode":
                access_url = f"http://localhost:{host_port}"
            elif container_type == "mlflow":
                access_url = f"http://localhost:{host_port}"
            elif container_type == "model-serving":
                access_url = f"http://localhost:{host_port}"
            else:
                access_url = f"http://localhost:{host_port}"
        else:
            access_url = "N/A - Port not available"
        
        return jsonify({
            "access_url": access_url,
            "host_port": host_port,
            "status": container.status,
            "type": container_type,
            "ports": ports
        })
        
    except docker.errors.NotFound:
        return jsonify({"error": f"Environment {env_id} not found"}), 404
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@app.route('/api/environments/<env_id>/health', methods=['GET'])
def get_environment_health(env_id):
    """Get detailed health status of an environment"""
    if not docker_client:
        return jsonify({"error": "Docker not available"}), 500
    
    try:
        container = docker_client.containers.get(env_id)
        is_healthy, health_data = check_environment_health(container)
        
        return jsonify({
            "container_id": env_id,
            "container_name": container.name,
            "status": container.status,
            "health": health_data
        })
        
    except docker.errors.NotFound:
        return jsonify({"error": f"Environment {env_id} not found"}), 404
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@app.route('/api/environments/<env_id>/recover', methods=['POST'])
def recover_environment(env_id):
    """Attempt to recover a failing environment"""
    if not docker_client:
        return jsonify({"error": "Docker not available"}), 500
    
    try:
        container = docker_client.containers.get(env_id)
        is_healthy, message = check_environment_health(container)
        
        if is_healthy:
            return jsonify({"message": "Environment is healthy, no recovery needed"})
        
        # Attempt recovery based on the issue
        if "memory" in message.lower():
            # Restart container to clear memory
            container.restart()
            return jsonify({"message": "Environment restarted due to memory issues"})
        elif "cpu" in message.lower():
            # Restart container to clear CPU load
            container.restart()
            return jsonify({"message": "Environment restarted due to CPU issues"})
        else:
            # General recovery attempt
            container.restart()
            return jsonify({"message": "Environment restarted for recovery"})
            
    except docker.errors.NotFound:
        return jsonify({"error": f"Environment {env_id} not found"}), 404
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@app.route('/api/environments/templates', methods=['GET'])
def get_environment_templates():
    """Get list of available environment templates"""
    return jsonify({
        "templates": ENVIRONMENT_TEMPLATES
    })

@app.route('/api/environments/create-from-template', methods=['POST'])
def create_from_template():
    """Create a new environment from a template"""
    data = request.json
    template_name = data.get('template')
    custom_name = data.get('name')
    
    if template_name not in ENVIRONMENT_TEMPLATES:
        return jsonify({"error": "Invalid template name"}), 400
    
    template = ENVIRONMENT_TEMPLATES[template_name]
    base_type = template['base_type']
    
    # Create base environment using core logic
    user_id = data.get('user_id', 'default')
    user_quota = data.get('quota', 'default')
    
    result, status_code = _create_environment_core(base_type, user_id, user_quota)
    
    if status_code != 200:
        return jsonify(result), status_code
    
    # Install additional packages
    try:
        container_id = result.get('container_id')
        container_name = result.get('container_name')
        
        if not container_id:
            return jsonify({"error": "Failed to get container ID from base environment creation"}), 500
        
        container = docker_client.containers.get(container_id)
        
        # Install packages
        for package in template['packages']:
            container.exec_run(f"pip install {package}")
        
        return jsonify({
            "message": f"Environment created from template {template_name}",
            "container_id": container_id,
            "container_name": container_name,
            "template": template_name,
            "packages": template['packages'],
            "access_url": result.get('access_url')
        })
        
    except Exception as e:
        return jsonify({"error": f"Failed to install packages: {str(e)}"}), 500

@app.route('/api/environments/<env_id>/clone', methods=['POST'])
def clone_environment(env_id):
    """Clone an existing environment"""
    if not docker_client:
        return jsonify({"error": "Docker not available"}), 500
    
    try:
        source_container = docker_client.containers.get(env_id)
        
        # Get container configuration
        config = source_container.attrs['Config']
        host_config = source_container.attrs['HostConfig']
        
        # Create new container name
        timestamp = int(datetime.now().timestamp())
        new_name = f"{source_container.name}-clone-{timestamp}"
        
        # Create new container
        new_container = docker_client.containers.create(
            image=source_container.image.tags[0],
            name=new_name,
            command=config['Cmd'],
            environment=config['Env'],
            ports=host_config['PortBindings'],
            detach=True
        )
        
        # Start the new container
        new_container.start()
        
        return jsonify({
            "message": f"Environment cloned successfully",
            "source_id": env_id,
            "new_container_id": new_container.id,
            "new_name": new_name
        })
        
    except docker.errors.NotFound:
        return jsonify({"error": f"Environment {env_id} not found"}), 404
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@app.route('/')
def serve_frontend():
    """Serve the HTML frontend"""
    return send_file('ai_lab_user_platform.html')

@app.route('/admin')
def serve_admin_portal():
    """Serve the admin portal"""
    return send_file('ai_lab_admin_portal.html')

@app.route('/api/users/<user_id>/resources', methods=['GET'])
def get_user_resources(user_id):
    """Get resource usage for a specific user"""
    usage = resource_manager.get_user_resource_usage(user_id)
    return jsonify({
        "user_id": user_id,
        "resource_usage": usage
    })

@app.route('/api/environments/cleanup', methods=['POST'])
def cleanup_environments():
    """Clean up orphaned containers in 'created' state"""
    if not docker_client:
        return jsonify({"error": "Docker not available"}), 500
    
    cleaned_up = []
    errors = []
    
    try:
        containers = docker_client.containers.list(all=True)
        
        for container in containers:
            # Only clean up user-created ai-lab environments in 'created' state
            if (container.name.startswith('ai-lab-') and 
                container.status == 'created' and
                any(x in container.name for x in ['jupyter', 'vscode', 'pytorch', 'tensorflow'])):
                
                try:
                    # Get port info before removing container
                    port_to_release = None
                    try:
                        ports = container.attrs.get('NetworkSettings', {}).get('Ports', {})
                        if '8888/tcp' in ports and ports['8888/tcp']:
                            port_to_release = int(ports['8888/tcp'][0]['HostPort'])
                        elif '8080/tcp' in ports and ports['8080/tcp']:
                            port_to_release = int(ports['8080/tcp'][0]['HostPort'])
                    except Exception:
                        pass
                    
                    container.remove(force=True)
                    cleaned_up.append(container.name)
                    
                    # Update resource tracking
                    for user_id, environments in resource_manager.user_environments.items():
                        if container.name in environments:
                            resource_manager.untrack_environment(user_id, container.name)
                            break
                    
                    # Release the port if we found one
                    if port_to_release:
                        resource_manager.release_port(port_to_release)
                            
                except Exception as e:
                    errors.append(f"Failed to remove {container.name}: {str(e)}")
        
        return jsonify({
            "message": f"Cleanup completed. Removed {len(cleaned_up)} containers.",
            "cleaned_up": cleaned_up,
            "errors": errors
        })
        
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@app.route('/api/environments/<env_id>/pause', methods=['POST'])
def pause_environment(env_id):
    """Pause a specific environment to free resources while preserving state"""
    if not docker_client:
        return jsonify({"error": "Docker not available"}), 500
    
    # Check user ownership
    data = request.json or {}
    user_id = data.get('user_id')
    
    if user_id and not resource_manager.user_owns_environment(user_id, env_id):
        return jsonify({"error": "Access denied - you don't own this environment"}), 403
    
    try:
        container = docker_client.containers.get(env_id)
        
        if container.status != 'running':
            return jsonify({"error": f"Environment {env_id} is not running (status: {container.status})"}), 400
        
        # Pause the container
        container.pause()
        
        return jsonify({
            "message": f"Environment {env_id} paused successfully",
            "status": "paused",
            "note": "All processes are suspended. Resources are freed but state is preserved."
        })
        
    except docker.errors.NotFound:
        return jsonify({"error": f"Environment {env_id} not found"}), 404
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@app.route('/api/environments/<env_id>/resume', methods=['POST'])
def resume_environment(env_id):
    """Resume a paused environment and restore its state"""
    if not docker_client:
        return jsonify({"error": "Docker not available"}), 500
    
    # Check user ownership
    data = request.json or {}
    user_id = data.get('user_id')
    
    if user_id and not resource_manager.user_owns_environment(user_id, env_id):
        return jsonify({"error": "Access denied - you don't own this environment"}), 403
    
    try:
        container = docker_client.containers.get(env_id)
        
        if container.status != 'paused':
            return jsonify({"error": f"Environment {env_id} is not paused (status: {container.status})"}), 400
        
        # Resume the container
        container.unpause()
        
        return jsonify({
            "message": f"Environment {env_id} resumed successfully",
            "status": "running",
            "note": "All processes restored. You can continue exactly where you left off."
        })
        
    except docker.errors.NotFound:
        return jsonify({"error": f"Environment {env_id} not found"}), 404
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@app.route('/api/environments/<env_id>/register-user', methods=['POST'])
def register_environment_for_user(env_id):
    """Manually register an existing environment for a user (admin function)"""
    if not docker_client:
        return jsonify({"error": "Docker not available"}), 500
    
    data = request.json or {}
    user_id = data.get('user_id')
    
    if not user_id:
        return jsonify({"error": "user_id is required"}), 400
    
    try:
        # Check if environment exists
        container = docker_client.containers.get(env_id)
        
        # Check if already tracked
        if resource_manager.user_owns_environment(user_id, env_id):
            return jsonify({"message": f"Environment {env_id} already tracked for user {user_id}"}), 200
        
        # Register the environment
        resource_manager.track_environment(user_id, env_id)
        
        return jsonify({
            "message": f"Environment {env_id} successfully registered for user {user_id}",
            "user_id": user_id,
            "environment_id": env_id,
            "container_status": container.status
        })
        
    except docker.errors.NotFound:
        return jsonify({"error": f"Environment {env_id} not found"}), 404
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@app.route('/api/users/<user_id>/data', methods=['GET'])
def get_user_data(user_id):
    """Get user's data information and file listing"""
    try:
        storage_info = data_manager.get_user_storage_info(user_id)
        
        category = request.args.get('category', 'all')
        files = data_manager.list_user_files(user_id, category)
        
        return jsonify({
            "user_id": user_id,
            "storage_info": storage_info,
            "files": files,
            "category": category
        })
        
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@app.route('/api/users/<user_id>/data/upload', methods=['POST'])
def upload_user_data(user_id):
    """Upload data to user's directory"""
    if 'file' not in request.files:
        return jsonify({"error": "No file provided"}), 400
    
    file = request.files['file']
    category = request.form.get('category', 'workspace')
    
    if file.filename == '':
        return jsonify({"error": "No file selected"}), 400
    
    try:
        user_path = data_manager.get_user_data_path(user_id)
        category_path = user_path / category
        category_path.mkdir(parents=True, exist_ok=True)
        
        filename = secure_filename(file.filename)
        file_path = category_path / filename
        
        file.save(str(file_path))
        
        return jsonify({
            "message": f"File uploaded successfully to {category}",
            "filename": filename,
            "category": category,
            "size_bytes": file_path.stat().st_size,
            "size_human": data_manager._bytes_to_human(file_path.stat().st_size)
        })
        
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@app.route('/api/shared/datasets', methods=['GET'])
def get_shared_datasets():
    """Get list of available shared datasets"""
    try:
        datasets = data_manager.list_shared_datasets()
        return jsonify({
            "datasets": datasets,
            "count": len(datasets)
        })
        
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@app.route('/api/users/<user_id>/datasets/copy/<dataset_name>', methods=['POST'])
def copy_shared_dataset(user_id, dataset_name):
    """Copy a shared dataset to user's datasets directory"""
    try:
        data_manager.copy_shared_dataset_to_user(dataset_name, user_id)
        
        return jsonify({
            "message": f"Dataset '{dataset_name}' copied to user {user_id}",
            "dataset_name": dataset_name,
            "user_id": user_id
        })
        
    except FileNotFoundError as e:
        return jsonify({"error": str(e)}), 404
    except FileExistsError as e:
        return jsonify({"error": str(e)}), 409
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@app.route('/api/admin/users', methods=['GET'])
def admin_get_users():
    """Admin endpoint to get all users and their data"""
    try:
        users = []
        if data_manager.user_data_path.exists():
            for user_dir in data_manager.user_data_path.iterdir():
                if user_dir.is_dir():
                    # Convert back from sanitized format
                    user_id = user_dir.name.replace("_at_", "@").replace("_", ".")
                    
                    storage_info = data_manager.get_user_storage_info(user_id)
                    resource_usage = resource_manager.get_user_resource_usage(user_id)
                    
                    users.append({
                        "user_id": user_id,
                        "sanitized_id": user_dir.name,
                        "storage_info": storage_info,
                        "resource_usage": resource_usage,
                        "environments_count": len(resource_manager.user_environments.get(user_id, []))
                    })
        
        return jsonify({
            "users": users,
            "total_users": len(users)
        })
        
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@app.route('/api/admin/users/<user_id>/backup', methods=['POST'])
def admin_create_user_backup(user_id):
    """Admin endpoint to create backup of user's data"""
    try:
        backup_info = data_manager.create_user_backup(user_id)
        
        return jsonify({
            "message": f"Backup created for user {user_id}",
            "user_id": user_id,
            "backup_info": backup_info
        })
        
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@app.route('/api/admin/shared/datasets/upload', methods=['POST'])
def admin_upload_shared_dataset():
    """Admin endpoint to upload shared datasets"""
    if 'file' not in request.files:
        return jsonify({"error": "No file provided"}), 400
    
    file = request.files['file']
    dataset_name = request.form.get('dataset_name')
    
    if not dataset_name:
        return jsonify({"error": "Dataset name is required"}), 400
    
    if file.filename == '':
        return jsonify({"error": "No file selected"}), 400
    
    try:
        shared_datasets_path = data_manager.shared_data_path / "datasets"
        dataset_path = shared_datasets_path / secure_filename(dataset_name)
        dataset_path.mkdir(parents=True, exist_ok=True)
        
        filename = secure_filename(file.filename)
        file_path = dataset_path / filename
        
        file.save(str(file_path))
        
        return jsonify({
            "message": f"Shared dataset '{dataset_name}' uploaded successfully",
            "dataset_name": dataset_name,
            "filename": filename,
            "size_bytes": file_path.stat().st_size,
            "size_human": data_manager._bytes_to_human(file_path.stat().st_size)
        })
        
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@app.route('/api/admin/users/<user_id>/data/delete', methods=['DELETE'])
def admin_delete_user_data(user_id):
    """Admin endpoint to delete user's data"""
    try:
        user_path = data_manager.get_user_data_path(user_id)
        
        if user_path.exists():
            shutil.rmtree(user_path)
            
            return jsonify({
                "message": f"All data deleted for user {user_id}",
                "user_id": user_id
            })
        else:
            return jsonify({
                "message": f"No data found for user {user_id}",
                "user_id": user_id
            })
        
    except Exception as e:
        return jsonify({"error": str(e)}), 500

if __name__ == '__main__':
    print("Starting AI Lab Backend API")
    print("Frontend: http://localhost:5555")
    print("Admin Portal: http://localhost:5555/admin") 
    print("API Health: http://localhost:5555/api/health")
    print("Environments: http://localhost:5555/api/environments")
    
    app.run(host='0.0.0.0', port=5555, debug=True) 