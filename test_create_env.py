import requests
import json

# Test environment creation directly
data = {
    "template": "pytorch-basic",
    "user_id": "test_user",
    "quota": "default"
}

print("Testing environment creation...")
response = requests.post("http://localhost:5555/api/environments/create-from-template", json=data)

print(f"Status Code: {response.status_code}")
print(f"Response: {json.dumps(response.json(), indent=2)}")

if response.status_code == 200:
    container_id = response.json().get("container_id")
    print(f"\n✅ Environment created successfully!")
    print(f"Container ID: {container_id}")
    print(f"Access URL: {response.json().get('access_url')}")
else:
    print(f"\n❌ Environment creation failed!")
    print(f"Error: {response.json().get('error')}") 