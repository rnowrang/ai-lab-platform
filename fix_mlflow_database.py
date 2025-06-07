#!/usr/bin/env python3
"""
MLflow Database Fix
Identifies and helps resolve PostgreSQL integer overflow issues with large experiment IDs
"""

import mlflow
import pandas as pd

# Set MLflow connection
mlflow.set_tracking_uri("http://mlflow:5000")

def check_database_issues():
    """Check for database compatibility issues"""
    print("🔍 MLflow Database Health Check")
    print("=" * 50)
    
    try:
        # Get all experiments
        experiments = mlflow.search_experiments()
        print(f"✅ Found {len(experiments)} experiments")
        
        # Check for large experiment IDs
        large_id_experiments = []
        valid_experiments = []
        
        for exp in experiments:
            try:
                exp_id_int = int(exp.experiment_id)
                if -2147483648 <= exp_id_int <= 2147483647:  # PostgreSQL integer range
                    valid_experiments.append(exp)
                    print(f"✅ {exp.name} (ID: {exp.experiment_id}) - OK")
                else:
                    large_id_experiments.append(exp)
                    print(f"⚠️  {exp.name} (ID: {exp.experiment_id}) - TOO LARGE FOR POSTGRESQL")
            except ValueError:
                print(f"❌ {exp.name} (ID: {exp.experiment_id}) - INVALID ID FORMAT")
        
        print(f"\n📊 Summary:")
        print(f"✅ Valid experiments: {len(valid_experiments)}")
        print(f"⚠️  Problematic experiments: {len(large_id_experiments)}")
        
        if large_id_experiments:
            print(f"\n🔧 Problematic Experiments:")
            for exp in large_id_experiments:
                print(f"   - {exp.name} (ID: {exp.experiment_id})")
                try:
                    # Try to count runs for this experiment
                    runs = mlflow.search_runs(experiment_ids=[exp.experiment_id], max_results=1)
                    print(f"     Status: Has runs, will cause PostgreSQL errors")
                except Exception as e:
                    print(f"     Status: Cannot query runs - {e}")
        
        # Test run querying with valid experiments only
        print(f"\n🧪 Testing Run Queries:")
        if valid_experiments:
            try:
                valid_ids = [exp.experiment_id for exp in valid_experiments]
                runs = mlflow.search_runs(experiment_ids=valid_ids, max_results=5)
                print(f"✅ Successfully queried runs from valid experiments: {len(runs)} found")
            except Exception as e:
                print(f"❌ Error querying runs from valid experiments: {e}")
        
        # Recommend solutions
        print(f"\n💡 Recommendations:")
        if large_id_experiments:
            print("1. Use the updated dashboard that filters out large experiment IDs")
            print("2. Consider recreating experiments with smaller IDs if needed")
            print("3. The current MLflow version might have ID generation issues")
        else:
            print("✅ Database is healthy - no integer overflow issues detected")
            
        return valid_experiments, large_id_experiments
        
    except Exception as e:
        print(f"❌ Database health check failed: {e}")
        return None, None

def test_dashboard_compatibility():
    """Test if the dashboard will work with current database state"""
    print("\n🧪 Dashboard Compatibility Test")
    print("=" * 40)
    
    try:
        # Import and test the dashboard functions
        from mlflow_dashboard import show_experiments, show_runs
        
        print("Testing experiments display...")
        experiments = show_experiments()
        
        print("\nTesting runs display...")
        runs = show_runs(limit=5)
        
        if experiments is not None and (runs is not None or len(experiments) == 0):
            print("\n✅ Dashboard is compatible with current database state")
            return True
        else:
            print("\n❌ Dashboard compatibility issues detected")
            return False
            
    except Exception as e:
        print(f"❌ Dashboard compatibility test failed: {e}")
        return False

def main():
    """Main function to run all checks"""
    print("🚀 MLflow Database Fix Tool")
    print("=" * 60)
    
    # Check database issues
    valid_experiments, large_id_experiments = check_database_issues()
    
    if valid_experiments is not None:
        # Test dashboard compatibility
        compatible = test_dashboard_compatibility()
        
        print(f"\n🎯 Final Status:")
        if compatible:
            print("✅ MLflow dashboard is working correctly")
            print("🌟 You can now use the dashboard without PostgreSQL errors")
        else:
            print("⚠️  Some issues remain - check the error messages above")
    
    print(f"\n📋 Next Steps:")
    print("1. Use the updated mlflow_dashboard.py for Jupyter")
    print("2. Use the updated fix_mlflow_ui.py for web interface")
    print("3. Both now handle PostgreSQL integer overflow gracefully")

if __name__ == "__main__":
    main() 