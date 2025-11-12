#!/usr/bin/env bash
# Enable NVIDIA GPU support in Minikube for FKS Platform

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_step() {
    echo -e "${BLUE}[STEP]${NC} $1"
}

# Check prerequisites
log_step "Checking prerequisites..."

if ! command -v nvidia-smi &> /dev/null; then
    echo "❌ NVIDIA drivers not found. Please install NVIDIA drivers first."
    exit 1
fi

if ! command -v nvidia-container-toolkit &> /dev/null && ! command -v nvidia-docker &> /dev/null; then
    echo "❌ nvidia-container-toolkit not found."
    echo "Install with: sudo pacman -S nvidia-container-toolkit"
    exit 1
fi

log_info "✅ NVIDIA drivers found: $(nvidia-smi --query-gpu=name --format=csv,noheader)"
log_info "✅ nvidia-container-toolkit installed"

# Configure Docker to use NVIDIA runtime
log_step "Configuring Docker for NVIDIA runtime..."

if [ ! -f /etc/docker/daemon.json ]; then
    log_warn "Creating /etc/docker/daemon.json..."
    sudo tee /etc/docker/daemon.json > /dev/null <<'EOF'
{
    "runtimes": {
        "nvidia": {
            "path": "nvidia-container-runtime",
            "runtimeArgs": []
        }
    },
    "default-runtime": "nvidia"
}
EOF
else
    log_info "/etc/docker/daemon.json already exists"
    log_warn "Ensure it includes nvidia runtime configuration"
fi

log_step "Restarting Docker daemon..."
sudo systemctl restart docker
sleep 3

# Test Docker NVIDIA runtime
log_step "Testing Docker NVIDIA runtime..."
if docker run --rm nvidia/cuda:12.0.0-base-ubuntu22.04 nvidia-smi; then
    log_info "✅ Docker NVIDIA runtime working!"
else
    echo "❌ Docker NVIDIA runtime test failed"
    exit 1
fi

# Stop minikube if running
if minikube status &> /dev/null; then
    log_warn "Stopping existing minikube cluster..."
    minikube stop
    sleep 3
fi

# Delete existing cluster to start fresh with GPU support
log_warn "Deleting existing minikube cluster to enable GPU..."
minikube delete || true
sleep 3

# Start minikube with GPU support
log_step "Starting minikube with GPU support..."
minikube start \
    --driver=docker \
    --cpus=6 \
    --memory=16384 \
    --disk-size=50g \
    --gpus=all \
    --container-runtime=docker

log_step "Enabling minikube addons..."
minikube addons enable ingress
minikube addons enable metrics-server
minikube addons enable dashboard

# Install NVIDIA device plugin for Kubernetes
log_step "Installing NVIDIA device plugin for Kubernetes..."
kubectl create -f https://raw.githubusercontent.com/NVIDIA/k8s-device-plugin/v0.15.0/deployments/static/nvidia-device-plugin.yml || \
    log_warn "NVIDIA device plugin may already be installed"

# Wait for device plugin to be ready
log_info "Waiting for NVIDIA device plugin to be ready..."
sleep 10

# Verify GPU is available
log_step "Verifying GPU availability in Kubernetes..."
GPU_COUNT=$(kubectl get nodes -o json | jq -r '.items[].status.capacity."nvidia.com/gpu"' | grep -v null | head -1)

if [ -n "$GPU_COUNT" ] && [ "$GPU_COUNT" != "null" ]; then
    log_info "✅ GPU detected in Kubernetes! Available GPUs: $GPU_COUNT"
else
    echo "❌ GPU not detected in Kubernetes cluster"
    echo "Checking node details..."
    kubectl describe node minikube | grep -A 5 "Allocatable"
    exit 1
fi

# Label the node for GPU workloads
log_step "Labeling minikube node for GPU workloads..."
kubectl label nodes minikube gpu=true --overwrite

echo ""
echo "=============================================="
echo -e "${GREEN}✅ GPU Support Enabled!${NC}"
echo "=============================================="
echo ""
echo "GPU Information:"
nvidia-smi --query-gpu=name,memory.total,driver_version,cuda_version --format=csv,noheader
echo ""
echo "Kubernetes GPU Capacity:"
kubectl get nodes -o json | jq -r '.items[].status.capacity."nvidia.com/gpu"'
echo ""
echo "To use GPU in pods, add this to your pod spec:"
echo ""
echo "  resources:"
echo "    limits:"
echo "      nvidia.com/gpu: 1"
echo ""
echo "Node selector (already set for fks-ai):"
echo "  nodeSelector:"
echo "    gpu: \"true\""
echo ""
echo "Next steps:"
echo "  1. Redeploy FKS platform: make k8s-dev"
echo "  2. Check fks-ai pod: kubectl get pods -n fks-trading | grep fks-ai"
echo ""
