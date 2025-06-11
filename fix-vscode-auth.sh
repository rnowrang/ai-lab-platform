#!/bin/bash

# VS Code Authentication Fix Script
# Disables authentication for VS Code containers

echo "🔧 VS Code Authentication Fix Tool"
echo "=================================="

# Function to fix a specific container
fix_container() {
    local container_name=$1
    
    if ! docker ps --filter "name=$container_name" --format "{{.Names}}" | grep -q "$container_name"; then
        echo "❌ Container $container_name not found or not running"
        return 1
    fi
    
    echo "🔄 Fixing authentication for $container_name..."
    
    # Create config directory if it doesn't exist
    docker exec "$container_name" mkdir -p /home/coder/.config/code-server
    
    # Set authentication to none
    docker exec "$container_name" bash -c 'echo "bind-addr: 127.0.0.1:8080
auth: none
cert: false" > /home/coder/.config/code-server/config.yaml'
    
    # Fix permissions
    docker exec "$container_name" chown -R coder:coder /home/coder/.config
    
    # Restart code-server
    docker exec "$container_name" pkill -f code-server
    
    echo "✅ Authentication disabled for $container_name"
    
    # Get port info
    local port=$(docker ps --filter "name=$container_name" --format "table {{.Ports}}" | grep -o "0.0.0.0:[0-9]*" | cut -d: -f2)
    if [ -n "$port" ]; then
        echo "🌐 Access at: http://localhost:$port"
    fi
}

# Function to fix all VS Code containers
fix_all_vscode() {
    echo "🔍 Finding all VS Code containers..."
    
    local vscode_containers=$(docker ps --filter "name=vscode" --format "{{.Names}}")
    
    if [ -z "$vscode_containers" ]; then
        echo "ℹ️ No running VS Code containers found"
        return
    fi
    
    echo "Found VS Code containers:"
    echo "$vscode_containers"
    echo ""
    
    for container in $vscode_containers; do
        fix_container "$container"
        echo ""
    done
}

# Main script logic
case "${1:-}" in
    --all|-a)
        fix_all_vscode
        ;;
    --container|-c)
        if [ -z "$2" ]; then
            echo "❌ Please specify container name: $0 --container <container_name>"
            exit 1
        fi
        fix_container "$2"
        ;;
    --help|-h)
        echo "Usage: $0 [OPTION] [CONTAINER_NAME]"
        echo ""
        echo "Options:"
        echo "  --all, -a           Fix all VS Code containers"
        echo "  --container, -c     Fix specific container"
        echo "  --help, -h          Show this help"
        echo ""
        echo "Examples:"
        echo "  $0 --all                              # Fix all VS Code containers"
        echo "  $0 --container ai-lab-vscode-123     # Fix specific container"
        echo "  $0                                    # Interactive mode"
        ;;
    "")
        echo "Select an option:"
        echo "1) Fix all VS Code containers"
        echo "2) Fix specific container"
        echo "3) List VS Code containers"
        echo ""
        read -p "Enter choice (1-3): " choice
        
        case $choice in
            1)
                fix_all_vscode
                ;;
            2)
                echo ""
                docker ps --filter "name=vscode" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
                echo ""
                read -p "Enter container name: " container_name
                fix_container "$container_name"
                ;;
            3)
                echo ""
                docker ps --filter "name=vscode" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
                ;;
            *)
                echo "❌ Invalid choice"
                exit 1
                ;;
        esac
        ;;
    *)
        echo "❌ Unknown option: $1"
        echo "Use --help for usage information"
        exit 1
        ;;
esac

echo ""
echo "🎉 VS Code authentication fix complete!" 