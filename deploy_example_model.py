#!/usr/bin/env python3
"""
Stage 2 Enhancement: Example Model Deployment
Demonstrates automated model deployment to TorchServe
"""

import torch
import torch.nn as nn
import torchvision.models as models
import requests
import json
import os
import tempfile
import zipfile
from pathlib import Path

class SimpleClassifier(nn.Module):
    """Simple image classifier for demonstration"""
    def __init__(self, num_classes=10):
        super(SimpleClassifier, self).__init__()
        self.backbone = models.resnet18(pretrained=True)
        self.backbone.fc = nn.Linear(self.backbone.fc.in_features, num_classes)
    
    def forward(self, x):
        return self.backbone(x)

def create_model_archive():
    """Create a TorchServe model archive (.mar file)"""
    print("🔧 Creating example model...")
    
    # Create model
    model = SimpleClassifier(num_classes=10)
    model.eval()
    
    # Create temporary directory
    with tempfile.TemporaryDirectory() as temp_dir:
        temp_path = Path(temp_dir)
        
        # Save model
        model_path = temp_path / "model.pt"
        torch.save(model.state_dict(), model_path)
        
        # Create model handler
        handler_code = '''
import torch
import torch.nn as nn
import torchvision.models as models
from torchvision import transforms
from ts.torch_handler.image_classifier import ImageClassifier
import logging

logger = logging.getLogger(__name__)

class SimpleClassifier(nn.Module):
    def __init__(self, num_classes=10):
        super(SimpleClassifier, self).__init__()
        self.backbone = models.resnet18(pretrained=True)
        self.backbone.fc = nn.Linear(self.backbone.fc.in_features, num_classes)
    
    def forward(self, x):
        return self.backbone(x)

class ModelHandler(ImageClassifier):
    def __init__(self):
        super(ModelHandler, self).__init__()
        
    def initialize(self, context):
        """Initialize model"""
        self.manifest = context.manifest
        properties = context.system_properties
        model_dir = properties.get("model_dir")
        
        # Load model
        self.device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
        model_path = os.path.join(model_dir, "model.pt")
        
        self.model = SimpleClassifier(num_classes=10)
        self.model.load_state_dict(torch.load(model_path, map_location=self.device))
        self.model.to(self.device)
        self.model.eval()
        
        # Image preprocessing
        self.transform = transforms.Compose([
            transforms.Resize((224, 224)),
            transforms.ToTensor(),
            transforms.Normalize(mean=[0.485, 0.456, 0.406], 
                               std=[0.229, 0.224, 0.225])
        ])
        
        self.initialized = True
        logger.info("Model initialized successfully")
    
    def preprocess(self, data):
        """Preprocess input data"""
        images = []
        for row in data:
            image = row.get("data") or row.get("body")
            if isinstance(image, str):
                # Handle base64 encoded images
                import base64
                from PIL import Image
                import io
                image_data = base64.b64decode(image)
                image = Image.open(io.BytesIO(image_data)).convert('RGB')
            
            # Apply transforms
            image_tensor = self.transform(image).unsqueeze(0)
            images.append(image_tensor)
        
        return torch.cat(images).to(self.device)
    
    def inference(self, data):
        """Run inference"""
        with torch.no_grad():
            outputs = self.model(data)
            predictions = torch.nn.functional.softmax(outputs, dim=1)
        return predictions
    
    def postprocess(self, data):
        """Postprocess outputs"""
        results = []
        for prediction in data:
            pred_class = torch.argmax(prediction).item()
            confidence = prediction[pred_class].item()
            results.append({
                "predicted_class": pred_class,
                "confidence": confidence,
                "all_predictions": prediction.tolist()
            })
        return results
'''
        
        handler_path = temp_path / "model_handler.py"
        with open(handler_path, 'w') as f:
            f.write(handler_code)
        
        # Create model archive using torch-model-archiver
        archive_path = Path("./model_store/simple_classifier.mar")
        archive_path.parent.mkdir(exist_ok=True)
        
        # Create archive manually since torch-model-archiver might not be available
        with zipfile.ZipFile(archive_path, 'w', zipfile.ZIP_DEFLATED) as zipf:
            zipf.write(model_path, "model.pt")
            zipf.write(handler_path, "model_handler.py")
            
            # Add manifest
            manifest = {
                "runtime": "python",
                "model": {
                    "modelName": "simple_classifier",
                    "serializedFile": "model.pt",
                    "handler": "model_handler.py",
                    "modelVersion": "1.0"
                }
            }
            
            manifest_str = json.dumps(manifest, indent=2)
            zipf.writestr("MANIFEST.json", manifest_str)
        
        print(f"✅ Model archive created: {archive_path}")
        return archive_path

