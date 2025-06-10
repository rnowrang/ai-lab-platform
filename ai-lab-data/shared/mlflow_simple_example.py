#!/usr/bin/env python3
"""
Simple MLflow Example - Quick Start Guide
==========================================

A minimal example to test your MLflow setup and log your first experiment.
Perfect for getting started quickly!

Run this script to:
✅ Test MLflow connection
✅ Create your first experiment  
✅ Log parameters and metrics
✅ Save a simple model
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

print("🚀 Simple MLflow Example")
print("=" * 40)

# Configuration
MLFLOW_TRACKING_URI = "http://mlflow:5000"
EXPERIMENT_NAME = "quick-start-example"

try:
    # Step 1: Connect to MLflow
    print("1️⃣ Connecting to MLflow...")
    mlflow.set_tracking_uri(MLFLOW_TRACKING_URI)
    print(f"   ✅ Connected to: {MLFLOW_TRACKING_URI}")
    
    # Step 2: Create experiment
    print("\n2️⃣ Creating experiment...")
    try:
        experiment_id = mlflow.create_experiment(EXPERIMENT_NAME)
        print(f"   ✅ Created experiment: {EXPERIMENT_NAME}")
    except mlflow.exceptions.MlflowException:
        # Experiment already exists
        experiment = mlflow.get_experiment_by_name(EXPERIMENT_NAME)
        experiment_id = experiment.experiment_id
        print(f"   ✅ Using existing experiment: {EXPERIMENT_NAME}")
    
    mlflow.set_experiment(EXPERIMENT_NAME)
    
    # Step 3: Generate simple dataset
    print("\n3️⃣ Generating sample data...")
    X, y = make_classification(n_samples=1000, n_features=10, n_classes=2, random_state=42)
    X_train, X_test, y_train, y_test = train_test_split(X, y, test_size=0.3, random_state=42)
    print(f"   📊 Dataset: {len(X)} samples, {X.shape[1]} features")
    
    # Step 4: Train model with MLflow tracking
    print("\n4️⃣ Training model with MLflow tracking...")
    
    with mlflow.start_run(run_name="Quick-Start-Run"):
        # Set some tags
        mlflow.set_tag("version", "1.0")
        mlflow.set_tag("environment", "shared-folder")
        mlflow.set_tag("author", "ai-lab-user")
        
        # Log parameters
        n_estimators = 50
        max_depth = 5
        mlflow.log_param("n_estimators", n_estimators)
        mlflow.log_param("max_depth", max_depth)
        mlflow.log_param("test_size", 0.3)
        mlflow.log_param("dataset_size", len(X))
        
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
        
        # Save plot as artifact
        plot_path = "/tmp/feature_importance.png"
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
    
    # Step 5: Display results
    print(f"\n5️⃣ Results Summary:")
    print(f"   🔗 MLflow UI: {MLFLOW_TRACKING_URI}")
    print(f"   🧪 Experiment: {EXPERIMENT_NAME}")
    print(f"   📊 Accuracy: {accuracy:.4f}")
    print(f"   📁 Artifacts: Feature importance plot, trained model")
    
    print(f"\n🎉 Success! Your MLflow setup is working correctly!")
    print(f"📝 Next steps:")
    print(f"   1. Open the MLflow UI in your browser")
    print(f"   2. Explore the experiment and run details")
    print(f"   3. Try the complete example: mlflow_complete_example.py")
    print(f"   4. Create your own experiments!")

except Exception as e:
    print(f"\n❌ Error: {e}")
    print(f"\n🔧 Troubleshooting:")
    print(f"   1. Check if MLflow server is running")
    print(f"   2. Verify the tracking URI: {MLFLOW_TRACKING_URI}")
    print(f"   3. Ensure you have all required packages installed")
    print(f"   4. Check network connectivity to MLflow server")
    
    # Try to provide more specific error information
    if "Connection" in str(e):
        print(f"   💡 Connection issue: MLflow server might not be running")
    elif "Permission" in str(e):
        print(f"   💡 Permission issue: Check file system permissions")
    else:
        print(f"   �� Other issue: {e}") 