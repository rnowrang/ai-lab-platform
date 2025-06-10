#!/usr/bin/env python3
"""
Complete MLflow Example for AI Lab Platform
============================================

This example demonstrates:
1. Experiment management
2. Parameter and metric logging
3. Model tracking and versioning
4. Artifact management
5. Model registry usage
6. Best practices for ML experiment tracking

Run this script to see a complete MLflow workflow in action!
"""

import mlflow
import mlflow.pytorch
import mlflow.sklearn
import torch
import torch.nn as nn
import torch.optim as optim
import numpy as np
import pandas as pd
from sklearn.datasets import make_classification
from sklearn.model_selection import train_test_split
from sklearn.ensemble import RandomForestClassifier
from sklearn.metrics import accuracy_score, precision_score, recall_score, f1_score
import matplotlib.pyplot as plt
import seaborn as sns
import os
import json
from datetime import datetime

# Configuration
MLFLOW_TRACKING_URI = "http://mlflow:5000"
EXPERIMENT_NAME = "shared-ml-experiments"
ARTIFACT_LOCATION = "file:///shared/mlflow-artifacts"

print("🚀 MLflow Complete Example for AI Lab Platform")
print("=" * 60)

# Step 1: Connect to MLflow
print("\n1️⃣ Connecting to MLflow...")
mlflow.set_tracking_uri(MLFLOW_TRACKING_URI)
print(f"   📡 Connected to: {MLFLOW_TRACKING_URI}")

# Step 2: Create or get experiment
print("\n2️⃣ Setting up experiment...")
try:
    experiment_id = mlflow.create_experiment(
        name=EXPERIMENT_NAME,
        artifact_location=ARTIFACT_LOCATION
    )
    print(f"   ✅ Created new experiment: {EXPERIMENT_NAME} (ID: {experiment_id})")
except mlflow.exceptions.MlflowException as e:
    if "already exists" in str(e):
        experiment = mlflow.get_experiment_by_name(EXPERIMENT_NAME)
        experiment_id = experiment.experiment_id
        print(f"   ✅ Using existing experiment: {EXPERIMENT_NAME} (ID: {experiment_id})")
    else:
        raise e

mlflow.set_experiment(EXPERIMENT_NAME)

# Step 3: Generate sample data
print("\n3️⃣ Generating sample dataset...")
X, y = make_classification(
    n_samples=2000, 
    n_features=20, 
    n_informative=15,
    n_redundant=5,
    n_classes=2, 
    random_state=42
)
X_train, X_test, y_train, y_test = train_test_split(X, y, test_size=0.2, random_state=42)
print(f"   📊 Dataset: {X.shape[0]} samples, {X.shape[1]} features")
print(f"   🔀 Train/Test split: {len(X_train)}/{len(X_test)}")

# ============================================================================
# PyTorch Neural Network Example
# ============================================================================

