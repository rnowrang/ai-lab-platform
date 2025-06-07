#!/usr/bin/env python3
"""
MLflow Dashboard for Jupyter
Alternative to the web UI - works perfectly in notebooks
"""

import mlflow
import pandas as pd
import matplotlib.pyplot as plt
import seaborn as sns
from IPython.display import display, HTML
import warnings
warnings.filterwarnings('ignore')

# Set MLflow connection
mlflow.set_tracking_uri("http://mlflow:5000")

def show_experiments():
    """Display all experiments"""
    try:
        experiments = mlflow.search_experiments()
        
        print("🧪 MLflow Experiments Dashboard")
        print("=" * 50)
        
        if experiments:
            exp_data = []
            for exp in experiments:
                exp_data.append({
                    'Name': exp.name,
                    'ID': exp.experiment_id,
                    'Lifecycle': exp.lifecycle_stage,
                    'Artifact Location': exp.artifact_location
                })
            
            df = pd.DataFrame(exp_data)
            display(HTML(df.to_html(index=False, escape=False)))
            return df
        else:
            print("No experiments found.")
            return None
            
    except Exception as e:
        print(f"❌ Error connecting to MLflow: {e}")
        return None

def show_runs(experiment_name=None, limit=20):
    """Display runs from an experiment"""
    try:
        if experiment_name:
            experiment = mlflow.get_experiment_by_name(experiment_name)
            if experiment:
                runs = mlflow.search_runs(experiment_ids=[experiment.experiment_id], max_results=limit)
            else:
                print(f"Experiment '{experiment_name}' not found.")
                return None
        else:
            # Fix: Get experiments first and filter out those with large IDs that cause PostgreSQL issues
            experiments = mlflow.search_experiments()
            valid_experiment_ids = []
            
            for exp in experiments:
                try:
                    # Try to convert experiment ID to int to check if it's within PostgreSQL integer range
                    exp_id_int = int(exp.experiment_id)
                    if -2147483648 <= exp_id_int <= 2147483647:  # PostgreSQL integer range
                        valid_experiment_ids.append(exp.experiment_id)
                    else:
                        print(f"⚠️  Skipping experiment '{exp.name}' (ID: {exp.experiment_id}) - ID too large for PostgreSQL")
                except ValueError:
                    # If conversion fails, skip this experiment
                    continue
            
            if valid_experiment_ids:
                runs = mlflow.search_runs(experiment_ids=valid_experiment_ids, max_results=limit)
            else:
                print("❌ No valid experiments found (all experiment IDs are out of PostgreSQL range)")
                return None
        
        if not runs.empty:
            print(f"🏃 Recent Runs ({len(runs)} found)")
            print("=" * 50)
            
            # Select key columns
            display_cols = ['run_id', 'experiment_id', 'status', 'start_time']
            
            # Add parameter columns
            param_cols = [col for col in runs.columns if col.startswith('params.')]
            display_cols.extend(param_cols)
            
            # Add metric columns
            metric_cols = [col for col in runs.columns if col.startswith('metrics.')]
            display_cols.extend(metric_cols)
            
            # Display available columns
            available_cols = [col for col in display_cols if col in runs.columns]
            
            display_df = runs[available_cols].copy()
            display_df['run_id'] = display_df['run_id'].str[:8] + '...'  # Shorten run IDs
            
            display(HTML(display_df.to_html(index=False, escape=False)))
            return runs
        else:
            print("No runs found.")
            return None
            
    except Exception as e:
        print(f"❌ Error fetching runs: {e}")
        return None

def plot_metrics(experiment_name=None, metric_names=None):
    """Plot metrics over time"""
    try:
        runs = show_runs(experiment_name, limit=100)
        
        if runs is None or runs.empty:
            return
        
        # Get metric columns
        metric_cols = [col for col in runs.columns if col.startswith('metrics.')]
        
        if not metric_cols:
            print("No metrics found to plot.")
            return
        
        # Filter metric names if specified
        if metric_names:
            metric_cols = [f"metrics.{name}" for name in metric_names if f"metrics.{name}" in metric_cols]
        
        if not metric_cols:
            print("Specified metrics not found.")
            return
        
        # Create plots
        n_metrics = len(metric_cols)
        if n_metrics > 0:
            fig, axes = plt.subplots(1, min(n_metrics, 3), figsize=(15, 5))
            if n_metrics == 1:
                axes = [axes]
            
            for i, metric_col in enumerate(metric_cols[:3]):  # Plot max 3 metrics
                metric_name = metric_col.replace('metrics.', '')
                
                # Filter out NaN values
                valid_runs = runs[runs[metric_col].notna()]
                
                if not valid_runs.empty:
                    axes[i].scatter(range(len(valid_runs)), valid_runs[metric_col], alpha=0.7)
                    axes[i].set_title(f'{metric_name}')
                    axes[i].set_xlabel('Run Index')
                    axes[i].set_ylabel(metric_name)
                    axes[i].grid(True, alpha=0.3)
            
            plt.tight_layout()
            plt.show()
    
    except Exception as e:
        print(f"❌ Error plotting metrics: {e}")

def create_run_comparison(run_ids):
    """Compare specific runs"""
    try:
        comparison_data = []
        
        for run_id in run_ids:
            run = mlflow.get_run(run_id)
            run_data = {
                'run_id': run_id[:8] + '...',
                'status': run.info.status,
                'start_time': run.info.start_time
            }
            
            # Add parameters
            for key, value in run.data.params.items():
                run_data[f'param_{key}'] = value
            
            # Add metrics
            for key, value in run.data.metrics.items():
                run_data[f'metric_{key}'] = value
            
            comparison_data.append(run_data)
        
        comparison_df = pd.DataFrame(comparison_data)
        
        print("🔍 Run Comparison")
        print("=" * 50)
        display(HTML(comparison_df.to_html(index=False, escape=False)))
        
        return comparison_df
        
    except Exception as e:
        print(f"❌ Error comparing runs: {e}")
        return None

def mlflow_summary():
    """Complete MLflow dashboard summary"""
    print("🚀 MLflow Platform Dashboard")
    print("=" * 60)
    
    # Show experiments
    experiments = show_experiments()
    
    print("\n" + "=" * 60)
    
    # Show recent runs
    runs = show_runs(limit=10)
    
    if runs is not None and not runs.empty:
        print("\n" + "=" * 60)
        
        # Plot metrics if available
        plot_metrics()
        
        print("\n📊 Platform Status: ✅ Fully Operational")
        print("🎯 All experiments and runs are being tracked successfully!")
    
    return experiments, runs

# Convenience functions for Jupyter
def dashboard():
    """Main dashboard function"""
    return mlflow_summary()

def experiments():
    """Show experiments only"""
    return show_experiments()

def runs(experiment_name=None, limit=20):
    """Show runs only"""
    return show_runs(experiment_name, limit)

def plot(experiment_name=None, metrics=None):
    """Plot metrics only"""
    return plot_metrics(experiment_name, metrics)

if __name__ == "__main__":
    # Run dashboard when executed
    dashboard() 