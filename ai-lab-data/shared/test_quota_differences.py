#!/usr/bin/env python3
"""
Test script to demonstrate quota differences
Run this in different environments to see the actual limits
"""

import os
import subprocess
import psutil

def get_cgroup_memory_limit():
    """Get the actual Docker-enforced memory limit"""
    try:
        # Try cgroup v1
        with open('/sys/fs/cgroup/memory/memory.limit_in_bytes', 'r') as f:
            limit_bytes = int(f.read().strip())
            return limit_bytes / (1024**3)  # Convert to GB
    except:
        try:
            # Try cgroup v2
            with open('/sys/fs/cgroup/memory.max', 'r') as f:
                limit = f.read().strip()
                if limit != 'max':
                    return int(limit) / (1024**3)
        except:
            pass
    return None

def get_cpu_quota():
    """Get the actual CPU quota"""
    try:
        # Try cgroup v1
        with open('/sys/fs/cgroup/cpu/cpu.cfs_quota_us', 'r') as f:
            quota = int(f.read().strip())
        with open('/sys/fs/cgroup/cpu/cpu.cfs_period_us', 'r') as f:
            period = int(f.read().strip())
        if quota > 0:
            return quota / period
    except:
        try:
            # Try cgroup v2
            with open('/sys/fs/cgroup/cpu.max', 'r') as f:
                cpu_max = f.read().strip()
                if cpu_max != 'max':
                    quota, period = map(int, cpu_max.split())
                    return quota / period
        except:
            pass
    return None

print("🔍 Environment Resource Limits Check")
print("=" * 50)

# Get hostname to identify environment
hostname = os.environ.get('HOSTNAME', 'unknown')
print(f"Container: {hostname}")

# Memory limit
mem_limit = get_cgroup_memory_limit()
if mem_limit:
    print(f"\n📊 Memory Limit: {mem_limit:.0f} GB (Docker enforced)")
else:
    print("\n📊 Memory Limit: Unable to determine")

# CPU limit
cpu_limit = get_cpu_quota()
if cpu_limit:
    print(f"🖥️  CPU Limit: {cpu_limit:.0f} cores (Docker enforced)")
else:
    # Fallback to checking CPU affinity
    cpu_count = len(os.sched_getaffinity(0))
    print(f"🖥️  CPU Limit: {cpu_count} cores (via affinity)")

# GPU access (always all GPUs currently)
try:
    import torch
    if torch.cuda.is_available():
        gpu_count = torch.cuda.device_count()
        print(f"🎮 GPU Access: {gpu_count} GPUs (NOT limited by quota)")
    else:
        print("🎮 GPU Access: No CUDA available")
except:
    print("🎮 GPU Access: PyTorch not available")

print("\n" + "=" * 50)

# Quota tier detection based on limits
if mem_limit:
    if mem_limit <= 8:
        print("📋 Detected Quota Tier: DEFAULT (8GB RAM, 2 CPUs)")
    elif mem_limit <= 16:
        print("📋 Detected Quota Tier: PREMIUM (16GB RAM, 4 CPUs)")
    elif mem_limit <= 32:
        print("📋 Detected Quota Tier: ENTERPRISE (32GB RAM, 8 CPUs)")
    else:
        print("📋 Detected Quota Tier: CUSTOM or UNLIMITED")

print("\n💡 Note: GPU access is currently not limited by quota!")
print("   All environments can access all 4 GPUs.") 