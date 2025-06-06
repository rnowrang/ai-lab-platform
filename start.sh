#!/bin/bash

set -e

# Default to JupyterLab if no SERVICE_TYPE is specified
SERVICE_TYPE=${SERVICE_TYPE:-jupyter}

echo "Starting ML Platform Container..."
echo "Service Type: $SERVICE_TYPE"

# Start the appropriate service based on SERVICE_TYPE
case $SERVICE_TYPE in
    "jupyter")
        echo "Starting JupyterLab..."
        exec jupyter lab \
            --ip=0.0.0.0 \
            --port=8888 \
            --no-browser \
            --allow-root \
            --ServerApp.token='' \
            --ServerApp.password='' \
            --ServerApp.allow_origin='*' \
            --ServerApp.base_url=${JUPYTERHUB_SERVICE_PREFIX:-/} \
            --ServerApp.tornado_settings='{"headers":{"Content-Security-Policy":"frame-ancestors *"}}' \
            --notebook-dir=/home/jovyan
        ;;
    "vscode")
        echo "Starting VS Code Server..."
        exec code-server \
            --bind-addr=0.0.0.0:8080 \
            --auth=none \
            --disable-telemetry \
            /home/jovyan
        ;;
    "terminal")
        echo "Starting Terminal Session..."
        # Keep container running with interactive shell
        exec /bin/bash
        ;;
    *)
        echo "Unknown service type: $SERVICE_TYPE"
        echo "Available options: jupyter, vscode, terminal"
        exit 1
        ;;
esac 