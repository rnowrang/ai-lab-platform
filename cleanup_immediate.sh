#!/bin/bash
# IMMEDIATE CLEANUP SCRIPT - Safe automatic cleanup
# Run this script to clean up cache files, temporary files, and other safe-to-remove items

set -e

echo "🧹 Starting immediate cleanup..."

# Phase 1: Remove cache and temporary files
echo "📁 Removing Python cache files..."
find . -name "__pycache__" -type d -exec rm -rf {} + 2>/dev/null || true
find . -name "*.pyc" -delete 2>/dev/null || true
find . -name "*.pyo" -delete 2>/dev/null || true

echo "📝 Removing editor temporary files..."
find . -name "*.swp" -delete 2>/dev/null || true
find . -name "*.swo" -delete 2>/dev/null || true
find . -name "*~" -delete 2>/dev/null || true

echo "🍎 Removing OS temporary files..."
find . -name ".DS_Store" -delete 2>/dev/null || true
find . -name "Thumbs.db" -delete 2>/dev/null || true

echo "📋 Files cleaned up:"
echo "  - Python cache files (__pycache__, *.pyc, *.pyo)"
echo "  - Editor swap files (*.swp, *.swo)"
echo "  - OS temporary files (.DS_Store, Thumbs.db)"

echo ""
echo "⚠️  SECURITY WARNING: These files need manual review:"
echo "  - credentials.txt (contains sensitive data)"
echo "  - ssl/privkey.pem (private SSL key)"
echo ""
echo "📋 Review CLEANUP_DECISIONS_NEEDED.md for items requiring decisions"
echo "✅ Immediate cleanup completed!" 