#!/bin/bash
# detect_ports.sh - Auto-detect RunPod external port mappings

echo "Detecting RunPod external port mappings..."

# Get public IP
PUBLIC_IP=$(curl -s ifconfig.me)
echo "Public IP: $PUBLIC_IP"

# Parse SSH port from environment or prompt
if [ -z "$RUNPOD_SSH_PORT" ]; then
    echo "Enter your RunPod SSH port (from SSH command):"
    read SSH_PORT
else
    SSH_PORT=$RUNPOD_SSH_PORT
fi

echo "SSH Port: $SSH_PORT"

# RunPod typically assigns ports sequentially
# SSH (22) = base port
# Next service = base + 1
# Next service = base + 2
INFERENCE_PORT=$((SSH_PORT + 1))
MANAGEMENT_PORT=$((SSH_PORT + 2))

echo ""
echo "Detected port mappings:"
echo "  vLLM Inference (5000): $PUBLIC_IP:$INFERENCE_PORT"
echo "  Gonka Management (8080): $PUBLIC_IP:$MANAGEMENT_PORT"

# Test connectivity
echo ""
echo "Testing external connectivity..."
if curl -s --max-time 5 http://$PUBLIC_IP:$INFERENCE_PORT/v1/models > /dev/null; then
    echo "✅ Inference port $INFERENCE_PORT is accessible"
else
    echo "❌ Inference port $INFERENCE_PORT is NOT accessible"
fi

if curl -s --max-time 5 http://$PUBLIC_IP:$MANAGEMENT_PORT/api/v1/state > /dev/null; then
    echo "✅ Management port $MANAGEMENT_PORT is accessible"
else
    echo "❌ Management port $MANAGEMENT_PORT is NOT accessible"
fi

# Export for use by other scripts
export EXTERNAL_INFERENCE_PORT=$INFERENCE_PORT
export EXTERNAL_MANAGEMENT_PORT=$MANAGEMENT_PORT

echo ""
echo "To use these ports, run:"
echo "export EXTERNAL_INFERENCE_PORT=$INFERENCE_PORT"
echo "export EXTERNAL_MANAGEMENT_PORT=$MANAGEMENT_PORT"
