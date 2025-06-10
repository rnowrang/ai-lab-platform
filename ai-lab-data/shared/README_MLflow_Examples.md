# MLflow Examples for AI Lab Platform

Welcome to the MLflow examples! These files demonstrate how to use MLflow for experiment tracking, model management, and artifact storage in your AI Lab environment.

## 📁 Files in this Directory

### 🚀 Quick Start
- **`mlflow_simple_example.py`** - Simple example to test your MLflow setup (5 minutes)
- Perfect for beginners or testing your connection

### 🔬 Complete Example  
- **`mlflow_complete_example.py`** - Comprehensive example with multiple models (15-20 minutes)
- Demonstrates advanced MLflow features and best practices

### 📓 Interactive Notebook
- **`mlflow_example.ipynb`** - Jupyter notebook version for interactive learning
- Step-by-step cells you can run individually

## 🏃‍♂️ Quick Start Guide

### 1. Test Your MLflow Setup (Recommended First Step)

```bash
cd /shared
python mlflow_simple_example.py
```

This will:
- ✅ Test connection to MLflow server
- ✅ Create a simple experiment
- ✅ Train a basic model
- ✅ Log parameters, metrics, and artifacts
- ✅ Verify everything is working

Expected output:
```
🚀 Simple MLflow Example
========================================
1️⃣ Connecting to MLflow...
   ✅ Connected to: http://mlflow:5000
2️⃣ Creating experiment...
   ✅ Created experiment: quick-start-example
...
🎉 Success! Your MLflow setup is working correctly!
```

### 2. Run the Complete Example

```bash
python mlflow_complete_example.py
```

This comprehensive example includes:
- 🧠 PyTorch Neural Network training
- 🌲 Scikit-Learn Random Forest
- 📊 Model comparison and analysis
- 📈 Data visualization
- 📁 Artifact management
- 🏆 Best model selection

### 3. Try the Interactive Notebook

1. Open Jupyter Lab in your environment
2. Navigate to `/shared/mlflow_example.ipynb`
3. Run cells step-by-step to learn interactively

## 🔧 Configuration

The examples use these default settings:

```python
MLFLOW_TRACKING_URI = "http://mlflow:5000"
EXPERIMENT_NAME = "your-experiment-name"  
ARTIFACT_LOCATION = "file:///shared/mlflow-artifacts"
```

## 📊 What You'll Learn

### Basic MLflow Concepts
- **Experiments**: Organize related runs
- **Runs**: Individual training sessions
- **Parameters**: Hyperparameters you set
- **Metrics**: Results you measure
- **Artifacts**: Files you save (models, plots, data)
- **Tags**: Metadata for organization

### Advanced Features
- Model comparison and selection
- Artifact management
- Parameter logging best practices
- Metric tracking over time
- Model versioning
- Experiment organization

## 🎯 Viewing Results

After running any example:

1. **Open MLflow UI**: Navigate to `http://mlflow:5000` in your browser
2. **Find Your Experiment**: Look for your experiment name in the list
3. **Explore Runs**: Click on runs to see details
4. **View Artifacts**: Download models, plots, and data files
5. **Compare Models**: Use the compare feature to analyze different runs

## 🔍 Example Output Structure

After running examples, you'll see:

```
MLflow Experiments:
├── quick-start-example/
│   └── Run: Quick-Start-Run
│       ├── Parameters: n_estimators, max_depth, test_size
│       ├── Metrics: accuracy, train_samples, test_samples  
│       └── Artifacts: feature_importance.png, model/
│
├── shared-ml-experiments/ 
│   ├── Run: PyTorch-Neural-Network
│   ├── Run: RandomForest-Classifier
│   ├── Run: Dataset-Analysis
│   └── Run: Model-Comparison-Summary
│
└── notebook-ml-experiments/
    └── (Results from Jupyter notebook)
```

## 🛠️ Troubleshooting

### Connection Issues
```
❌ Error: Connection refused
```
**Solution**: Check if MLflow server is running at `http://mlflow:5000`

### Permission Issues  
```
❌ Error: Permission denied
```
**Solution**: Ensure you have write access to `/shared` directory

### Package Issues
```
❌ Error: No module named 'mlflow'
```
**Solution**: Install required packages:
```bash
pip install mlflow torch scikit-learn matplotlib seaborn pandas
```

### Artifact Storage Issues
```
❌ Error: Cannot write to artifact location
```
**Solution**: Check that `/shared/mlflow-artifacts` directory exists and is writable

## 📚 Additional Resources

### MLflow Documentation
- [MLflow Official Docs](https://mlflow.org/docs/latest/index.html)
- [MLflow Tracking Guide](https://mlflow.org/docs/latest/tracking.html)
- [MLflow Models Guide](https://mlflow.org/docs/latest/models.html)

### AI Lab Platform
- User Platform: Access your environments and notebooks
- Admin Portal: Manage shared datasets and user resources
- Monitoring: View system metrics and usage

## 🎨 Customizing the Examples

### Create Your Own Experiment

```python
import mlflow

# Set your experiment name
mlflow.set_experiment("my-custom-experiment")

with mlflow.start_run(run_name="my-run"):
    # Log parameters
    mlflow.log_param("learning_rate", 0.01)
    mlflow.log_param("batch_size", 32)
    
    # Log metrics
    mlflow.log_metric("accuracy", 0.95)
    mlflow.log_metric("loss", 0.05)
    
    # Log artifacts
    mlflow.log_artifact("my_plot.png")
    
    # Log model (example with sklearn)
    mlflow.sklearn.log_model(model, "my_model")
```

### Best Practices

1. **Use descriptive names**: Clear experiment and run names
2. **Log everything**: Parameters, metrics, and important artifacts
3. **Tag your runs**: Add metadata for easy filtering
4. **Version your data**: Log dataset information
5. **Document your process**: Add notes and descriptions
6. **Organize experiments**: Group related work together

## 🚀 Next Steps

1. **Run the examples** to familiarize yourself with MLflow
2. **Explore the UI** to understand the interface
3. **Create your own experiments** using your datasets
4. **Share results** with your team using MLflow
5. **Deploy models** using MLflow's model serving features

## 💡 Tips for Success

- Start with the simple example to verify everything works
- Use the notebook for interactive learning and experimentation  
- Run the complete example to see advanced features
- Create your own experiments based on these templates
- Use the MLflow UI extensively to explore your results
- Save and version your important models
- Document your experiments with good names and tags

---

**Happy experimenting! 🧪✨**

For questions or issues, check the AI Lab Platform documentation or contact your administrator. 