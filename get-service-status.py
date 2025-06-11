#!/usr/bin/env python3

import subprocess
import json
import sys
import requests
from datetime import datetime

def run_command(cmd):
    """Run a shell command and return output"""
    try:
        result = subprocess.run(cmd, shell=True, capture_output=True, text=True)
        return result.stdout.strip(), result.returncode == 0
    except Exception as e:
        return str(e), False

def get_docker_status(container_name):
    """Get Docker container status"""
    cmd = f"docker ps --filter 'name={container_name}' --format '{{{{.Status}}}}'"
    output, success = run_command(cmd)
    
    if not success or not output:
        return "stopped", "Container not running"
    
    status = output.lower()
    if "healthy" in status:
        return "healthy", "Container healthy"
    elif "unhealthy" in status:
        return "unhealthy", "Container unhealthy"
    elif "up" in status:
        uptime = output.replace("Up ", "").split(" (")[0]
        return "running", f"Up {uptime}"
    else:
        return "unknown", output

def test_service_connectivity(service_name):
    """Test service connectivity"""
    endpoints = {
        'backend': 'https://localhost/api/health',
        'nginx': 'https://localhost/',
        'mlflow': 'http://localhost:5000/health',
        'grafana': 'http://localhost:3000/api/health',
        'prometheus': 'http://localhost:9090/-/healthy'
    }
    
    if service_name not in endpoints:
        return None, "No test endpoint defined"
    
    try:
        response = requests.get(endpoints[service_name], timeout=5, verify=False)
        if response.status_code == 200:
            return True, "Responding normally"
        else:
            return False, f"HTTP {response.status_code}"
    except requests.exceptions.RequestException as e:
        return False, f"Connection failed: {str(e)[:50]}"

def test_database_connectivity():
    """Test PostgreSQL connectivity"""
    cmd = "docker exec ai-lab-postgres pg_isready -U postgres"
    output, success = run_command(cmd)
    
    if success and "accepting connections" in output:
        return True, "Database ready"
    else:
        return False, "Database not ready"

def test_redis_connectivity():
    """Test Redis connectivity"""
    cmd = "docker exec ai-lab-redis redis-cli ping"
    output, success = run_command(cmd)
    
    if success and "PONG" in output:
        return True, "Redis responding"
    else:
        return False, "Redis not responding"

def get_service_status(service_name):
    """Get comprehensive service status"""
    container_name = f"ai-lab-{service_name}"
    
    # Get basic Docker status
    docker_status, docker_details = get_docker_status(container_name)
    
    # Additional connectivity tests
    connectivity_status = None
    connectivity_details = ""
    
    if service_name == "postgres":
        connectivity_status, connectivity_details = test_database_connectivity()
    elif service_name == "redis":
        connectivity_status, connectivity_details = test_redis_connectivity()
    elif service_name in ["backend", "nginx", "mlflow", "grafana", "prometheus"]:
        connectivity_status, connectivity_details = test_service_connectivity(service_name)
    
    # Determine overall status
    if docker_status == "healthy":
        status = "healthy"
        details = docker_details
    elif docker_status == "running":
        if connectivity_status is True:
            status = "healthy"
            details = connectivity_details
        elif connectivity_status is False:
            status = "unhealthy"
            details = connectivity_details
        else:
            status = "running"
            details = docker_details
    else:
        status = docker_status
        details = docker_details
    
    return {
        "service": service_name,
        "status": status,
        "details": details,
        "docker_status": docker_status,
        "connectivity": connectivity_status,
        "timestamp": datetime.now().isoformat()
    }

def get_all_services_status():
    """Get status for all services"""
    services = [
        "postgres", "redis", "backend", "mlflow", 
        "nginx", "grafana", "prometheus", "torchserve"
    ]
    
    results = {}
    for service in services:
        results[service] = get_service_status(service)
    
    # Calculate overall health
    total_services = len(services)
    healthy_services = sum(1 for s in results.values() if s["status"] in ["healthy", "running"])
    
    overall = {
        "timestamp": datetime.now().isoformat(),
        "total_services": total_services,
        "healthy_services": healthy_services,
        "health_percentage": round((healthy_services / total_services) * 100, 1),
        "overall_status": "healthy" if healthy_services == total_services else "degraded" if healthy_services > 0 else "down"
    }
    
    return {
        "overall": overall,
        "services": results
    }

def main():
    """Main function"""
    if len(sys.argv) > 1:
        service_name = sys.argv[1]
        if service_name == "all":
            result = get_all_services_status()
        else:
            result = get_service_status(service_name)
        print(json.dumps(result, indent=2))
    else:
        print("Usage: python3 get-service-status.py <service_name|all>")
        print("\nAvailable services:")
        print("  postgres, redis, backend, mlflow, nginx, grafana, prometheus, torchserve")
        print("  all (for all services)")

if __name__ == "__main__":
    main() 