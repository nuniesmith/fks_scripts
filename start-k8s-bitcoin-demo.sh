#!/bin/bash
# Start Kubernetes and Deploy FKS Platform for Bitcoin Signal Demo
# This script starts k8s, pulls images from DockerHub, and deploys the platform

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
MAIN_DIR="$REPO_DIR/main"
K8S_DIR="$MAIN_DIR/k8s"
NAMESPACE="${NAMESPACE:-fks-trading}"
RELEASE_NAME="${RELEASE_NAME:-fks-platform}"

# Docker registry
DOCKER_USERNAME="nuniesmith"
DOCKER_REPO="fks"

# Functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check prerequisites
check_prerequisites() {
    log_info "Checking prerequisites..."
    
    # Check kubectl
    if ! command -v kubectl &> /dev/null; then
        log_error "kubectl is not installed. Please install kubectl first."
        exit 1
    fi
    
    # Check helm
    if ! command -v helm &> /dev/null; then
        log_error "helm is not installed. Please install Helm 3.x first."
        exit 1
    fi
    
    # Check minikube
    if ! command -v minikube &> /dev/null; then
        log_warning "minikube is not installed."
        read -p "Install minikube now? (y/n): " install_choice
        if [ "$install_choice" = "y" ]; then
            install_minikube
        else
            log_error "Cannot proceed without minikube."
            exit 1
        fi
    fi
    
    log_success "Prerequisites check passed ✓"
}

# Install minikube (Ubuntu/Debian)
install_minikube() {
    log_info "Installing minikube..."
    
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64
        sudo install minikube-linux-amd64 /usr/local/bin/minikube
        rm minikube-linux-amd64
        log_success "Minikube installed ✓"
    else
        log_error "Minikube installation is only supported on Linux in this script."
        log_info "Please install minikube manually: https://minikube.sigs.k8s.io/docs/start/"
        exit 1
    fi
}

# Start minikube
start_minikube() {
    log_info "Starting minikube cluster..."
    
    # Check if minikube is already running
    if minikube status &> /dev/null; then
        log_warning "Minikube is already running."
        read -p "Stop and restart minikube? (y/n): " restart_choice
        if [ "$restart_choice" = "y" ]; then
            minikube stop
            minikube delete
        else
            log_info "Using existing minikube cluster."
            return 0
        fi
    fi
    
    # Start minikube with sufficient resources
    log_info "Starting minikube with 6 CPUs, 16GB RAM, 50GB disk..."
    minikube start \
        --cpus=6 \
        --memory=16384 \
        --disk-size=50g \
        --driver=docker \
        --addons=ingress \
        --addons=metrics-server
    
    # Enable minikube Docker context
    eval $(minikube docker-env)
    
    log_success "Minikube started ✓"
}

