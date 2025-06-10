#!/usr/bin/env python3
"""
MLflow Working Example - No Permission Issues
=============================================

This version uses local artifact storage to avoid permission problems.
Perfect for testing MLflow functionality!

Run this script to:
✅ Test MLflow connection
✅ Create experiment with local artifacts  
✅ Log parameters and metrics
✅ Save models locally
"""

import mlflow
import mlflow.sklearn
import numpy as np
from sklearn.datasets import make_classification
from sklearn.ensemble import RandomForestClassifier
from sklearn.model_selection import train_test_split
from sklearn.metrics import accuracy_score
import matplotlib.pyplot as plt
from datetime import datetime
import os

print("🚀 MLflow Working Example (Local Artifacts)")
print("=" * 50)

# Configuration - use local artifacts to avoid permission issues
MLFLOW_TRACKING_URI = "http://mlflow:5000"
EXPERIMENT_NAME = "local-artifacts-example"
LOCAL_ARTIFACTS_PATH = f"{os.getcwd()}/mlflow_artifacts"

# Create local artifacts directory
os.makedirs(LOCAL_ARTIFACTS_PATH, exist_ok=True)

try:
    # Step 1: Connect to MLflow
    print("1️⃣ Connecting to MLflow...")
    mlflow.set_tracking_uri(MLFLOW_TRACKING_URI)
    print(f"   ✅ Connected to: {MLFLOW_TRACKING_URI}")
    
    # Step 2: Create experiment with local artifacts
    print("\n2️⃣ Creating experiment with local artifacts...")
    try:
        experiment_id = mlflow.create_experiment(
            name=EXPERIMENT_NAME,
            artifact_location=f"file://{LOCAL_ARTIFACTS_PATH}"
        )
        print(f"   ✅ Created experiment: {EXPERIMENT_NAME}")
    except mlflow.exceptions.MlflowException:
        # Experiment already exists
        experiment = mlflow.get_experiment_by_name(EXPERIMENT_NAME)
        experiment_id = experiment.experiment_id
        print(f"   ✅ Using existing experiment: {EXPERIMENT_NAME}")
    
    mlflow.set_experiment(EXPERIMENT_NAME)
    print(f"   📁 Artifacts will be stored in: {LOCAL_ARTIFACTS_PATH}")
    
    # Step 3: Generate simple dataset
    print("\n3️⃣ Generating sample data...")
    X, y = make_classification(n_samples=1000, n_features=10, n_classes=2, random_state=42)
    X_train, X_test, y_train, y_test = train_test_split(X, y, test_size=0.3, random_state=42)
    print(f"   📊 Dataset: {len(X)} samples, {X.shape[1]} features")
    
    # Step 4: Train model with MLflow tracking
    print("\n4️⃣ Training model with MLflow tracking...")
    
    with mlflow.start_run(run_name="Local-Artifacts-Run"):
        # Set some tags
        mlflow.set_tag("version", "1.0")
        mlflow.set_tag("environment", "local-artifacts")
        mlflow.set_tag("author", "ai-lab-user")
        
        # Log parameters
        n_estimators = 50
        max_depth = 5
        mlflow.log_param("n_estimators", n_estimators)
        mlflow.log_param("max_depth", max_depth)
        mlflow.log_param("test_size", 0.3)
        mlflow.log_param("dataset_size", len(X))
        mlflow.log_param("artifact_location", "local")
        
        # Train model
        model = RandomForestClassifier(
            n_estimators=n_estimators, 
            max_depth=max_depth, 
            random_state=42
        )
        model.fit(X_train, y_train)
        
        # Make predictions and calculate metrics
        y_pred = model.predict(X_test)
        accuracy = accuracy_score(y_test, y_pred)
        
        # Log metrics
        mlflow.log_metric("accuracy", accuracy)
        mlflow.log_metric("train_samples", len(X_train))
        mlflow.log_metric("test_samples", len(X_test))
        
        # Create a simple plot
        feature_importance = model.feature_importances_
        plt.figure(figsize=(8, 4))
        plt.bar(range(len(feature_importance)), feature_importance)
        plt.title('Feature Importance')
        plt.xlabel('Feature Index')
        plt.ylabel('Importance')
        plt.tight_layout()
        
        # Save plot locally first, then log as artifact
        plot_path = f"{LOCAL_ARTIFACTS_PATH}/feature_importance_{datetime.now().strftime('%Y%m%d_%H%M%S')}.png"
        plt.savefig(plot_path)
        mlflow.log_artifact(plot_path, "plots")
        plt.close()
        
        # Log model
        mlflow.sklearn.log_model(model, "random_forest_model")
        
        # Log current timestamp
        mlflow.log_param("timestamp", datetime.now().strftime("%Y-%m-%d %H:%M:%S"))
        
        run_id = mlflow.active_run().info.run_id
        
        print(f"   ✅ Model trained successfully!")
        print(f"   🎯 Accuracy: {accuracy:.4f}")
        print(f"   🆔 Run ID: {run_id[:8]}...")
        print(f"   📁 Artifacts saved to: {LOCAL_ARTIFACTS_PATH}")
    
    # Step 5: Display results
    print(f"\n5️⃣ Results Summary:")
    print(f"   🔗 MLflow UI: {MLFLOW_TRACKING_URI}")
    print(f"   🧪 Experiment: {EXPERIMENT_NAME}")
    print(f"   📊 Accuracy: {accuracy:.4f}")
    print(f"   📁 Local artifacts: {LOCAL_ARTIFACTS_PATH}")
    
    # List the artifacts created
    if os.path.exists(LOCAL_ARTIFACTS_PATH):
        artifacts = os.listdir(LOCAL_ARTIFACTS_PATH)
        if artifacts:
            print(f"   📋 Artifacts created: {len(artifacts)} files")
            for artifact in artifacts[:5]:  # Show first 5
                print(f"      - {artifact}")
    
    print(f"\n🎉 Success! MLflow working with local artifacts!")
    print(f"📝 Next steps:")
    print(f"   1. Open the MLflow UI: {MLFLOW_TRACKING_URI}")
    print(f"   2. Look for experiment: {EXPERIMENT_NAME}")
    print(f"   3. Check local artifacts in: {LOCAL_ARTIFACTS_PATH}")
    print(f"   4. Try the other examples once this works!")

except Exception as e:
    print(f"\n❌ Error: {e}")
    print(f"\n🔧 Troubleshooting:")
    print(f"   1. Check if MLflow server is running: {MLFLOW_TRACKING_URI}")
    print(f"   2. Verify you have write access to current directory")
    print(f"   3. Ensure all required packages are installed")
    
    # Try to provide more specific error information
    if "Connection" in str(e):
        print(f"   💡 Connection issue: MLflow server might not be running")
    elif "Permission" in str(e):
        print(f"   💡 Permission issue: Try running from your home directory")
    else:
        print(f"   💡 Other issue: {e}")

print(f"\n📍 Current working directory: {os.getcwd()}")
print(f"📍 Local artifacts path: {LOCAL_ARTIFACTS_PATH}") 