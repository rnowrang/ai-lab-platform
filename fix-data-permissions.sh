#!/bin/bash

# AI Lab Platform - Fix Data Permissions Script
# Fixes ownership issues between container users and host directories

echo "🔧 AI Lab Platform - Data Permissions Fix"
echo "=========================================="

# Check if we're in the right directory
if [ ! -d "ai-lab-data" ]; then
    echo "❌ Error: ai-lab-data directory not found. Please run from project root."
    exit 1
fi

echo "📁 Fixing user data directory permissions..."

# Change ownership to match jovyan user in containers (UID 1000, GID 100)
# This allows Jupyter containers to write to the data directories
sudo chown -R 1000:100 ai-lab-data/users/

# Set proper permissions
# Directories: rwxrwxr-x (775) - owner and group can read/write/execute, others can read/execute
# Files: rw-rw-r-- (664) - owner and group can read/write, others can read
find ai-lab-data/users/ -type d -exec chmod 775 {} \; 2>/dev/null || true
find ai-lab-data/users/ -type f -exec chmod 664 {} \; 2>/dev/null || true

echo "✅ User data permissions fixed!"
echo ""
echo "📊 Summary:"
echo "- Changed ownership to UID 1000 (jovyan) and GID 100 (users)"
echo "- Set directory permissions to 775 (rwxrwxr-x)"
echo "- Set file permissions to 664 (rw-rw-r--)"
echo ""
echo "🎯 What this fixes:"
echo "- ✅ Create new notebooks in Jupyter"
echo "- ✅ Save existing notebooks"
echo "- ✅ Upload datasets"
echo "- ✅ Create folders and organize files"
echo ""
echo "🔍 Verification:"
echo "Try creating a new notebook in Jupyter - it should work without permission errors!" 