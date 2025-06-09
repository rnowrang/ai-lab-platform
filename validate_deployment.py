#!/usr/bin/env python3
"""
AI Lab Platform - Deployment Validation Script
Tests all components to ensure the platform is working correctly.
"""

import requests
import time
import json
from datetime import datetime

# Service endpoints
SERVICES = {
    "Backend API": "http://localhost:5555/api/health",
    "MLflow": "http://localhost:5000/health", 
    "Grafana": "http://localhost:3000/api/health",
    "Prometheus": "http://localhost:9090/-/healthy"
}

def test_service(name, url, timeout=10):
    """Test if a service is accessible and responding"""
    try:
        response = requests.get(url, timeout=timeout)
        if response.status_code == 200:
            print(f"✅ {name}: HEALTHY")
            return True
        else:
            print(f"❌ {name}: UNHEALTHY (HTTP {response.status_code})")
            return False
    except requests.exceptions.RequestException as e:
        print(f"❌ {name}: UNREACHABLE ({str(e)})")
        return False

def test_backend_endpoints():
    """Test specific backend API endpoints"""
    base_url = "http://localhost:5555"
    endpoints = [
        "/api/health",
        "/api/environments/templates", 
        "/api/resources/usage"
    ]
    
    print(f"\n🔍 Testing Backend API Endpoints:")
    healthy_count = 0
    
    for endpoint in endpoints:
        url = f"{base_url}{endpoint}"
        try:
            response = requests.get(url, timeout=5)
            if response.status_code == 200:
                print(f"✅ {endpoint}: OK")
                healthy_count += 1
            else:
                print(f"❌ {endpoint}: FAILED (HTTP {response.status_code})")
        except Exception as e:
            print(f"❌ {endpoint}: ERROR ({str(e)})")
    
    return healthy_count == len(endpoints)

def test_docker_connectivity():
    """Test if backend can connect to Docker"""
    try:
        response = requests.get("http://localhost:5555/api/environments", timeout=5)
        if response.status_code == 200:
            data = response.json()
            if "error" in data and "Docker not available" in data["error"]:
                print("❌ Docker Connectivity: FAILED - Backend cannot connect to Docker")
                return False
            else:
                print("✅ Docker Connectivity: OK")
                return True
        else:
            print(f"❌ Docker Connectivity: UNKNOWN (HTTP {response.status_code})")
            return False
    except Exception as e:
        print(f"❌ Docker Connectivity: ERROR ({str(e)})")
        return False

def main():
    """Run all validation tests"""
    print("🚀 AI Lab Platform - Deployment Validation")
    print("=" * 50)
    
    # Test core services
    print("\n🔍 Testing Core Services:")
    service_results = {}
    for name, url in SERVICES.items():
        service_results[name] = test_service(name, url)
    
    # Test backend endpoints
    backend_healthy = test_backend_endpoints()
    
    # Test Docker connectivity
    print(f"\n🐳 Testing Docker Integration:")
    docker_healthy = test_docker_connectivity()
    
    # Summary
    print(f"\n📊 Validation Summary:")
    print(f"=" * 30)
    
    healthy_services = sum(service_results.values())
    total_services = len(service_results)
    
    print(f"Core Services: {healthy_services}/{total_services}")
    print(f"Backend API: {'✅ HEALTHY' if backend_healthy else '❌ UNHEALTHY'}")
    print(f"Docker Integration: {'✅ HEALTHY' if docker_healthy else '❌ UNHEALTHY'}")
    
    overall_health = (
        healthy_services == total_services and 
        backend_healthy and 
        docker_healthy
    )
    
    if overall_health:
        print(f"\n🎉 Platform Status: FULLY OPERATIONAL")
        print(f"🌐 Access the platform at: http://localhost:5555")
        return 0
    else:
        print(f"\n⚠️ Platform Status: PARTIALLY OPERATIONAL")
        print(f"📋 Some services may not be working correctly.")
        return 1

if __name__ == "__main__":
    exit(main()) 