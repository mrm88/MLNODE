#!/bin/bash
set -e

# Load environment
source ./setup_env.sh

# Optimal config from benchmark (UPDATE THIS)
TP=4
PP=2

echo "========================================="
echo "Registering MLNode with Network Node"
echo "========================================="
echo "MLNode IP: $MLNODE_PUBLIC_IP"
echo "Network Node: $NETWORK_NODE_IP"
echo "Config: TP=$TP, PP=$PP"
echo ""

# Check MLNode is running
if ! curl -s http://localhost:$INFERENCE_PORT/v1/models > /dev/null 2>&1; then
  echo "❌ ERROR: MLNode not running on port $INFERENCE_PORT"
  echo "Start it first: bash start_production.sh"
  exit 1
fi

echo "✓ MLNode is running"

# Register with Network Node Admin API
echo ""
echo "Registering via Network Node Admin API..."

RESPONSE=$(curl -s -X POST http://$NETWORK_NODE_IP:$NETWORK_NODE_ADMIN_PORT/admin/v1/nodes \
  -H "Content-Type: application/json" \
  -d "{
    \"id\": \"a40-cluster-1\",
    \"host\": \"http://${MLNODE_PUBLIC_IP}\",
    \"inference_port\": ${INFERENCE_PORT},
    \"poc_port\": ${MANAGEMENT_PORT},
    \"max_concurrent\": 1000,
    \"models\": {
      \"Qwen/Qwen3-32B-FP8\": {
        \"args\": [
          \"--tensor-parallel-size\", \"${TP}\",
          \"--pipeline-parallel-size\", \"${PP}\"
        ]
      }
    }
  }")

echo "Response: $RESPONSE"

# Verify registration
echo ""
echo "Verifying registration..."
sleep 2

ALL_NODES=$(curl -s http://$NETWORK_NODE_IP:$NETWORK_NODE_ADMIN_PORT/admin/v1/nodes)
echo "All registered nodes:"
echo "$ALL_NODES" | jq '.'

# Check if our node is in the list
if echo "$ALL_NODES" | jq -e '.[] | select(.id == "a40-cluster-1")' > /dev/null 2>&1; then
  echo ""
  echo "✓ SUCCESS! MLNode registered"
  echo ""
  echo "Your MLNode is now active!"
  echo "Monitor at: http://$NETWORK_NODE_IP:$NETWORK_NODE_API_PORT/v1/epochs/current/participants"
else
  echo ""
  echo "⚠ Registration response received but node not in list"
  echo "Check Network Node logs"
fi

echo ""
echo "========================================="
echo "IMPORTANT: Expose ports on Runpod!"
echo "========================================="
echo "Make sure these ports are exposed in Runpod:"
echo "  - Port $INFERENCE_PORT (inference)"
echo "  - Port $MANAGEMENT_PORT (management - if needed)"
echo ""
echo "Your Network Node needs to reach:"
echo "  http://${MLNODE_PUBLIC_IP}:${INFERENCE_PORT}"
