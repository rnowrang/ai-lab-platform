#!/bin/bash

# AI Lab Platform - Post-Reboot Automation Installer
# This script installs the complete post-reboot automation system

set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if running as root for systemd operations
check_permissions() {
    if [ "$EUID" -ne 0 ]; then
        log_error "This script needs to be run with sudo for systemd installation"
        echo "Usage: sudo ./install-post-reboot-automation.sh"
        exit 1
    fi
}

# Install the automation system
install_automation() {
    log_info "🚀 Installing AI Lab Post-Reboot Automation System..."
    
    # Get the directory where this script is located
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    cd "$SCRIPT_DIR"
    
    # 1. Make automation script executable
    log_info "Making automation script executable..."
    chmod +x post-reboot-automation.sh
    
    # 2. Install systemd service
    log_info "Installing systemd service..."
    cp ai-lab-startup.service /etc/systemd/system/
    systemctl daemon-reload
    systemctl enable ai-lab-startup.service
    
    # 3. Test installation
    log_info "Testing service installation..."
    if systemctl is-enabled ai-lab-startup.service >/dev/null 2>&1; then
        log_info "✅ Systemd service installed and enabled successfully"
    else
        log_error "❌ Failed to enable systemd service"
        exit 1
    fi
    
    # 4. Verify files exist
    if [ -f "post-reboot-automation.sh" ] && [ -f "POST_REBOOT_AUTOMATION.md" ]; then
        log_info "✅ All automation files are present"
    else
        log_error "❌ Missing automation files"
        exit 1
    fi
    
    log_info "🎉 Post-Reboot Automation System installed successfully!"
    echo ""
    echo "📋 What was installed:"
    echo "  - Automation script: $SCRIPT_DIR/post-reboot-automation.sh"
    echo "  - Systemd service: /etc/systemd/system/ai-lab-startup.service"
    echo "  - Documentation: $SCRIPT_DIR/POST_REBOOT_AUTOMATION.md"
    echo ""
    echo "🔄 The automation will now run automatically on every reboot and will:"
    echo "  ✅ Clean up orphaned containers"
    echo "  ✅ Fix data directory permissions"
    echo "  ✅ Start all services with health checks"
    echo "  ✅ Verify data volume consistency"
    echo "  ✅ Test system functionality"
    echo "  ✅ Set up continuous health monitoring"
    echo ""
    echo "📊 Monitoring:"
    echo "  - Health checks: Every 5 minutes"
    echo "  - Log file: /var/log/ai-lab-post-reboot.log"
    echo "  - Service status: sudo systemctl status ai-lab-startup.service"
    echo ""
    echo "🧪 Test the automation:"
    echo "  sudo systemctl start ai-lab-startup.service"
    echo "  sudo journalctl -u ai-lab-startup.service -f"
    echo ""
    echo "🚀 No more manual post-reboot fixes needed!"
}

# Test the automation (optional)
test_automation() {
    log_info "🧪 Would you like to test the automation now? (y/N)"
    read -r response
    if [[ "$response" =~ ^[Yy]$ ]]; then
        log_info "Running automation test..."
        systemctl start ai-lab-startup.service
        sleep 5
        
        if systemctl is-active ai-lab-startup.service >/dev/null 2>&1; then
            log_info "✅ Automation test completed successfully"
            log_info "Check logs: sudo journalctl -u ai-lab-startup.service --no-pager"
        else
            log_warn "⚠️ Automation test may have issues"
            log_info "Check status: sudo systemctl status ai-lab-startup.service"
        fi
    fi
}

# Main execution
main() {
    echo "🔧 AI Lab Platform - Post-Reboot Automation Installer"
    echo "=================================================="
    echo ""
    
    check_permissions
    install_automation
    test_automation
    
    echo ""
    echo "✨ Installation complete! Your AI Lab Platform will now automatically"
    echo "   handle all post-reboot issues without manual intervention."
}

# Run main function
main "$@" 