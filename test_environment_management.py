import requests
import time
import json
from datetime import datetime

BASE_URL = "http://localhost:5555"

def print_test_result(test_name, success, message=""):
    """Print test result in a formatted way"""
    status = "✅ PASS" if success else "❌ FAIL"
    print(f"{status} - {test_name}")
    if message:
        print(f"   Message: {message}")
    print()

def test_health_check():
    """Test the basic health check endpoint"""
    try:
        response = requests.get(f"{BASE_URL}/api/health")
        success = response.status_code == 200
        print_test_result("Health Check", success, response.json())
        return success
    except Exception as e:
        print_test_result("Health Check", False, str(e))
        return False

def test_environment_templates():
    """Test environment templates listing"""
    try:
        response = requests.get(f"{BASE_URL}/api/environments/templates")
        success = response.status_code == 200
        templates = response.json().get("templates", {})
        print_test_result("Environment Templates", success, f"Found {len(templates)} templates")
        return success
    except Exception as e:
        print_test_result("Environment Templates", False, str(e))
        return False

def test_create_environment():
    """Test environment creation"""
    try:
        data = {
            "template": "pytorch-basic",
            "user_id": "test_user",
            "quota": "default"
        }
        response = requests.post(f"{BASE_URL}/api/environments/create-from-template", json=data)
        success = response.status_code == 200
        if success:
            container_id = response.json().get("container_id")
            print_test_result("Create Environment", success, f"Created container: {container_id}")
            return container_id
        else:
            print_test_result("Create Environment", False, response.json().get("error"))
            return None
    except Exception as e:
        print_test_result("Create Environment", False, str(e))
        return None

def test_environment_health(container_id):
    """Test environment health monitoring"""
    try:
        response = requests.get(f"{BASE_URL}/api/environments/{container_id}/health")
        success = response.status_code == 200
        health_data = response.json().get("health", {})
        print_test_result("Environment Health", success, json.dumps(health_data, indent=2))
        return success
    except Exception as e:
        print_test_result("Environment Health", False, str(e))
        return False

def test_user_resources():
    """Test user resource tracking"""
    try:
        response = requests.get(f"{BASE_URL}/api/users/test_user/resources")
        success = response.status_code == 200
        resource_data = response.json().get("resource_usage", {})
        print_test_result("User Resources", success, json.dumps(resource_data, indent=2))
        return success
    except Exception as e:
        print_test_result("User Resources", False, str(e))
        return False

def test_environment_recovery(container_id):
    """Test environment recovery"""
    try:
        response = requests.post(f"{BASE_URL}/api/environments/{container_id}/recover")
        success = response.status_code == 200
        print_test_result("Environment Recovery", success, response.json().get("message"))
        return success
    except Exception as e:
        print_test_result("Environment Recovery", False, str(e))
        return False

def test_stop_environment(container_id):
    """Test stopping an environment"""
    try:
        response = requests.post(f"{BASE_URL}/api/environments/{container_id}/stop")
        success = response.status_code == 200
        print_test_result("Stop Environment", success, response.json().get("message"))
        return success
    except Exception as e:
        print_test_result("Stop Environment", False, str(e))
        return False

def run_all_tests():
    """Run all tests in sequence"""
    print("🚀 Starting Environment Management Tests")
    print("=" * 50)
    
    # Basic health check
    if not test_health_check():
        print("❌ Basic health check failed, stopping tests")
        return
    
    # Test templates
    if not test_environment_templates():
        print("❌ Template listing failed, stopping tests")
        return
    
    # Create environment
    container_id = test_create_environment()
    if not container_id:
        print("❌ Environment creation failed, stopping tests")
        return
    
    # Wait for environment to start
    print("⏳ Waiting for environment to start...")
    time.sleep(10)
    
    # Test health monitoring
    test_environment_health(container_id)
    
    # Test resource tracking
    test_user_resources()
    
    # Test recovery
    test_environment_recovery(container_id)
    
    # Wait before stopping
    print("⏳ Waiting before stopping environment...")
    time.sleep(5)
    
    # Stop environment
    test_stop_environment(container_id)
    
    print("=" * 50)
    print("✨ Test suite completed")

if __name__ == "__main__":
    run_all_tests() 