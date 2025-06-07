"""
Resource Management Router
Handles GPU allocation, environment creation, and resource scheduling
"""

from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel
from typing import List, Optional, Dict, Any
from enum import Enum
import asyncio

from ..auth.router import get_current_user
from ..models.user import User
from ..models.environment import Environment, EnvironmentCreate, EnvironmentResponse
from ..k8s.client import KubernetesClient
from ..database import get_db_session

# Router setup
resources_router = APIRouter()

# Enums and Models
class EnvironmentType(str, Enum):
    JUPYTER = "jupyter"
    VSCODE = "vscode"
    CUSTOM = "custom"

class GPUType(str, Enum):
    RTX_3090 = "rtx-3090"
    RTX_2080_TI = "rtx-2080-ti"

class ResourceRequest(BaseModel):
    environment_type: EnvironmentType
    gpu_count: int = 1
    gpu_type: GPUType = GPUType.RTX_3090
    cpu_cores: int = 4
    memory_gb: int = 16
    storage_gb: int = 50
    environment_name: Optional[str] = None
    custom_image: Optional[str] = None
    conda_packages: Optional[List[str]] = None
    pip_packages: Optional[List[str]] = None

class ResourceQuota(BaseModel):
    max_gpus: int
    max_cpu_cores: int
    max_memory_gb: int
    max_storage_gb: int
    max_environments: int

class ResourceUsage(BaseModel):
    current_gpus: int
    current_cpu_cores: int
    current_memory_gb: int
    current_storage_gb: int
    current_environments: int
    quota: ResourceQuota


# Utility Functions
async def check_resource_availability(gpu_count: int, gpu_type: GPUType) -> bool:
    """Check if requested GPU resources are available"""
    k8s_client = KubernetesClient()
    
    # Get current GPU usage across all nodes
    gpu_usage = await k8s_client.get_gpu_usage()
    
    available_gpus = gpu_usage.get(gpu_type.value, {}).get("available", 0)
    return available_gpus >= gpu_count


async def check_user_quota(user: User, resource_request: ResourceRequest) -> bool:
    """Check if user has sufficient quota for the request"""
    current_usage = await get_user_resource_usage(user.id)
    
    # Check GPU quota
    if current_usage.current_gpus + resource_request.gpu_count > user.gpu_quota:
        return False
    
    # Check environment count quota (default max 5 environments)
    max_environments = getattr(user, 'max_environments', 5)
    if current_usage.current_environments >= max_environments:
        return False
    
    return True


async def get_user_resource_usage(user_id: int) -> ResourceUsage:
    """Get current resource usage for a user"""
    async with get_db_session() as db:
        environments = await Environment.get_by_user(db, user_id, active_only=True)
        
        total_gpus = sum(env.gpu_count for env in environments)
        total_cpu = sum(env.cpu_cores for env in environments)
        total_memory = sum(env.memory_gb for env in environments)
        total_storage = sum(env.storage_gb for env in environments)
        
        # Get user quota
        user = await User.get(db, user_id)
        quota = ResourceQuota(
            max_gpus=user.gpu_quota,
            max_cpu_cores=getattr(user, 'cpu_quota', 32),
            max_memory_gb=getattr(user, 'memory_quota', 128),
            max_storage_gb=getattr(user, 'storage_quota', 500),
            max_environments=getattr(user, 'max_environments', 5)
        )
        
        return ResourceUsage(
            current_gpus=total_gpus,
            current_cpu_cores=total_cpu,
            current_memory_gb=total_memory,
            current_storage_gb=total_storage,
            current_environments=len(environments),
            quota=quota
        )


# Routes
@resources_router.get("/availability")
async def get_resource_availability():
    """Get current resource availability"""
    k8s_client = KubernetesClient()
    
    try:
        # Get GPU availability
        gpu_usage = await k8s_client.get_gpu_usage()
        
        # Get node information
        nodes = await k8s_client.get_nodes_info()
        
        return {
            "gpus": gpu_usage,
            "nodes": nodes,
            "total_capacity": {
                "gpus": sum(node.get("gpu_capacity", 0) for node in nodes),
                "cpu_cores": sum(node.get("cpu_capacity", 0) for node in nodes),
                "memory_gb": sum(node.get("memory_capacity_gb", 0) for node in nodes)
            }
        }
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to get resource availability: {str(e)}"
        )


@resources_router.get("/usage", response_model=ResourceUsage)
async def get_user_usage(current_user: User = Depends(get_current_user)):
    """Get current user's resource usage and quota"""
    return await get_user_resource_usage(current_user.id)


