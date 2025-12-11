#!/bin/bash
# setup_mlnode.sh - Complete Vast.ai MLNode Setup

set -e

echo "========================================="
echo "Gonka MLNode Setup - Vast.ai"
echo "========================================="

# Fix DNS (Vast.ai issue)
echo "Fixing DNS configuration..."
echo "nameserver 8.8.8.8" > /etc/resolv.conf
echo "nameserver 8.8.4.4" >> /etc/resolv.conf

# Update system and install dependencies
echo "Installing system dependencies..."
apt-get update
apt-get install -y git screen sqlite3 jq curl pkg-config libsecp256k1-dev nginx wget

# Upgrade pip
python3.12 -m pip install --upgrade pip

# Install Python packages
echo "Installing Python packages..."
pip install git+https://github.com/product-science/compressa-perf.git --break-system-packages
pip install toml fire sentencepiece tiktoken fairscale h2 httpx[http2] huggingface_hub --break-system-packages

# Clone/update scripts
echo "Setting up scripts repository..."
cd /data
if [ ! -d "/data/gonka-scripts" ]; then
    git clone https://github.com/mrm88/MLNODE.git gonka-scripts
else
    cd gonka-scripts
    git pull origin main
    cd /data
fi

# Download and extract Gonka MLNode app
if [ ! -d "/data/app" ]; then
    echo "Downloading Gonka MLNode application..."
    cd /data
    rm -f gonka-mlnode-app.tar.gz*
    wget https://github.com/mrm88/MLNODE/releases/download/V1/gonka-mlnode-app.tar.gz
    
    echo "Extracting application..."
    tar -xzf gonka-mlnode-app.tar.gz
    rm gonka-mlnode-app.tar.gz
    
    echo "Verifying extraction..."
    ls -la app/packages/
fi

# Pre-download model (critical for Vast.ai)
if [ ! -d "/data/.cache/huggingface/hub/models--Qwen--Qwen3-32B-FP8" ]; then
    echo "========================================="
    echo "Downloading Qwen3-32B-FP8 model (~32GB)"
    echo "This will take 5-10 minutes..."
    echo "========================================="
    export HF_HOME=/data/.cache/huggingface
    huggingface-cli download Qwen/Qwen3-32B-FP8 --local-dir-use-symlinks False
    echo "Model download complete!"
else
    echo "Model already cached, skipping download."
fi

# Create logs directory
mkdir -p /data/logs

# Configure Nginx proxy (strips /v3.0.8 version prefix)
echo "Configuring Nginx reverse proxy..."
cat > /etc/nginx/sites-available/gonka-proxy <<'EOF'
server {
    listen 8080;
    server_name _;

    # Strip /vX.X.X prefix and proxy to Gonka API
    location ~ ^/v[0-9]+\.[0-9]+\.[0-9]+/(.*)$ {
        proxy_pass http://127.0.0.1:8081/$1$is_args$args;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_read_timeout 300s;
    }

    # Direct access without version
    location / {
        proxy_pass http://127.0.0.1:8081;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_read_timeout 300s;
    }
}
EOF

ln -sf /etc/nginx/sites-available/gonka-proxy /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default
nginx -t

# Start nginx
echo "Starting Nginx..."
pkill nginx 2>/dev/null || true
sleep 2
nginx

echo "========================================="
echo "Setup complete! ✅"
echo "========================================="
echo ""
echo "Next steps:"
echo "1. Start Gonka API: bash /data/gonka-scripts/start_gonka_api.sh"
echo "2. Start vLLM: bash /data/gonka-scripts/start_vllm_via_gonka.sh"
echo "3. Find your ports in Vast.ai 'Open Ports' section"
echo "4. Register: bash /data/gonka-scripts/register_node.sh"
