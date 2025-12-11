#!/bin/bash
# setup_env.sh - Environment configuration for Vast.ai

# Get public IP from Vast.ai metadata
# Use the LOCAL IP from "Open Ports" section (175.x.x.x)
# NOT the public IP that curl ifconfig.me returns (198.x.x.x)
export MLNODE_PUBLIC_IP=$(hostname -I | awk '{print $1}')

# Internal ports (inside container)
export MLNODE_INFERENCE_PORT=5000
export MLNODE_MANAGEMENT_PORT=8080

# Network Node configuration
export NETWORK_NODE_IP="104.238.135.166"
export NETWORK_NODE_ADMIN_API="http://${NETWORK_NODE_IP}:9200"
export POC_CALLBACK_URL="http://${NETWORK_NODE_IP}:9100"

echo "========================================="
echo "MLNode Configuration"
echo "========================================="
echo "MLNode Public IP: $MLNODE_PUBLIC_IP"
echo "Inference Port (internal): $MLNODE_INFERENCE_PORT"
echo "Management Port (internal): $MLNODE_MANAGEMENT_PORT"
echo ""
echo "Network Node: $NETWORK_NODE_IP"
echo "Network Node Admin API: $NETWORK_NODE_ADMIN_API"
echo "PoC Callback URL: $POC_CALLBACK_URL"
echo "========================================="
echo ""
echo "⚠️  IMPORTANT: Check Vast.ai 'Open Ports' for external ports!"
echo "Example: 175.155.64.175:19644 -> 5000/tcp"
echo "         175.155.64.175:19391 -> 8080/tcp"
echo ""
echo "Set these BEFORE registering:"
echo "  export EXTERNAL_INFERENCE_PORT=19644   # Your actual port"
echo "  export EXTERNAL_MANAGEMENT_PORT=19391  # Your actual port"
