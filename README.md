# Gonka MLNode Scripts for 8×A40

Scripts for benchmarking and deploying Gonka MLNode on Runpod.

## Installation on Runpod
```bash
cd /data
git clone https://github.com/MRN88/gonka-mlnode-scripts.git scripts
cd scripts
chmod +x *.sh
```

## Usage

### 1. Setup Environment
```bash
source setup_env.sh
```

### 2. Quick Test
```bash
bash quick_test.sh
```

### 3. Run Full Benchmark
```bash
screen -S gonka-bench
bash gonka_native_benchmark.sh
# Ctrl+A, D to detach
```

### 4. View Results
```bash
compressa-perf list --show-metrics --show-parameters
```

### 5. Start Production
```bash
# Update TP/PP in start_production.sh based on benchmark results
nano start_production.sh

# Start
screen -S mlnode-prod
bash start_production.sh
```

### 6. Register with Network Node
```bash
bash register_with_network.sh
```

## Configuration

- **Network Node IP**: 104.238.135.166
- **Model**: Qwen/Qwen3-32B-FP8
- **Inference Port**: 5000
- **Management Port**: 8080
