#!/bin/bash
set -e

# Load environment
source ./setup_env.sh

CONFIG_FILE=./config.yml
LOG_DIR=/data/logs
RESULTS_DIR=/data/benchmark_results

mkdir -p $LOG_DIR $RESULTS_DIR

echo "========================================="
echo "Gonka 8xA40 Benchmark (Native)"
echo "MLNode: $MLNODE_PUBLIC_IP"
echo "Network Node: $NETWORK_NODE_IP"
echo "Started: $(date)"
echo "========================================="

# Test configurations
declare -a CONFIGS=(
  "8:1:tp8_pp1"
  "4:2:tp4_pp2"
  "4:1:tp4_pp1"
  "2:4:tp2_pp4"
)

for config_str in "${CONFIGS[@]}"; do
  IFS=':' read -r tp pp name <<< "$config_str"
  
  echo ""
  echo "========================================="
  echo "Config: TP=$tp, PP=$pp ($name)"
  echo "Time: $(date)"
  echo "========================================="
  
  # Kill existing vLLM
  pkill -9 vllm || true
  pkill -9 python3 || true
  sleep 5
  
  # Start vLLM
  echo "Starting vLLM..."
  vllm serve $MODEL \
    --host 0.0.0.0 \
    --port $INFERENCE_PORT \
    --tensor-parallel-size $tp \
    --pipeline-parallel-size $pp \
    --gpu-memory-utilization 0.90 \
    --max-model-len 16384 \
    --max-num-batched-tokens 32768 \
    --max-num-seqs 256 \
    --trust-remote-code \
    > $LOG_DIR/vllm_${name}.log 2>&1 &
  
  VLLM_PID=$!
  echo "vLLM PID: $VLLM_PID"
  
  # Wait for ready
  echo "Waiting for vLLM..."
  for i in {1..90}; do
    if curl -s http://localhost:$INFERENCE_PORT/v1/models > /dev/null 2>&1; then
      echo "✓ Ready after ${i}s"
      break
    fi
    if [ $i -eq 90 ]; then
      echo "❌ Timeout"
      continue 2
    fi
    sleep 1
  done
  
  # Verify
  if ! curl -s http://localhost:$INFERENCE_PORT/health > /dev/null 2>&1; then
    echo "❌ Health check failed"
    continue
  fi
  echo "✓ Verified"
  
  # Benchmark
  echo "Running benchmark..."
  compressa-perf measure-from-yaml \
    --no-sign \
    --node_url http://localhost:$INFERENCE_PORT \
    --model_name $MODEL \
    --experiment_name "a40_8gpu_${name}" \
    $CONFIG_FILE \
    2>&1 | tee $LOG_DIR/bench_${name}.log
  
  echo "✓ Benchmark complete"
  
  # Stop
  kill $VLLM_PID 2>/dev/null || true
  sleep 10
  pkill -9 vllm python3 || true
  sleep 5
  
  echo "✓ Config $name done"
done

echo ""
echo "========================================="
echo "BENCHMARK COMPLETE!"
echo "========================================="
echo ""
echo "View results:"
echo "  compressa-perf list --show-metrics --show-parameters"
echo ""
echo "Compare:"
cat << 'SQL'
sqlite3 compressa-perf-db.sqlite "
  SELECT 
    experiment_name,
    ROUND(CAST(json_extract(metrics, '$.THROUGHPUT_OUTPUT_TOKENS') AS REAL), 2) as throughput,
    ROUND(CAST(json_extract(metrics, '$.TTFT') AS REAL), 3) as ttft,
    ROUND(CAST(json_extract(metrics, '$.TPOT') AS REAL), 4) as tpot
  FROM experiments 
  WHERE experiment_name LIKE 'a40_8gpu_%'
  ORDER BY throughput DESC;
"
SQL
