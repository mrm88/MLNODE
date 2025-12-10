#!/bin/bash

# This runs automatically when pod starts

# Set critical environment variables
export VLLM_USE_V1=0
export NCCL_P2P_DISABLE=1
export NCCL_IB_DISABLE=1
export NCCL_SOCKET_IFNAME=eth0
export HF_HOME=/data/.cache/huggingface
export CUDA_VISIBLE_DEVICES=0,1,2,3,4,5,6,7

# Create directories
mkdir -p /data/logs /data/configs

# Pull latest scripts from GitHub
cd /data
if [ -d "gonka-scripts" ]; then
  cd gonka-scripts && git pull
else
  git clone https://github.com/mrm88/gonka-mlnode-scripts.git gonka-scripts
  cd gonka-scripts
fi

# Install compressa-perf if not already installed
apt-get install -y pkg-config libsecp256k1-dev 2>/dev/null || true
pip install git+https://github.com/product-science/compressa-perf.git --break-system-packages 2>/dev/null || true

echo "Startup complete. Ready to run:"
echo "  cd /data/gonka-scripts"
echo "  bash start_production_working.sh"