class SimpleNN(nn.Module):
    def __init__(self, input_size, hidden_size, output_size, dropout_rate=0.3):
        super(SimpleNN, self).__init__()
        self.fc1 = nn.Linear(input_size, hidden_size)
        self.fc2 = nn.Linear(hidden_size, hidden_size // 2)
        self.fc3 = nn.Linear(hidden_size // 2, output_size)
        self.relu = nn.ReLU()
        self.dropout = nn.Dropout(dropout_rate)
        self.sigmoid = nn.Sigmoid()
    
    def forward(self, x):
        x = self.relu(self.fc1(x))
        x = self.dropout(x)
        x = self.relu(self.fc2(x))
        x = self.dropout(x)
        x = self.sigmoid(self.fc3(x))
        return x

def train_pytorch_model():
    """Train PyTorch model with MLflow tracking"""
    print("\n4️⃣ Training PyTorch Neural Network...")
    
    # Model hyperparameters
    input_size = X_train.shape[1]
    hidden_size = 128
    output_size = 1
    learning_rate = 0.001
    epochs = 50
    batch_size = 64
    dropout_rate = 0.3
    
    # Convert to tensors
    X_train_tensor = torch.FloatTensor(X_train)
    y_train_tensor = torch.FloatTensor(y_train).unsqueeze(1)
    X_test_tensor = torch.FloatTensor(X_test)
    y_test_tensor = torch.FloatTensor(y_test).unsqueeze(1)
    
    with mlflow.start_run(run_name="PyTorch-Neural-Network"):
        # Log hyperparameters
        mlflow.log_param("model_type", "PyTorch Neural Network")
        mlflow.log_param("input_size", input_size)
        mlflow.log_param("hidden_size", hidden_size)
        mlflow.log_param("learning_rate", learning_rate)
        mlflow.log_param("epochs", epochs)
        mlflow.log_param("batch_size", batch_size)
        mlflow.log_param("dropout_rate", dropout_rate)
        mlflow.log_param("optimizer", "Adam")
        
        # Additional run information
        mlflow.set_tag("framework", "PyTorch")
        mlflow.set_tag("task", "Binary Classification")
        mlflow.set_tag("dataset_size", len(X_train))
        
        # Initialize model
        model = SimpleNN(input_size, hidden_size, output_size, dropout_rate)
        criterion = nn.BCELoss()
        optimizer = optim.Adam(model.parameters(), lr=learning_rate)
        
        # Training loop with detailed logging
        train_losses = []
        test_accuracies = []
        
        for epoch in range(epochs):
            model.train()
            
            # Mini-batch training
            epoch_loss = 0
            for i in range(0, len(X_train_tensor), batch_size):
                batch_X = X_train_tensor[i:i+batch_size]
                batch_y = y_train_tensor[i:i+batch_size]
                
                optimizer.zero_grad()
                outputs = model(batch_X)
                loss = criterion(outputs, batch_y)
                loss.backward()
                optimizer.step()
                epoch_loss += loss.item()
            
            avg_loss = epoch_loss / (len(X_train_tensor) // batch_size)
            train_losses.append(avg_loss)
            
            # Evaluation
            if epoch % 10 == 0:
                model.eval()
                with torch.no_grad():
                    test_outputs = model(X_test_tensor)
                    test_predictions = (test_outputs > 0.5).float()
                    test_accuracy = (test_predictions == y_test_tensor).float().mean().item()
                    test_accuracies.append(test_accuracy)
                    
                    print(f"   Epoch {epoch:3d}: Loss={avg_loss:.4f}, Test Acc={test_accuracy:.4f}")
                    
                    # Log metrics
                    mlflow.log_metric("train_loss", avg_loss, step=epoch)
                    mlflow.log_metric("test_accuracy", test_accuracy, step=epoch)
        
        # Final evaluation
        model.eval()
        with torch.no_grad():
            final_outputs = model(X_test_tensor)
            final_predictions = (final_outputs > 0.5).float().numpy()
            final_accuracy = accuracy_score(y_test, final_predictions)
            final_precision = precision_score(y_test, final_predictions)
            final_recall = recall_score(y_test, final_predictions)
            final_f1 = f1_score(y_test, final_predictions)
        
        # Log final metrics
        mlflow.log_metric("final_accuracy", final_accuracy)
        mlflow.log_metric("final_precision", final_precision)
        mlflow.log_metric("final_recall", final_recall)
        mlflow.log_metric("final_f1_score", final_f1)
        
        print(f"   🎯 Final Results:")
        print(f"      Accuracy: {final_accuracy:.4f}")
        print(f"      Precision: {final_precision:.4f}")
        print(f"      Recall: {final_recall:.4f}")
        print(f"      F1-Score: {final_f1:.4f}")
        
        # Create and log training curve plot
        plt.figure(figsize=(12, 4))
        
        plt.subplot(1, 2, 1)
        plt.plot(train_losses)
        plt.title('Training Loss')
        plt.xlabel('Epoch')
        plt.ylabel('Loss')
        plt.grid(True)
        
        plt.subplot(1, 2, 2)
        test_epochs = list(range(0, epochs, 10))
        plt.plot(test_epochs, test_accuracies)
        plt.title('Test Accuracy')
        plt.xlabel('Epoch')
        plt.ylabel('Accuracy')
        plt.grid(True)
        
        plt.tight_layout()
        plt.savefig('/tmp/pytorch_training_curves.png', dpi=150, bbox_inches='tight')
        mlflow.log_artifact('/tmp/pytorch_training_curves.png', "plots")
        plt.close()
        
        # Save and log model
        torch.save(model.state_dict(), '/tmp/pytorch_model.pth')
        mlflow.log_artifact('/tmp/pytorch_model.pth', "models")
        mlflow.pytorch.log_model(model, "pytorch_model")
        
        # Create model summary
        model_summary = {
            "model_type": "PyTorch Neural Network",
            "architecture": {
                "input_layer": input_size,
                "hidden_layer_1": hidden_size,
                "hidden_layer_2": hidden_size // 2,
                "output_layer": output_size,
                "dropout_rate": dropout_rate
            },
            "total_parameters": sum(p.numel() for p in model.parameters()),
            "trainable_parameters": sum(p.numel() for p in model.parameters() if p.requires_grad),
            "final_metrics": {
                "accuracy": final_accuracy,
                "precision": final_precision,
                "recall": final_recall,
                "f1_score": final_f1
            }
        }
        
        with open('/tmp/pytorch_model_summary.json', 'w') as f:
            json.dump(model_summary, f, indent=2)
        mlflow.log_artifact('/tmp/pytorch_model_summary.json', "model_info")
        
        print("   ✅ PyTorch model logged successfully")
        return mlflow.active_run().info.run_id

# ============================================================================
# Scikit-Learn Random Forest Example
# ============================================================================

def train_sklearn_model():
    """Train Scikit-Learn model with MLflow tracking"""
    print("\n5️⃣ Training Scikit-Learn Random Forest...")
    
    # Hyperparameters
    n_estimators = 100
    max_depth = 10
    min_samples_split = 5
    min_samples_leaf = 2
    random_state = 42
    
    with mlflow.start_run(run_name="RandomForest-Classifier"):
        # Log hyperparameters
        mlflow.log_param("model_type", "Random Forest")
        mlflow.log_param("n_estimators", n_estimators)
        mlflow.log_param("max_depth", max_depth)
        mlflow.log_param("min_samples_split", min_samples_split)
        mlflow.log_param("min_samples_leaf", min_samples_leaf)
        mlflow.log_param("random_state", random_state)
        
        # Tags
        mlflow.set_tag("framework", "Scikit-Learn")
        mlflow.set_tag("task", "Binary Classification")
        mlflow.set_tag("algorithm", "Ensemble Method")
        
        # Train model
        model = RandomForestClassifier(
            n_estimators=n_estimators,
            max_depth=max_depth,
            min_samples_split=min_samples_split,
            min_samples_leaf=min_samples_leaf,
            random_state=random_state
        )
        
        model.fit(X_train, y_train)
        
        # Predictions
        train_pred = model.predict(X_train)
        test_pred = model.predict(X_test)
        test_pred_proba = model.predict_proba(X_test)[:, 1]
        
        # Calculate metrics
        train_accuracy = accuracy_score(y_train, train_pred)
        test_accuracy = accuracy_score(y_test, test_pred)
        test_precision = precision_score(y_test, test_pred)
        test_recall = recall_score(y_test, test_pred)
        test_f1 = f1_score(y_test, test_pred)
        
        # Log metrics
        mlflow.log_metric("train_accuracy", train_accuracy)
        mlflow.log_metric("test_accuracy", test_accuracy)
        mlflow.log_metric("test_precision", test_precision)
        mlflow.log_metric("test_recall", test_recall)
        mlflow.log_metric("test_f1_score", test_f1)
        
        print(f"   🎯 Results:")
        print(f"      Train Accuracy: {train_accuracy:.4f}")
        print(f"      Test Accuracy: {test_accuracy:.4f}")
        print(f"      Precision: {test_precision:.4f}")
        print(f"      Recall: {test_recall:.4f}")
        print(f"      F1-Score: {test_f1:.4f}")
        
        # Feature importance analysis
        feature_importance = pd.DataFrame({
            'feature': [f'feature_{i}' for i in range(X_train.shape[1])],
            'importance': model.feature_importances_
        }).sort_values('importance', ascending=False)
        
        # Plot feature importance
        plt.figure(figsize=(10, 6))
        sns.barplot(data=feature_importance.head(10), x='importance', y='feature')
        plt.title('Top 10 Feature Importances')
        plt.xlabel('Importance')
        plt.tight_layout()
        plt.savefig('/tmp/feature_importance.png', dpi=150, bbox_inches='tight')
        mlflow.log_artifact('/tmp/feature_importance.png', "plots")
        plt.close()
        
        # Save feature importance data
        feature_importance.to_csv('/tmp/feature_importance.csv', index=False)
        mlflow.log_artifact('/tmp/feature_importance.csv', "data")
        
        # Log model
        mlflow.sklearn.log_model(model, "sklearn_model")
        
        # Create model metadata
        model_metadata = {
            "model_type": "Random Forest Classifier",
            "sklearn_version": mlflow.sklearn.__version__,
            "hyperparameters": {
                "n_estimators": n_estimators,
                "max_depth": max_depth,
                "min_samples_split": min_samples_split,
                "min_samples_leaf": min_samples_leaf
            },
            "feature_count": X_train.shape[1],
            "training_samples": len(X_train),
            "test_samples": len(X_test),
            "metrics": {
                "train_accuracy": train_accuracy,
                "test_accuracy": test_accuracy,
                "precision": test_precision,
                "recall": test_recall,
                "f1_score": test_f1
            },
            "top_features": feature_importance.head(5).to_dict('records')
        }
        
        with open('/tmp/sklearn_model_metadata.json', 'w') as f:
            json.dump(model_metadata, f, indent=2)
        mlflow.log_artifact('/tmp/sklearn_model_metadata.json', "model_info")
        
        print("   ✅ Scikit-Learn model logged successfully")
        return mlflow.active_run().info.run_id

# ============================================================================
# Model Comparison and Registry
# ============================================================================

def compare_models_and_register_best():
    """Compare models and register the best one"""
    print("\n6️⃣ Comparing models and updating model registry...")
    
    # Get all runs from current experiment
    experiment = mlflow.get_experiment_by_name(EXPERIMENT_NAME)
    runs = mlflow.search_runs(experiment_ids=[experiment.experiment_id])
    
    if len(runs) < 2:
        print("   ⚠️  Not enough runs to compare models")
        return
    
    # Find best model based on test accuracy
    best_run = runs.loc[runs['metrics.test_accuracy'].idxmax()]
    best_accuracy = best_run['metrics.test_accuracy']
    best_model_name = best_run['tags.mlflow.runName']
    best_run_id = best_run['run_id']
    
    print(f"   🏆 Best model: {best_model_name}")
    print(f"   📊 Best accuracy: {best_accuracy:.4f}")
    
    # Create comparison visualization
    plt.figure(figsize=(12, 8))
    
    # Accuracy comparison
    plt.subplot(2, 2, 1)
    model_names = runs['tags.mlflow.runName'].tolist()
    accuracies = runs['metrics.test_accuracy'].tolist()
    colors = ['gold' if acc == best_accuracy else 'lightblue' for acc in accuracies]
    plt.bar(model_names, accuracies, color=colors)
    plt.title('Model Accuracy Comparison')
    plt.ylabel('Test Accuracy')
    plt.xticks(rotation=45)
    
    # F1 Score comparison
    plt.subplot(2, 2, 2)
    f1_scores = runs['metrics.test_f1_score'].tolist() if 'metrics.test_f1_score' in runs.columns else []
    if f1_scores:
        plt.bar(model_names, f1_scores, color=colors)
        plt.title('Model F1-Score Comparison')
        plt.ylabel('F1-Score')
        plt.xticks(rotation=45)
    
    # Precision vs Recall
    plt.subplot(2, 2, 3)
    if 'metrics.test_precision' in runs.columns and 'metrics.test_recall' in runs.columns:
        precisions = runs['metrics.test_precision'].tolist()
        recalls = runs['metrics.test_recall'].tolist()
        plt.scatter(recalls, precisions, c=accuracies, cmap='viridis', s=100)
        plt.xlabel('Recall')
        plt.ylabel('Precision')
        plt.title('Precision vs Recall')
        plt.colorbar(label='Accuracy')
    
    # Model summary table
    plt.subplot(2, 2, 4)
    plt.axis('off')
    summary_data = []
    for _, run in runs.iterrows():
        summary_data.append([
            run['tags.mlflow.runName'][:15] + '...' if len(run['tags.mlflow.runName']) > 15 else run['tags.mlflow.runName'],
            f"{run['metrics.test_accuracy']:.3f}",
            f"{run.get('metrics.test_f1_score', 0):.3f}",
            '🏆' if run['run_id'] == best_run_id else ''
        ])
    
    table = plt.table(cellText=summary_data,
                      colLabels=['Model', 'Accuracy', 'F1-Score', 'Best'],
                      cellLoc='center',
                      loc='center')
    table.auto_set_font_size(False)
    table.set_fontsize(8)
    table.scale(1.2, 1.5)
    plt.title('Model Summary', y=0.8)
    
    plt.tight_layout()
    plt.savefig('/tmp/model_comparison.png', dpi=150, bbox_inches='tight')
    
    # Log comparison as artifact in a separate run
    with mlflow.start_run(run_name="Model-Comparison-Summary"):
        mlflow.log_artifact('/tmp/model_comparison.png', "analysis")
        
        # Log comparison metrics
        mlflow.log_metric("best_accuracy", best_accuracy)
        mlflow.log_metric("models_compared", len(runs))
        
        # Create detailed comparison report
        comparison_report = {
            "comparison_date": datetime.now().isoformat(),
            "models_compared": len(runs),
            "best_model": {
                "name": best_model_name,
                "run_id": best_run_id,
                "accuracy": best_accuracy
            },
            "all_models": []
        }
        
        for _, run in runs.iterrows():
            model_info = {
                "name": run['tags.mlflow.runName'],
                "run_id": run['run_id'],
                "accuracy": run['metrics.test_accuracy'],
                "framework": run.get('tags.framework', 'Unknown')
            }
            comparison_report["all_models"].append(model_info)
        
        with open('/tmp/model_comparison_report.json', 'w') as f:
            json.dump(comparison_report, f, indent=2)
        mlflow.log_artifact('/tmp/model_comparison_report.json', "reports")
        
        print("   ✅ Model comparison completed and logged")
    
    plt.close()

# ============================================================================
# Create Dataset Summary
# ============================================================================

def create_dataset_summary():
    """Create and log dataset analysis"""
    print("\n7️⃣ Creating dataset analysis...")
    
    with mlflow.start_run(run_name="Dataset-Analysis"):
        # Dataset statistics
        dataset_stats = {
            "total_samples": len(X),
            "features": X.shape[1],
            "classes": len(np.unique(y)),
            "class_distribution": {
                "class_0": int(np.sum(y == 0)),
                "class_1": int(np.sum(y == 1))
            },
            "train_test_split": {
                "train_samples": len(X_train),
                "test_samples": len(X_test),
                "split_ratio": len(X_test) / len(X)
            }
        }
        
        # Log dataset parameters
        mlflow.log_param("total_samples", dataset_stats["total_samples"])
        mlflow.log_param("n_features", dataset_stats["features"])
        mlflow.log_param("n_classes", dataset_stats["classes"])
        mlflow.log_param("train_samples", dataset_stats["train_test_split"]["train_samples"])
        mlflow.log_param("test_samples", dataset_stats["train_test_split"]["test_samples"])
        
        # Create dataset visualizations
        fig, axes = plt.subplots(2, 2, figsize=(15, 10))
        
        # Class distribution
        class_counts = [dataset_stats["class_distribution"]["class_0"], 
                       dataset_stats["class_distribution"]["class_1"]]
        axes[0, 0].pie(class_counts, labels=['Class 0', 'Class 1'], autopct='%1.1f%%')
        axes[0, 0].set_title('Class Distribution')
        
        # Feature correlation heatmap (sample of features)
        sample_features = min(10, X.shape[1])
        feature_corr = np.corrcoef(X[:, :sample_features].T)
        sns.heatmap(feature_corr, annot=True, cmap='coolwarm', center=0, ax=axes[0, 1])
        axes[0, 1].set_title(f'Feature Correlation (First {sample_features} features)')
        
        # Feature distribution
        axes[1, 0].hist(X.flatten(), bins=50, alpha=0.7, color='skyblue')
        axes[1, 0].set_title('Feature Value Distribution')
        axes[1, 0].set_xlabel('Feature Value')
        axes[1, 0].set_ylabel('Frequency')
        
        # Train/Test split visualization
        split_data = ['Train', 'Test']
        split_counts = [len(X_train), len(X_test)]
        axes[1, 1].bar(split_data, split_counts, color=['lightgreen', 'lightcoral'])
        axes[1, 1].set_title('Train/Test Split')
        axes[1, 1].set_ylabel('Sample Count')
        
        plt.tight_layout()
        plt.savefig('/tmp/dataset_analysis.png', dpi=150, bbox_inches='tight')
        mlflow.log_artifact('/tmp/dataset_analysis.png', "data_analysis")
        plt.close()
        
        # Save dataset statistics
        with open('/tmp/dataset_stats.json', 'w') as f:
            json.dump(dataset_stats, f, indent=2)
        mlflow.log_artifact('/tmp/dataset_stats.json', "data_analysis")
        
        # Create data sample
        sample_data = pd.DataFrame(
            X[:100], 
            columns=[f'feature_{i}' for i in range(X.shape[1])]
        )
        sample_data['target'] = y[:100]
        sample_data.to_csv('/tmp/data_sample.csv', index=False)
        mlflow.log_artifact('/tmp/data_sample.csv', "data_analysis")
        
        print("   ✅ Dataset analysis completed and logged")

# ============================================================================
# Main Execution
# ============================================================================

def main():
    """Run the complete MLflow example"""
    try:
        # Execute all steps
        pytorch_run_id = train_pytorch_model()
        sklearn_run_id = train_sklearn_model()
        create_dataset_summary()
        compare_models_and_register_best()
        
        print("\n🎉 MLflow Complete Example Finished!")
        print("=" * 60)
        print(f"🔗 View results at: {MLFLOW_TRACKING_URI}")
        print(f"📁 Artifacts stored in: {ARTIFACT_LOCATION}")
        print(f"🧪 Experiment: {EXPERIMENT_NAME}")
        print("\n✅ All experiments, models, and artifacts have been logged!")
        print("\n📝 What you can do next:")
        print("   1. Open MLflow UI to explore experiments")
        print("   2. Compare model performance")
        print("   3. Download artifacts and models")
        print("   4. Use this as a template for your own experiments")
        
        # Summary of what was created
        experiment = mlflow.get_experiment_by_name(EXPERIMENT_NAME)
        runs = mlflow.search_runs(experiment_ids=[experiment.experiment_id])
        
        print(f"\n📊 Summary:")
        print(f"   Experiment ID: {experiment.experiment_id}")
        print(f"   Total Runs: {len(runs)}")
        print(f"   Models Trained: PyTorch NN, Random Forest")
        print(f"   Artifacts: Plots, Model Files, Analysis Reports")
        
    except Exception as e:
        print(f"\n❌ Error occurred: {e}")
        print("   Check MLflow connection and try again")
        raise

if __name__ == "__main__":
    main() 