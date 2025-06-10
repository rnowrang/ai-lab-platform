#!/usr/bin/env python3
"""
Multi-GPU Training with NCCL Workarounds

This script provides workarounds for common NCCL errors in Docker containers.
"""

import torch
import torch.nn as nn
import torch.optim as optim
import os
import time

# Set NCCL environment variables for better compatibility
os.environ['NCCL_DEBUG'] = 'INFO'
os.environ['NCCL_IB_DISABLE'] = '1'  # Disable InfiniBand if not available
os.environ['NCCL_P2P_LEVEL'] = 'NVL'  # Use NVLink if available

# Optional: Disable P2P if having issues
# os.environ['NCCL_P2P_DISABLE'] = '1'

# Alternative: Use Gloo backend instead of NCCL
# os.environ['MASTER_ADDR'] = 'localhost'
# os.environ['MASTER_PORT'] = '12355'

print("PyTorch Multi-GPU Training with NCCL Workarounds")
print("=" * 50)
print(f"PyTorch version: {torch.__version__}")
print(f"CUDA available: {torch.cuda.is_available()}")
print(f"Number of GPUs: {torch.cuda.device_count()}")
print()

# Simple model
class SimpleModel(nn.Module):
    def __init__(self):
        super().__init__()
        self.fc = nn.Sequential(
            nn.Linear(1024, 512),
            nn.ReLU(),
            nn.Linear(512, 256),
            nn.ReLU(),
            nn.Linear(256, 10)
        )
    
    def forward(self, x):
        return self.fc(x)

def test_multi_gpu():
    """Test multi-GPU functionality with various workarounds"""
    
    if torch.cuda.device_count() < 2:
        print("Warning: Less than 2 GPUs available. Multi-GPU features won't work.")
        return
    
    print(f"Testing with {torch.cuda.device_count()} GPUs...")
    
    # Method 1: Try standard DataParallel
    print("\n1. Testing DataParallel...")
    try:
        model = SimpleModel()
        model = nn.DataParallel(model)
        model = model.cuda()
        
        # Test forward pass
        x = torch.randn(32, 1024).cuda()
        y = model(x)
        print("✓ DataParallel forward pass successful")
        
        # Test backward pass
        loss = y.mean()
        loss.backward()
        print("✓ DataParallel backward pass successful")
        
    except Exception as e:
        print(f"✗ DataParallel failed: {e}")
        print("\nTrying workaround: Single GPU per batch...")
        
        # Workaround: Manual distribution
        try:
            model = SimpleModel().cuda()
            x = torch.randn(32, 1024).cuda()
            y = model(x)
            loss = y.mean()
            loss.backward()
            print("✓ Single GPU training works")
        except Exception as e2:
            print(f"✗ Single GPU also failed: {e2}")
    
    # Method 2: Test with smaller batch size
    print("\n2. Testing with smaller batch size...")
    try:
        model = SimpleModel()
        model = nn.DataParallel(model)
        model = model.cuda()
        
        # Very small batch to minimize communication
        x = torch.randn(4, 1024).cuda()
        y = model(x)
        print("✓ Small batch DataParallel successful")
        
    except Exception as e:
        print(f"✗ Small batch DataParallel failed: {e}")
    
    # Method 3: Test device-to-device communication
    print("\n3. Testing GPU-to-GPU communication...")
    try:
        # Test peer access
        for i in range(torch.cuda.device_count()):
            for j in range(torch.cuda.device_count()):
                if i != j:
                    can_access = torch.cuda.can_device_access_peer(i, j)
                    print(f"  GPU {i} -> GPU {j}: {'Yes' if can_access else 'No'}")
        
        # Test tensor transfer
        x = torch.randn(100, 100).cuda(0)
        y = x.cuda(1)  # Transfer to GPU 1
        print("✓ GPU-to-GPU transfer successful")
        
    except Exception as e:
        print(f"✗ GPU communication failed: {e}")

def alternative_multi_gpu_train():
    """Alternative approach: Sequential GPU usage"""
    print("\n4. Alternative: Sequential GPU usage...")
    
    models = []
    optimizers = []
    
    # Create a model on each GPU
    for i in range(torch.cuda.device_count()):
        model = SimpleModel().cuda(i)
        optimizer = optim.Adam(model.parameters())
        models.append(model)
        optimizers.append(optimizer)
    
    # Train on each GPU sequentially
    batch_size_per_gpu = 16
    for epoch in range(2):
        total_loss = 0
        
        for gpu_id in range(torch.cuda.device_count()):
            # Generate data for this GPU
            x = torch.randn(batch_size_per_gpu, 1024).cuda(gpu_id)
            y = torch.randint(0, 10, (batch_size_per_gpu,)).cuda(gpu_id)
            
            # Forward pass
            output = models[gpu_id](x)
            loss = nn.CrossEntropyLoss()(output, y)
            
            # Backward pass
            optimizers[gpu_id].zero_grad()
            loss.backward()
            optimizers[gpu_id].step()
            
            total_loss += loss.item()
        
        avg_loss = total_loss / torch.cuda.device_count()
        print(f"Epoch {epoch+1}: Loss = {avg_loss:.4f}")
    
    print("✓ Sequential multi-GPU training successful")

if __name__ == "__main__":
    test_multi_gpu()
    
    if torch.cuda.device_count() >= 2:
        alternative_multi_gpu_train()
    
    print("\n" + "=" * 50)
    print("Recommendations:")
    print("1. Restart Jupyter kernel after changing NCCL environment variables")
    print("2. Create new containers with --ipc=host flag")
    print("3. Use DistributedDataParallel for production workloads")
    print("4. Consider using Horovod for easier multi-GPU setup") 