def deploy_model_to_torchserve(archive_path, model_name="simple_classifier"):
    """Deploy model to TorchServe"""
    print(f"🚀 Deploying model '{model_name}' to TorchServe...")
    
    # TorchServe management API endpoints
    base_url = "http://localhost:8082"  # Management API port
    
    try:
        # Register model
        with open(archive_path, 'rb') as f:
            files = {'model_file': f}
            response = requests.post(
                f"{base_url}/models",
                files=files,
                params={
                    'model_name': model_name,
                    'initial_workers': 1,
                    'synchronous': True
                }
            )
        
        if response.status_code == 200:
            print(f"✅ Model '{model_name}' deployed successfully!")
            return True
        else:
            print(f"❌ Failed to deploy model: {response.status_code} - {response.text}")
            return False
            
    except Exception as e:
        print(f"❌ Error deploying model: {e}")
        return False

def test_model_inference(model_name="simple_classifier"):
    """Test model inference"""
    print(f"🧪 Testing inference for model '{model_name}'...")
    
    inference_url = f"http://localhost:8081/predictions/{model_name}"
    
    try:
        # Create a simple test image (random tensor as example)
        import torch
        import base64
        import io
        from PIL import Image
        import numpy as np
        
        # Create random RGB image
        random_image = np.random.randint(0, 255, (224, 224, 3), dtype=np.uint8)
        pil_image = Image.fromarray(random_image)
        
        # Convert to base64
        buffer = io.BytesIO()
        pil_image.save(buffer, format='PNG')
        image_base64 = base64.b64encode(buffer.getvalue()).decode()
        
        # Send inference request
        response = requests.post(
            inference_url,
            json={"data": image_base64},
            headers={"Content-Type": "application/json"}
        )
        
        if response.status_code == 200:
            result = response.json()
            print(f"✅ Inference successful!")
            print(f"   Predicted class: {result.get('predicted_class', 'N/A')}")
            print(f"   Confidence: {result.get('confidence', 'N/A'):.4f}")
            return True
        else:
            print(f"❌ Inference failed: {response.status_code} - {response.text}")
            return False
            
    except Exception as e:
        print(f"❌ Error during inference: {e}")
        return False

def list_deployed_models():
    """List all deployed models"""
    print("📋 Listing deployed models...")
    
    try:
        response = requests.get("http://localhost:8082/models")
        if response.status_code == 200:
            models = response.json()
            print("Deployed models:")
            for model in models.get('models', []):
                print(f"  - {model}")
            return models
        else:
            print(f"❌ Failed to list models: {response.status_code}")
            return None
    except Exception as e:
        print(f"❌ Error listing models: {e}")
        return None

def main():
    """Main deployment process"""
    print("🚀 Stage 2 ML Platform Enhancement: Model Deployment Demo")
    print("=" * 60)
    
    # Create model store directory
    os.makedirs("model_store", exist_ok=True)
    
    # Step 1: Create model archive
    archive_path = create_model_archive()
    
    # Step 2: Deploy to TorchServe
    if deploy_model_to_torchserve(archive_path):
        # Step 3: Test inference
        test_model_inference()
        
        # Step 4: List deployed models
        list_deployed_models()
        
        print("\n🎉 Stage 2 Enhancement Complete!")
        print("Your ML Platform now supports:")
        print("  ✅ Automated model deployment")
        print("  ✅ RESTful inference API")
        print("  ✅ Model versioning")
        print("  ✅ Scalable serving")
        print("\nAccess your models at: http://localhost:8081/predictions/MODEL_NAME")
    else:
        print("❌ Deployment failed. Check TorchServe logs.")

if __name__ == "__main__":
    main() 