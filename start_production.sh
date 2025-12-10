#!/bin/bash
set -e

# Load environment
source ./setup_env.sh

# Optimal config (UPDATE AFTER BENCHMARKING)
TP=4
PP=2

echo "[$(date)] Starting Gonka MLNode - Production"
echo "[$(date)] MLNode Public IP: $MLNODE_PUBLIC_IP"
echo "[$(date)] Network Node: $NETWORK_NODE_IP"
echo "[$(date)] Configuration: TP=$TP, PP=$PP"
echo "[$(date)] Inference Port: $INFERENCE_PORT"

# Verify model is cached
if [ ! -d "$HF_HOME/hub/models--Qwen--Qwen3-32B-FP8" ]; then
  echo "[$(date)] Downloading model..."
  huggingface-cli download $MODEL --cache-dir $HF_HOME
fi

# Verify network connectivity to Network Node
echo "[$(date)] Testing connection to Network Node..."
if ! curl -s -m 5 http://$NETWORK_NODE_IP:$NETWORK_NODE_API_PORT/health > /dev/null 2>&1; then
  echo "[$(date)] WARNING: Cannot reach Network Node at $NETWORK_NODE_IP"
  echo "[$(date)] Continuing anyway - ensure firewall allows connection"
fi

# Start vLLM
echo "[$(date)] Starting vLLM..."
exec vllm serve $MODEL \
  --host 0.0.0.0 \
  --port $INFERENCE_PORT \
  --tensor-parallel-size $TP \
  --pipeline-parallel-size $PP \
  --gpu-memory-utilization 0.90 \
  --max-model-len 16384 \
  --max-num-batched-tokens 32768 \
  --max-num-seqs 256 \
  --trust-remote-code \
  2>&1 | tee /data/logs/production.log
