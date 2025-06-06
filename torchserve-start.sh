#!/bin/bash

set -e

echo "Starting TorchServe..."

# Create models configuration file if it doesn't exist
if [ ! -f "/mnt/models/models.json" ]; then
    echo "Creating default models configuration..."
    cat > /mnt/models/models.json <<EOF
{
  "models": {}
}
EOF
fi

# Set environment variables
export TS_CONFIG_FILE="/home/model-server/config.properties"

# Start TorchServe
echo "TorchServe configuration:"
cat $TS_CONFIG_FILE

exec torchserve \
    --start \
    --ts-config $TS_CONFIG_FILE \
    --model-store /mnt/models \
    --foreground 