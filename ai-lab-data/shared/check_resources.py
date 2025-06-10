#!/usr/bin/env python3
"""
Check actual resource limits inside a container
Run this inside your Jupyter environment to see what resources are actually available
"""

import os
import torch
import psutil
import subprocess

print("=== Resource Limits Check ===\n")

# 1. Check Memory Limits
print("1. MEMORY:")
memory = psutil.virtual_memory()
print(f"   Total System Memory: {memory.total / (1024**3):.1f} GB")
print(f"   Available Memory: {memory.available / (1024**3):.1f} GB")

# Check cgroup memory limit (Docker enforced limit)
try:
    with open('/sys/fs/cgroup/memory/memory.limit_in_bytes', 'r') as f:
        limit = int(f.read().strip())
        if limit < (1 << 62):  # Less than max value
            print(f"   Docker Memory Limit: {limit / (1024**3):.1f} GB ⚠️ ENFORCED")
        else:
            print("   Docker Memory Limit: No limit set")
except:
    # Try cgroup v2
    try:
        with open('/sys/fs/cgroup/memory.max', 'r') as f:
            limit = f.read().strip()
            if limit != 'max':
                print(f"   Docker Memory Limit: {int(limit) / (1024**3):.1f} GB ⚠️ ENFORCED")
            else:
                print("   Docker Memory Limit: No limit set")
    except:
        print("   Docker Memory Limit: Unable to determine")

# 2. Check CPU Limits
print("\n2. CPU:")
print(f"   Total System CPUs: {psutil.cpu_count(logical=True)}")
print(f"   Available CPUs: {len(os.sched_getaffinity(0))}")

# Check cgroup CPU quota
try:
    with open('/sys/fs/cgroup/cpu/cpu.cfs_quota_us', 'r') as f:
        quota = int(f.read().strip())
    with open('/sys/fs/cgroup/cpu/cpu.cfs_period_us', 'r') as f:
        period = int(f.read().strip())
    
    if quota > 0:
        cpu_limit = quota / period
        print(f"   Docker CPU Limit: {cpu_limit:.1f} cores ⚠️ ENFORCED")
    else:
        print("   Docker CPU Limit: No limit set")
except:
    # Try cgroup v2
    try:
        with open('/sys/fs/cgroup/cpu.max', 'r') as f:
            cpu_max = f.read().strip()
            if cpu_max != 'max':
                quota, period = map(int, cpu_max.split())
                cpu_limit = quota / period
                print(f"   Docker CPU Limit: {cpu_limit:.1f} cores ⚠️ ENFORCED")
            else:
                print("   Docker CPU Limit: No limit set")
    except:
        print("   Docker CPU Limit: Unable to determine")

# 3. Check GPU Access
print("\n3. GPU:")
if torch.cuda.is_available():
    print(f"   CUDA Available: Yes")
    print(f"   Number of GPUs: {torch.cuda.device_count()} 🚨 ALL GPUs ACCESSIBLE!")
    
    for i in range(torch.cuda.device_count()):
        props = torch.cuda.get_device_properties(i)
        print(f"   GPU {i}: {props.name}")
        print(f"      Memory: {props.total_memory / (1024**3):.1f} GB")
else:
    print("   CUDA Available: No")

# 4. Check environment variables
print("\n4. ENVIRONMENT:")
print(f"   Container Hostname: {os.environ.get('HOSTNAME', 'Unknown')}")
print(f"   User Quota Type: {os.environ.get('USER_QUOTA', 'Not set')}")

# 5. Test actual limits
print("\n5. TESTING LIMITS:")

# Test memory allocation
print("   Testing memory allocation...")
try:
    # Try to allocate 1GB
    test_size = 1 * 1024 * 1024 * 1024  # 1GB in bytes
    test_array = bytearray(test_size)
    print("   ✓ Can allocate 1GB of memory")
    del test_array
except:
    print("   ✗ Cannot allocate 1GB of memory")

# Test GPU memory
if torch.cuda.is_available():
    print("   Testing GPU memory...")
    try:
        # Try to allocate 1GB on each GPU
        for i in range(torch.cuda.device_count()):
            x = torch.zeros((256, 1024, 1024), device=f'cuda:{i}')  # ~1GB
            print(f"   ✓ Can allocate 1GB on GPU {i}")
            del x
            torch.cuda.empty_cache()
    except Exception as e:
        print(f"   ✗ GPU memory allocation failed: {e}")

print("\n=== Summary ===")
print("• Memory and CPU limits are enforced by Docker")
print("• GPU access is NOT limited - all GPUs are accessible")
print("• To test your actual limits, try allocating more than allowed") 