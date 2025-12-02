#!/bin/bash
# Deploy FKS Platform to Kubernetes using Helm
# This script deploys the platform after k8s is started

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
MAIN_DIR="$REPO_DIR/main"
K8S_DIR="$MAIN_DIR/k8s"
NAMESPACE="${NAMESPACE:-fks-trading}"
RELEASE_NAME="${RELEASE_NAME:-fks-platform}"

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
    
    if ! command -v kubectl &> /dev/null; then
        log_error "kubectl is not installed"
        exit 1
    fi
    
    if ! command -v helm &> /dev/null; then
        log_error "helm is not installed"
        exit 1
    fi
    
    if ! kubectl cluster-info &> /dev/null; then
        log_error "Cannot connect to Kubernetes cluster"
        exit 1
    fi
    
    log_success "Prerequisites check passed ✓"
}

# Deploy platform
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
        --set fks_main.enabled=true \
        --set fks_api.enabled=true \
        --set fks_ai.enabled=false \
        --set fks_execution.enabled=false \
        --set fks_web.enabled=false \
        --set fks_ninja.enabled=false \
        --set postgresql.enabled=true \
        --set redis.enabled=true
    
    log_success "Platform deployed ✓"
}

# Wait for pods
wait_for_pods() {
    log_info "Waiting for pods to be ready..."
    
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
    log_info "Setting up port-forwarding for services..."
    
    # Kill any existing port-forwards
    pkill -f "kubectl port-forward" || true
    
    # Port-forward services
    log_info "Port-forwarding services..."
    kubectl port-forward -n "$NAMESPACE" svc/fks-app 8002:8002 > /dev/null 2>&1 &
    kubectl port-forward -n "$NAMESPACE" svc/fks-data 8003:8003 > /dev/null 2>&1 &
    kubectl port-forward -n "$NAMESPACE" svc/fks-main 8000:8000 > /dev/null 2>&1 &
    kubectl port-forward -n "$NAMESPACE" svc/fks-api 8001:8001 > /dev/null 2>&1 &
    
    sleep 3
    
    log_success "Port-forwarding set up ✓"
}

# Test services
test_services() {
    log_info "Testing services..."
    
    # Test fks_data
    log_info "Testing fks_data..."
    if curl -s "http://localhost:8003/health" > /dev/null 2>&1; then
        log_success "fks_data is healthy ✓"
    else
        log_warning "fks_data is not responding (may need a moment to start)"
    fi
    
    # Test fks_app
    log_info "Testing fks_app..."
    if curl -s "http://localhost:8002/health" > /dev/null 2>&1; then
        log_success "fks_app is healthy ✓"
    else
        log_warning "fks_app is not responding (may need a moment to start)"
    fi
    
    # Test Bitcoin signal generation
    log_info "Testing Bitcoin signal generation..."
    sleep 2
    if curl -s "http://localhost:8002/api/v1/signals/latest/BTCUSDT?category=swing&use_ai=false" | grep -q "signal_type" 2>/dev/null; then
        log_success "Bitcoin signal generation working ✓"
    else
        log_warning "Bitcoin signal generation may not be working yet (services may still be starting)"
    fi
}

# Show access information
show_access_info() {
    echo ""
    echo "╔═══════════════════════════════════════════════╗"
    echo "║  FKS Platform - Bitcoin Signal Demo          ║"
    echo "║  Deployment Complete                          ║"
    echo "╚═══════════════════════════════════════════════╝"
    echo ""
    
    log_info "=== Access Information ==="
    echo ""
    echo "Web Interface:"
    echo "  URL: http://localhost:8000"
    echo "  Admin: http://localhost:8000/admin/"
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

# Main execution
main() {
    echo ""
    echo "╔═══════════════════════════════════════════════╗"
    echo "║  FKS Platform - Bitcoin Signal Demo          ║"
    echo "║  Helm Deployment                              ║"
    echo "╚═══════════════════════════════════════════════╝"
    echo ""
    
    check_prerequisites
    deploy_platform
    wait_for_pods
    setup_port_forwarding
    test_services
    show_access_info
}

# Run main function
main

