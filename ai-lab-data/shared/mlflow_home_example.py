#!/usr/bin/env python3
"""
MLflow Home Directory Example - Fully Working
==============================================

This version uses your home directory for artifacts to avoid read-only issues.
Perfect for testing MLflow functionality!

Run this script to:
✅ Test MLflow connection
✅ Create experiment with home directory artifacts  
✅ Log parameters and metrics
✅ Save models in your home directory
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

print("🚀 MLflow Home Directory Example")
print("=" * 45)

# Configuration - use home directory for artifacts
MLFLOW_TRACKING_URI = "http://mlflow:5000"
EXPERIMENT_NAME = "home-directory-example"
HOME_ARTIFACTS_PATH = os.path.expanduser("~/mlflow_artifacts")

# Create artifacts directory in home
os.makedirs(HOME_ARTIFACTS_PATH, exist_ok=True)

try:
    # Step 1: Connect to MLflow
    print("1️⃣ Connecting to MLflow...")
    mlflow.set_tracking_uri(MLFLOW_TRACKING_URI)
    print(f"   ✅ Connected to: {MLFLOW_TRACKING_URI}")
    
    # Step 2: Create experiment with home directory artifacts
    print("\n2️⃣ Creating experiment with home directory artifacts...")
    try:
        experiment_id = mlflow.create_experiment(
            name=EXPERIMENT_NAME,
            artifact_location=f"file://{HOME_ARTIFACTS_PATH}"
        )
        print(f"   ✅ Created experiment: {EXPERIMENT_NAME}")
    except mlflow.exceptions.MlflowException:
        # Experiment already exists
        experiment = mlflow.get_experiment_by_name(EXPERIMENT_NAME)
        experiment_id = experiment.experiment_id
        print(f"   ✅ Using existing experiment: {EXPERIMENT_NAME}")
    
    mlflow.set_experiment(EXPERIMENT_NAME)
    print(f"   📁 Artifacts will be stored in: {HOME_ARTIFACTS_PATH}")
    
    # Step 3: Generate simple dataset
    print("\n3️⃣ Generating sample data...")
    X, y = make_classification(n_samples=800, n_features=8, n_classes=2, random_state=42)
    X_train, X_test, y_train, y_test = train_test_split(X, y, test_size=0.25, random_state=42)
    print(f"   📊 Dataset: {len(X)} samples, {X.shape[1]} features")
    print(f"   🔀 Train/Test split: {len(X_train)}/{len(X_test)}")
    
    # Step 4: Train model with MLflow tracking
    print("\n4️⃣ Training model with MLflow tracking...")
    
    with mlflow.start_run(run_name="Home-Directory-Run"):
        # Set some tags
        mlflow.set_tag("version", "1.0")
        mlflow.set_tag("environment", "home-directory")
        mlflow.set_tag("author", "jovyan-user")
        mlflow.set_tag("location", "jupyter-environment")
        
        # Log parameters
        n_estimators = 30
        max_depth = 4
        mlflow.log_param("n_estimators", n_estimators)
        mlflow.log_param("max_depth", max_depth)
        mlflow.log_param("test_size", 0.25)
        mlflow.log_param("dataset_size", len(X))
        mlflow.log_param("artifact_location", "home_directory")
        
        # Train model
        print("   🤖 Training Random Forest...")
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
        
        # Additional metrics
        from sklearn.metrics import precision_score, recall_score, f1_score
        precision = precision_score(y_test, y_pred)
        recall = recall_score(y_test, y_pred)
        f1 = f1_score(y_test, y_pred)
        
        mlflow.log_metric("precision", precision)
        mlflow.log_metric("recall", recall)
        mlflow.log_metric("f1_score", f1)
        
        # Create feature importance plot
        feature_importance = model.feature_importances_
        plt.figure(figsize=(10, 6))
        plt.bar(range(len(feature_importance)), feature_importance, 
                color='skyblue', alpha=0.8)
        plt.title('Feature Importance - Random Forest Model')
        plt.xlabel('Feature Index')
        plt.ylabel('Importance')
        plt.grid(True, alpha=0.3)
        plt.tight_layout()
        
        # Save plot to home directory first, then log as artifact
        timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
        plot_path = f"{HOME_ARTIFACTS_PATH}/feature_importance_{timestamp}.png"
        plt.savefig(plot_path, dpi=150, bbox_inches='tight')
        mlflow.log_artifact(plot_path, "plots")
        plt.close()
        
        # Create a simple metrics summary plot
        plt.figure(figsize=(8, 5))
        metrics = ['Accuracy', 'Precision', 'Recall', 'F1-Score']
        values = [accuracy, precision, recall, f1]
        bars = plt.bar(metrics, values, color=['#ff9999', '#66b3ff', '#99ff99', '#ffcc99'])
        plt.title('Model Performance Metrics')
        plt.ylabel('Score')
        plt.ylim(0, 1)
        
        # Add value labels on bars
        for bar, value in zip(bars, values):
            plt.text(bar.get_x() + bar.get_width()/2, bar.get_height() + 0.01, 
                    f'{value:.3f}', ha='center', va='bottom')
        
        plt.tight_layout()
        metrics_plot_path = f"{HOME_ARTIFACTS_PATH}/metrics_summary_{timestamp}.png"
        plt.savefig(metrics_plot_path, dpi=150, bbox_inches='tight')
        mlflow.log_artifact(metrics_plot_path, "plots")
        plt.close()
        
        # Log model
        print("   💾 Saving model...")
        mlflow.sklearn.log_model(model, "random_forest_model")
        
        # Create model info file
        model_info = {
            "model_type": "RandomForestClassifier",
            "n_estimators": n_estimators,
            "max_depth": max_depth,
            "features": X.shape[1],
            "training_samples": len(X_train),
            "test_samples": len(X_test),
            "accuracy": accuracy,
            "precision": precision,
            "recall": recall,
            "f1_score": f1,
            "timestamp": datetime.now().isoformat()
        }
        
        import json
        model_info_path = f"{HOME_ARTIFACTS_PATH}/model_info_{timestamp}.json"
        with open(model_info_path, 'w') as f:
            json.dump(model_info, f, indent=2)
        mlflow.log_artifact(model_info_path, "model_info")
        
        # Log current timestamp
        mlflow.log_param("timestamp", datetime.now().strftime("%Y-%m-%d %H:%M:%S"))
        
        run_id = mlflow.active_run().info.run_id
        
        print(f"   ✅ Model trained successfully!")
        print(f"   🎯 Results:")
        print(f"      Accuracy: {accuracy:.4f}")
        print(f"      Precision: {precision:.4f}")
        print(f"      Recall: {recall:.4f}")
        print(f"      F1-Score: {f1:.4f}")
        print(f"   🆔 Run ID: {run_id[:8]}...")
    
    # Step 5: Display results
    print(f"\n5️⃣ Results Summary:")
    print(f"   🔗 MLflow UI: {MLFLOW_TRACKING_URI}")
    print(f"   🧪 Experiment: {EXPERIMENT_NAME}")
    print(f"   📊 Model Performance: {accuracy:.4f} accuracy")
    print(f"   📁 Artifacts saved to: {HOME_ARTIFACTS_PATH}")
    
    # List the artifacts created
    if os.path.exists(HOME_ARTIFACTS_PATH):
        artifacts = [f for f in os.listdir(HOME_ARTIFACTS_PATH) if not f.startswith('.')]
        if artifacts:
            print(f"   📋 Artifacts created: {len(artifacts)} files")
            for artifact in sorted(artifacts)[-3:]:  # Show last 3 files
                print(f"      - {artifact}")
    
    print(f"\n🎉 Success! MLflow working perfectly with home directory storage!")
    print(f"\n📝 Next steps:")
    print(f"   1. Open MLflow UI: {MLFLOW_TRACKING_URI}")
    print(f"   2. Look for experiment: {EXPERIMENT_NAME}")
    print(f"   3. Explore your run and download artifacts")
    print(f"   4. Check artifacts locally: ls {HOME_ARTIFACTS_PATH}")

except Exception as e:
    print(f"\n❌ Error: {e}")
    print(f"\n🔧 Troubleshooting:")
    print(f"   1. Check MLflow server: {MLFLOW_TRACKING_URI}")
    print(f"   2. Verify home directory access: {HOME_ARTIFACTS_PATH}")
    print(f"   3. Ensure packages are installed: pip list | grep mlflow")
    
    # Specific error guidance
    if "Connection" in str(e):
        print(f"   💡 MLflow server might not be running")
    elif "Permission" in str(e) or "Read-only" in str(e):
        print(f"   💡 Try from your home directory: cd ~ && python /shared/mlflow_home_example.py")
    else:
        print(f"   💡 Detailed error: {e}")

print(f"\n📍 Current directory: {os.getcwd()}")
print(f"📍 Home artifacts path: {HOME_ARTIFACTS_PATH}")
print(f"📍 Home directory: {os.path.expanduser('~')}") 