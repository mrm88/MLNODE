#!/bin/bash
set -e

source ./setup_env.sh

echo "Quick Test: TP=4, PP=2"
echo "MLNode IP: $MLNODE_PUBLIC_IP"

pkill -9 vllm python3 || true
sleep 3

echo "Starting vLLM..."
vllm serve $MODEL \
  --host 0.0.0.0 \
  --port $INFERENCE_PORT \
  --tensor-parallel-size 4 \
  --pipeline-parallel-size 2 \
  --gpu-memory-utilization 0.90 \
  --max-model-len 16384 \
  --trust-remote-code \
  > /data/logs/quick_test.log 2>&1 &

echo "Waiting 90s..."
sleep 90

echo "Testing..."
curl http://localhost:$INFERENCE_PORT/health
curl http://localhost:$INFERENCE_PORT/v1/models | jq

curl -X POST http://localhost:$INFERENCE_PORT/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "Qwen/Qwen3-32B-FP8",
    "messages": [{"role": "user", "content": "Hello"}],
    "max_tokens": 20
  }' | jq

echo ""
echo "✓ Quick test complete!"
nvidia-smi --query-gpu=utilization.gpu,memory.used --format=csv
