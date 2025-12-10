#!/bin/bash
set -e

# CRITICAL: NCCL workarounds and V0 engine
export VLLM_USE_V1=0
export NCCL_P2P_DISABLE=1
export NCCL_IB_DISABLE=1
export NCCL_SOCKET_IFNAME=eth0

# Load environment
source ./setup_env.sh

# TP=4 (WINNER from benchmark!)
OPTIMAL_TP=4

echo "[$(date)] Starting Gonka MLNode - Production"
echo "[$(date)] MLNode Public IP: $MLNODE_PUBLIC_IP"
echo "[$(date)] Network Node: $NETWORK_NODE_IP"
echo "[$(date)] Configuration: TP=$OPTIMAL_TP"
echo "[$(date)] Inference Port: $INFERENCE_PORT"

# Kill any existing
pkill -9 -f "vllm" || true
pkill -9 -f "python3.*vllm" || true
sleep 10

# Start vLLM
echo "[$(date)] Starting vLLM with TP=$OPTIMAL_TP..."
exec vllm serve $MODEL \
  --host 0.0.0.0 \
  --port $INFERENCE_PORT \
  --tensor-parallel-size $OPTIMAL_TP \
  --gpu-memory-utilization 0.90 \
  --max-model-len 16384 \
  --max-num-batched-tokens 32768 \
  --max-num-seqs 256 \
  --trust-remote-code \
  2>&1 | tee /data/logs/production.log
