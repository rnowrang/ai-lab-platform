#!/usr/bin/env python3
"""
AI Lab User Platform Demo
Demonstrates the key features of the platform
"""

import requests
import json
import time

API_BASE = "http://localhost:8000"

def demo_user_registration():
    """Demo user registration"""
    print("\n🔐 Demo: User Registration")
    
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
    """Demo user login"""
    print("\n🔑 Demo: User Login")
    
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
    """Demo fetching resource templates"""
    print("\n📋 Demo: Available Templates")
    
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
    """Demo checking resource usage"""
    print("\n📊 Demo: Resource Usage")
    
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
    """Demo creating a new environment"""
    print("\n🚀 Demo: Create Environment")
    
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
    """Run the demo"""
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
    
    print("\n🎉 Demo completed!")
    print("📱 Open http://localhost:3000 to access the web interface")
    print("📚 Open http://localhost:8000/docs to explore the API")

if __name__ == "__main__":
    main()