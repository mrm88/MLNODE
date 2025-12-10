#!/bin/bash
set -e

# CRITICAL: Export NCCL workarounds and V0 engine
export VLLM_USE_V1=0
export NCCL_P2P_DISABLE=1
export NCCL_IB_DISABLE=1
export NCCL_SOCKET_IFNAME=eth0

# Load environment
source ./setup_env.sh

CONFIG_FILE=./config.yml
LOG_DIR=/data/logs
mkdir -p $LOG_DIR

echo "========================================="
echo "Gonka 8xA40 Benchmark (Working Config)"
echo "MLNode: $MLNODE_PUBLIC_IP"
echo "Network Node: $NETWORK_NODE_IP"
echo "========================================="

# Configs to test (only ones that work)
declare -a CONFIGS=(
  "4:tp4"
  "8:tp8"
  "2:tp2"
)

for config_str in "${CONFIGS[@]}"; do
  IFS=':' read -r tp name <<< "$config_str"
  
  echo ""
  echo "========================================"
  echo "Testing: TP=$tp ($name)"
  echo "========================================"
  
  # Kill existing
  pkill -9 vllm python3 || true
  sleep 10
  
  # Start vLLM
  echo "Starting vLLM..."
  vllm serve $MODEL \
    --host 0.0.0.0 \
    --port $INFERENCE_PORT \
    --tensor-parallel-size $tp \
    --gpu-memory-utilization 0.90 \
    --max-model-len 16384 \
    --max-num-batched-tokens 32768 \
    --max-num-seqs 256 \
    --trust-remote-code \
    > $LOG_DIR/vllm_${name}.log 2>&1 &
  
  VLLM_PID=$!
  echo "vLLM PID: $VLLM_PID"
  
  # Wait for ready (up to 5 minutes)
  echo "Waiting for vLLM to start..."
  for i in {1..300}; do
    if curl -s http://localhost:$INFERENCE_PORT/v1/models > /dev/null 2>&1; then
      echo "✓ Ready after ${i}s"
      break
    fi
    if [ $i -eq 300 ]; then
      echo "❌ Timeout after 5 minutes"
      tail -50 $LOG_DIR/vllm_${name}.log
      continue 2
    fi
    sleep 1
  done
  
  # Verify
  if ! curl -s http://localhost:$INFERENCE_PORT/health > /dev/null 2>&1; then
    echo "❌ Health check failed"
    tail -50 $LOG_DIR/vllm_${name}.log
    continue
  fi
  echo "✓ Health check passed"
  
  # Run benchmark
  echo "Running compressa-perf benchmark..."
  compressa-perf measure-from-yaml \
    --no-sign \
    --node_url http://localhost:$INFERENCE_PORT \
    --model_name $MODEL \
    --experiment_name "a40_8gpu_${name}" \
    $CONFIG_FILE \
    2>&1 | tee $LOG_DIR/bench_${name}.log
  
  echo "✓ Benchmark complete for $name"
  
  # Stop
  kill $VLLM_PID 2>/dev/null || true
  sleep 5
  pkill -9 vllm python3 || true
  sleep 10
done

echo ""
echo "========================================"
echo "BENCHMARK COMPLETE!"
echo "========================================"
echo ""
echo "View results:"
echo "  compressa-perf list --show-metrics --show-parameters"
echo ""
echo "Compare (run this):"
cat << 'SQL'
sqlite3 compressa-perf-db.sqlite "
  SELECT 
    experiment_name as 'Config',
    ROUND(CAST(json_extract(metrics, '$.THROUGHPUT_OUTPUT_TOKENS') AS REAL), 2) as 'Throughput (tok/s)',
    ROUND(CAST(json_extract(metrics, '$.TTFT') AS REAL), 3) as 'TTFT (s)',
    ROUND(CAST(json_extract(metrics, '$.TPOT') AS REAL), 4) as 'TPOT (s)'
  FROM experiments 
  WHERE experiment_name LIKE 'a40_8gpu_%'
  ORDER BY CAST(json_extract(metrics, '$.THROUGHPUT_OUTPUT_TOKENS') AS REAL) DESC;
"
SQL
