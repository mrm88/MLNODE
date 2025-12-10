#!/bin/bash
# register_with_network.sh - Register MLNode with Network Node using best benchmarked config

set -e

# Source environment variables
source "$(dirname "$0")/setup_env.sh"

echo "========================================="
echo "MLNode Configuration"
echo "========================================="
echo "MLNode Public IP: $MLNODE_IP"
echo "Inference Port: $MLNODE_INFERENCE_PORT"
echo "Management Port: $MLNODE_MANAGEMENT_PORT"
echo ""
echo "Network Node: $NETWORK_NODE_IP"
echo "Network Node Admin API: $NETWORK_NODE_ADMIN_API"
echo "PoC Callback URL: $POC_CALLBACK_URL"
echo "========================================="

# Auto-detect best config from benchmark database
DB_PATH="/data/gonka-scripts/compressa-perf-db.sqlite"

if [ -f "$DB_PATH" ]; then
    echo "Detecting best benchmarked configuration..."
    
    BEST_RESULT=$(sqlite3 "$DB_PATH" "SELECT e.name, CAST(m.value AS REAL) as throughput FROM Experiments e JOIN Metrics m ON e.id = m.experiment_id WHERE m.name = 'THROUGHPUT_OUTPUT_TOKENS' AND e.name LIKE 'gonka-tp%' ORDER BY throughput DESC LIMIT 1;")
    
    if [ -n "$BEST_RESULT" ]; then
        BEST_CONFIG=$(echo "$BEST_RESULT" | cut -d'|' -f1)
        BEST_THROUGHPUT=$(echo "$BEST_RESULT" | cut -d'|' -f2)
        TP_VALUE=$(echo "$BEST_CONFIG" | sed 's/.*tp\([0-9]*\).*/\1/')
        
        echo "Best config: TP=$TP_VALUE ($BEST_THROUGHPUT tok/s)"
        TP_SIZE=$TP_VALUE
    else
        echo "No benchmark results found, using default TP=4"
        TP_SIZE=4
    fi
else
    echo "Benchmark database not found, using default TP=4"
    TP_SIZE=4
fi

PP_SIZE=1

echo "========================================="
echo "Registering MLNode with Network Node"
echo "========================================="
echo "MLNode IP: $MLNODE_IP"
echo "Network Node: $NETWORK_NODE_IP"
echo "Config: TP=$TP_SIZE, PP=$PP_SIZE"

# Check if MLNode is running
if ! curl -s http://localhost:5000/health > /dev/null 2>&1; then
    echo "ERROR: MLNode is not running on port 5000"
    exit 1
fi

echo "MLNode is running"

# Register with Network Node Admin API
echo "Registering via Network Node Admin API..."

RESPONSE=$(curl -s -X POST ${NETWORK_NODE_ADMIN_API}/admin/v1/nodes \
  -H "Content-Type: application/json" \
  -d "{
    \"host\": \"${MLNODE_IP}\",
    \"inference_segment\": \"\",
    \"inference_port\": ${MLNODE_INFERENCE_PORT},
    \"poc_segment\": \"\",
    \"poc_port\": ${MLNODE_MANAGEMENT_PORT},
    \"models\": {
      \"${MODEL_NAME}\": {
        \"args\": [
          \"--tensor-parallel-size\",
          \"${TP_SIZE}\",
          \"--pipeline-parallel-size\",
          \"${PP_SIZE}\"
        ]
      }
    },
    \"id\": \"${MLNODE_ID}\",
    \"max_concurrent\": 1000,
    \"hardware\": null
  }")

echo "Response: $RESPONSE"

echo ""
echo "========================================="
echo "Registration Complete!"
echo "========================================="
echo "MLNode ID: ${MLNODE_ID}"
echo "Config: TP=$TP_SIZE, PP=$PP_SIZE"
echo "========================================="
