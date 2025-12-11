#!/bin/bash
# register_node.sh - Register MLNode with Network Node

cd /data/gonka-scripts
source setup_env.sh

echo "Registering MLNode with Network Node..."
echo "MLNode IP: $MLNODE_PUBLIC_IP"

curl --max-time 10 -X POST http://104.238.135.166:9200/admin/v1/nodes \
  -H "Content-Type: application/json" \
  -d "{\"host\":\"$MLNODE_PUBLIC_IP\",\"inference_segment\":\"\",\"inference_port\":5000,\"poc_segment\":\"\",\"poc_port\":8080,\"models\":{\"Qwen/Qwen3-32B-FP8\":{\"args\":[\"--tensor-parallel-size\",\"4\",\"--pipeline-parallel-size\",\"1\"]}},\"id\":\"a40-cluster-tp4\",\"max_concurrent\":1000,\"hardware\":null}"

echo ""
echo "Checking registration status..."
curl -s http://104.238.135.166:9200/admin/v1/nodes | jq '.[] | select(.node.id=="a40-cluster-tp4") | {id: .node.id, status: .state.current_status}'
