#!/bin/bash
# start_gonka_mlnode.sh - Run Gonka MLNode on RunPod

set -e

WORKSPACE=${WORKSPACE:-/workspace}
APP_DIR=$WORKSPACE/gonka-mlnode
DOWNLOAD_URL="https://github.com/mrm88/gonka-mlnode-scripts/releases/download/V1/gonka-mlnode-app.tar.gz"

echo "========================================="
echo "Gonka MLNode Setup"
echo "========================================="

# Download and extract if not exists
if [ ! -d "$APP_DIR" ]; then
    echo "Downloading Gonka MLNode..."
    cd $WORKSPACE
    wget -q $DOWNLOAD_URL
    tar -xzf gonka-mlnode-app.tar.gz
    mv gonka-mlnode-clean $APP_DIR
    rm gonka-mlnode-app.tar.gz
fi

cd $APP_DIR

# Install dependencies
echo "Installing dependencies..."
pip install fastapi uvicorn starlette httpx aiohttp pydantic --break-system-packages -q

# Set PYTHONPATH to include all package sources
export PYTHONPATH=$APP_DIR/packages/api/src:$APP_DIR/packages/pow/src:$APP_DIR/packages/train/src:$APP_DIR/packages/common/src:$PYTHONPATH

# Environment variables
export HF_HOME=${HF_HOME:-$WORKSPACE/.cache/huggingface}
export VLLM_ATTENTION_BACKEND=FLASHINFER
export TENSOR_PARALLEL_SIZE=${TENSOR_PARALLEL_SIZE:-4}
export PIPELINE_PARALLEL_SIZE=${PIPELINE_PARALLEL_SIZE:-1}
export MAX_MODEL_LEN=${MAX_MODEL_LEN:-16384}
export GPU_MEMORY_UTILIZATION=${GPU_MEMORY_UTILIZATION:-0.90}
export MODEL_NAME=${MODEL_NAME:-Qwen/Qwen3-32B-FP8}
export CUDA_VISIBLE_DEVICES=${CUDA_VISIBLE_DEVICES:-0,1,2,3}

echo "========================================="
echo "Configuration:"
echo "  Model: $MODEL_NAME"
echo "  TP: $TENSOR_PARALLEL_SIZE"
echo "  Max Length: $MAX_MODEL_LEN"
echo "  GPU Util: $GPU_MEMORY_UTILIZATION"
echo "========================================="

# Run MLNode
echo "Starting Gonka MLNode on port 8080..."
uvicorn api.app:app --host=0.0.0.0 --port=8080 --log-level info