# Pull images from DockerHub
pull_images() {
    log_info "Pulling images from DockerHub..."
    
    # Set minikube Docker context
    eval $(minikube docker-env)
    
    # Services needed for Bitcoin signal demo
    SERVICES=("app" "data" "web" "api" "main")
    
    local success_count=0
    local failed_services=()
    
    for service in "${SERVICES[@]}"; do
        local image_name="$DOCKER_USERNAME/$DOCKER_REPO:${service}-latest"
        log_info "Pulling $image_name..."
        
        if docker pull "$image_name" &> /dev/null; then
            log_success "Pulled $image_name ✓"
            success_count=$((success_count + 1))
        else
            log_warning "Failed to pull $image_name"
            failed_services+=("$service")
        fi
    done
    
    echo ""
    log_info "Image pull complete: $success_count/${#SERVICES[@]} services"
    if [ ${#failed_services[@]} -gt 0 ]; then
        log_warning "Failed to pull: ${failed_services[*]}"
        log_info "These images may not exist on DockerHub yet."
    fi
}

# Deploy FKS platform
deploy_platform() {
    log_info "Deploying FKS platform to Kubernetes..."
    
    cd "$K8S_DIR"
    
    # Create namespace if it doesn't exist
    kubectl create namespace "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -
    
    # Deploy using Helm
    log_info "Deploying with Helm..."
    helm upgrade --install "$RELEASE_NAME" \
        ./charts/fks-platform \
        --namespace "$NAMESPACE" \
        --create-namespace \
        --wait \
        --timeout 10m \
        --set fks_app.enabled=true \
        --set fks_data.enabled=true \
        --set fks_web.enabled=true \
        --set fks_api.enabled=true \
        --set fks_main.enabled=true \
        --set fks_ai.enabled=false \
        --set fks_execution.enabled=false \
        --set fks_ninja.enabled=false \
        --set postgresql.enabled=true \
        --set redis.enabled=true
    
    log_success "Platform deployed ✓"
}

# Wait for pods to be ready
wait_for_pods() {
    log_info "Waiting for pods to be ready..."
    
    # Wait for all pods in namespace
    kubectl wait --for=condition=ready pod \
        --all \
        -n "$NAMESPACE" \
        --timeout=600s || log_warning "Some pods are not ready yet"
    
    # Show pod status
    echo ""
    log_info "Pod status:"
    kubectl get pods -n "$NAMESPACE"
}

# Set up port-forwarding
setup_port_forwarding() {
    log_info "Setting up port-forwarding for web interface..."
    
    # Kill any existing port-forwards
    pkill -f "kubectl port-forward" || true
    
    # Port-forward services
    log_info "Port-forwarding services..."
    kubectl port-forward -n "$NAMESPACE" svc/fks-app 8002:8002 > /dev/null 2>&1 &
    kubectl port-forward -n "$NAMESPACE" svc/fks-data 8003:8003 > /dev/null 2>&1 &
    kubectl port-forward -n "$NAMESPACE" svc/fks-web 3001:3001 > /dev/null 2>&1 &
    kubectl port-forward -n "$NAMESPACE" svc/fks-api 8001:8001 > /dev/null 2>&1 &
    kubectl port-forward -n "$NAMESPACE" svc/fks-main 8000:8000 > /dev/null 2>&1 &
    
    sleep 3
    
    log_success "Port-forwarding set up ✓"
}

# Show access information
show_access_info() {
    echo ""
    echo "╔═══════════════════════════════════════════════╗"
    echo "║  FKS Platform - Bitcoin Signal Demo          ║"
    echo "║  Kubernetes Deployment Complete               ║"
    echo "╚═══════════════════════════════════════════════╝"
    echo ""
    
    log_info "=== Access Information ==="
    echo ""
    echo "Web Interface (React):"
    echo "  URL: http://localhost:3001"
    echo ""
    echo "API Services:"
    echo "  fks_app (Signals): http://localhost:8002"
    echo "  fks_data (Data): http://localhost:8003"
    echo "  fks_api (Gateway): http://localhost:8001"
    echo "  fks_main (Main): http://localhost:8000"
    echo ""
    echo "Test Bitcoin Signal Generation:"
    echo "  curl \"http://localhost:8002/api/v1/signals/latest/BTCUSDT?category=swing&use_ai=false\""
    echo ""
    echo "View Pod Status:"
    echo "  kubectl get pods -n $NAMESPACE"
    echo ""
    echo "View Logs:"
    echo "  kubectl logs -n $NAMESPACE -l app=fks-app -f"
    echo "  kubectl logs -n $NAMESPACE -l app=fks-data -f"
    echo ""
    echo "Stop Port-Forwarding:"
    echo "  pkill -f \"kubectl port-forward\""
    echo ""
}

# Test services
test_services() {
    log_info "Testing services..."
    
    # Test fks_data
    log_info "Testing fks_data..."
    if curl -s "http://localhost:8003/health" > /dev/null; then
        log_success "fks_data is healthy ✓"
    else
        log_warning "fks_data is not responding"
    fi
    
    # Test fks_app
    log_info "Testing fks_app..."
    if curl -s "http://localhost:8002/health" > /dev/null; then
        log_success "fks_app is healthy ✓"
    else
        log_warning "fks_app is not responding"
    fi
    
    # Test Bitcoin signal generation
    log_info "Testing Bitcoin signal generation..."
    if curl -s "http://localhost:8002/api/v1/signals/latest/BTCUSDT?category=swing&use_ai=false" | grep -q "signal_type"; then
        log_success "Bitcoin signal generation working ✓"
    else
        log_warning "Bitcoin signal generation may not be working"
    fi
}

# Main execution
main() {
    echo ""
    echo "╔═══════════════════════════════════════════════╗"
    echo "║  FKS Platform - Bitcoin Signal Demo          ║"
    echo "║  Kubernetes Deployment                        ║"
    echo "╚═══════════════════════════════════════════════╝"
    echo ""
    
    # Check prerequisites
    check_prerequisites
    
    # Start minikube
    start_minikube
    
    # Pull images
    pull_images
    
    # Deploy platform
    deploy_platform
    
    # Wait for pods
    wait_for_pods
    
    # Set up port-forwarding
    setup_port_forwarding
    
    # Test services
    test_services
    
    # Show access information
    show_access_info
}

# Run main function
main

