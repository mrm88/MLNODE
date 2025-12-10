#!/bin/bash
# register_node.sh - Register MLNode with Network Node

cd /data/gonka-scripts
source setup_env.sh

echo "Registering MLNode with Network Node..."
echo "MLNode IP: $MLNODE_PUBLIC_IP"

# Auto-detect or use environment variables
INFERENCE_PORT=${EXTERNAL_INFERENCE_PORT:-5000}
MANAGEMENT_PORT=${EXTERNAL_MANAGEMENT_PORT:-8080}

echo "Using ports: Inference=$INFERENCE_PORT, Management=$MANAGEMENT_PORT"

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
  "id": "a40-cluster-tp4",
  "max_concurrent": 1000,
  "hardware": null
}
EOF
)

# Send registration request
curl --max-time 10 -X POST http://104.238.135.166:9200/admin/v1/nodes \
  -H "Content-Type: application/json" \
  -d "$JSON_PAYLOAD"

echo ""
echo "Checking registration status..."
curl -s http://104.238.135.166:9200/admin/v1/nodes | jq '.[] | select(.node.id=="a40-cluster-tp4") | {id: .node.id, status: .state.current_status}'