@resources_router.post("/request", response_model=EnvironmentResponse)
async def request_resources(
    resource_request: ResourceRequest,
    current_user: User = Depends(get_current_user)
):
    """Request resources and create environment"""
    
    # Validate resource request
    if resource_request.gpu_count < 1 or resource_request.gpu_count > 4:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="GPU count must be between 1 and 4"
        )
    
    # Check resource availability
    if not await check_resource_availability(resource_request.gpu_count, resource_request.gpu_type):
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail=f"Insufficient {resource_request.gpu_type} GPUs available"
        )
    
    # Check user quota
    if not await check_user_quota(current_user, resource_request):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Insufficient quota for this request"
        )
    
    # Create environment record
    environment_name = resource_request.environment_name or f"{resource_request.environment_type}-{current_user.id}"
    
    async with get_db_session() as db:
        environment_data = EnvironmentCreate(
            name=environment_name,
            environment_type=resource_request.environment_type,
            gpu_count=resource_request.gpu_count,
            gpu_type=resource_request.gpu_type,
            cpu_cores=resource_request.cpu_cores,
            memory_gb=resource_request.memory_gb,
            storage_gb=resource_request.storage_gb,
            custom_image=resource_request.custom_image,
            status="creating",
            user_id=current_user.id
        )
        
        environment = await Environment.create(db, environment_data.dict())
    
    # Create Kubernetes resources
    k8s_client = KubernetesClient()
    
    try:
        # Create namespace for user if it doesn't exist
        namespace = f"user-{current_user.id}"
        await k8s_client.ensure_namespace(namespace)
        
        # Create environment pod/deployment
        k8s_config = {
            "name": environment_name,
            "namespace": namespace,
            "image": get_environment_image(resource_request),
            "gpu_count": resource_request.gpu_count,
            "gpu_type": resource_request.gpu_type,
            "cpu_cores": resource_request.cpu_cores,
            "memory_gb": resource_request.memory_gb,
            "storage_gb": resource_request.storage_gb,
            "environment_type": resource_request.environment_type,
            "user_id": current_user.id,
            "packages": {
                "conda": resource_request.conda_packages or [],
                "pip": resource_request.pip_packages or []
            }
        }
        
        pod_info = await k8s_client.create_environment_pod(k8s_config)
        
        # Update environment with Kubernetes info
        async with get_db_session() as db:
            await Environment.update(db, environment.id, {
                "k8s_namespace": namespace,
                "k8s_pod_name": pod_info["name"],
                "k8s_service_name": pod_info.get("service_name"),
                "access_url": pod_info.get("access_url"),
                "status": "starting"
            })
            
            # Refresh environment data
            environment = await Environment.get(db, environment.id)
    
    except Exception as e:
        # Clean up environment record on failure
        async with get_db_session() as db:
            await Environment.update(db, environment.id, {"status": "failed"})
        
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to create environment: {str(e)}"
        )
    
    return EnvironmentResponse.from_orm(environment)


def get_environment_image(resource_request: ResourceRequest) -> str:
    """Get the appropriate Docker image for the environment type"""
    if resource_request.custom_image:
        return resource_request.custom_image
    
    # Default images for each environment type
    images = {
        EnvironmentType.JUPYTER: "ai-lab/ml:latest",  # Our custom ML image
        EnvironmentType.VSCODE: "ai-lab/ml:latest",   # Same image, different startup
        EnvironmentType.CUSTOM: "ai-lab/ml:latest"
    }
    
    return images.get(resource_request.environment_type, "ai-lab/ml:latest")


@resources_router.get("/templates")
async def get_environment_templates():
    """Get available environment templates"""
    templates = [
        {
            "id": "pytorch-jupyter",
            "name": "PyTorch + JupyterLab",
            "description": "Pre-configured PyTorch environment with JupyterLab",
            "environment_type": "jupyter",
            "recommended_gpu": 1,
            "recommended_memory": 16,
            "packages": {
                "conda": ["pytorch", "torchvision", "torchaudio", "cudatoolkit"],
                "pip": ["transformers", "datasets", "wandb", "tensorboard"]
            }
        },
        {
            "id": "tensorflow-jupyter", 
            "name": "TensorFlow + JupyterLab",
            "description": "Pre-configured TensorFlow environment with JupyterLab",
            "environment_type": "jupyter", 
            "recommended_gpu": 1,
            "recommended_memory": 16,
            "packages": {
                "conda": ["tensorflow-gpu", "keras"],
                "pip": ["tensorflow-datasets", "tensorboard", "wandb"]
            }
        },
        {
            "id": "vscode-dev",
            "name": "VS Code Development",
            "description": "Full development environment with VS Code Server",
            "environment_type": "vscode",
            "recommended_gpu": 1,
            "recommended_memory": 8,
            "packages": {
                "conda": ["python", "jupyter", "nodejs"],
                "pip": ["black", "flake8", "pytest"]
            }
        },
        {
            "id": "multi-gpu-training",
            "name": "Multi-GPU Training",
            "description": "Optimized for distributed training with multiple GPUs",
            "environment_type": "jupyter",
            "recommended_gpu": 4,
            "recommended_memory": 32,
            "packages": {
                "conda": ["pytorch", "torchvision", "nccl"],
                "pip": ["accelerate", "deepspeed", "transformers"]
            }
        }
    ]
    
    return {"templates": templates} 