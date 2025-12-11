#!/bin/bash
# register_node.sh - Register MLNode with Network Node

cd /data/gonka-scripts
source setup_env.sh

echo "Registering MLNode with Network Node..."
echo "MLNode IP: $MLNODE_PUBLIC_IP"

# Check if external ports are set
if [ -z "$EXTERNAL_INFERENCE_PORT" ] || [ -z "$EXTERNAL_MANAGEMENT_PORT" ]; then
    echo ""
    echo "❌ ERROR: External ports not set!"
    echo ""
    echo "Please check your Vast.ai 'Open Ports' section and run:"
    echo ""
    echo "  export EXTERNAL_INFERENCE_PORT=XXXXX   # e.g., 19644"
    echo "  export EXTERNAL_MANAGEMENT_PORT=YYYYY  # e.g., 19391"
    echo "  bash register_node.sh"
    echo ""
    exit 1
fi

INFERENCE_PORT=$EXTERNAL_INFERENCE_PORT
MANAGEMENT_PORT=$EXTERNAL_MANAGEMENT_PORT

echo "Using external ports:"
echo "  Inference (vLLM): $INFERENCE_PORT"
echo "  Management (Gonka): $MANAGEMENT_PORT"

# Test connectivity first
echo ""
echo "Testing external connectivity..."
if curl -s --max-time 5 http://$MLNODE_PUBLIC_IP:$MANAGEMENT_PORT/api/v1/state > /dev/null 2>&1; then
    echo "✅ Management port $MANAGEMENT_PORT is accessible"
else
    echo "❌ Management port $MANAGEMENT_PORT is NOT accessible externally"
    echo "   Check Vast.ai port mappings!"
fi

# Create JSON payload
JSON_PAYLOAD=$(cat <<EOF
{
  "host": "$MLNODE_PUBLIC_IP",
  "inference_segment": "",
  "inference_port": $INFERENCE_PORT,
  "poc_segment": "",
  "poc_port": $MANAGEMENT_PORT,
  "models": {
    "Qwen/Qwen3-32B-FP8": {
      "args": ["--tensor-parallel-size", "4", "--pipeline-parallel-size", "1"]
    }
  },
  "id": "vast-a40-cluster",
  "max_concurrent": 1000,
  "hardware": null
}
EOF
)

echo ""
echo "Sending registration request..."
curl --max-time 10 -X POST ${NETWORK_NODE_ADMIN_API}/admin/v1/nodes \
  -H "Content-Type: application/json" \
  -d "$JSON_PAYLOAD"

echo ""
echo ""
echo "Checking registration status..."
sleep 2
curl -s ${NETWORK_NODE_ADMIN_API}/admin/v1/nodes | grep -A 30 '"id":"vast-a40-cluster"' | head -40
