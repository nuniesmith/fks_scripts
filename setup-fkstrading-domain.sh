#!/bin/bash
# Complete setup script for fkstrading.xyz domain deployment
# This script sets up everything needed for the Bitcoin signal demo with domain

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
DOMAIN="fkstrading.xyz"
TAILSCALE_IP="100.80.141.117"

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

# Install NGINX Ingress
install_nginx_ingress() {
    log_info "Installing NGINX Ingress Controller..."
    
    # Check if already installed
    if kubectl get namespace ingress-nginx &> /dev/null; then
        log_success "NGINX Ingress Controller already installed ✓"
        return 0
    fi
    
    # Add Helm repository
    helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
    helm repo update
    
    # Install ingress-nginx
    helm upgrade --install ingress-nginx ingress-nginx/ingress-nginx \
        --namespace ingress-nginx \
        --create-namespace \
        --set controller.service.type=LoadBalancer \
        --wait \
        --timeout 5m
    
    log_success "NGINX Ingress Controller installed ✓"
}

# Apply ingress configuration
apply_ingress() {
    log_info "Applying ingress configuration for ${DOMAIN}..."
    
    cd "$K8S_DIR"
    
    # Create namespace first
    kubectl create namespace "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -
    
    # Apply ingress configuration
    if [ -f "ingress.yaml" ]; then
        log_info "Applying ingress.yaml for ${DOMAIN}..."
        kubectl apply -f ingress.yaml -n "$NAMESPACE" || log_warning "Ingress configuration may already exist"
        log_success "Ingress configuration applied ✓"
    else
        log_error "Ingress configuration file not found: ingress.yaml"
        exit 1
    fi
}

# Deploy platform
deploy_platform() {
    log_info "Deploying FKS platform to Kubernetes with domain ${DOMAIN}..."
    
    cd "$K8S_DIR"
    
    # Deploy using Helm
    log_info "Deploying with Helm..."
    helm upgrade --install "$RELEASE_NAME" \
        ./charts/fks-platform \
        --namespace "$NAMESPACE" \
        --create-namespace \
        --set fks_app.enabled=true \
        --set fks_data.enabled=true \
        --set fks_main.enabled=true \
        --set fks_api.enabled=true \
        --set fks_ai.enabled=false \
        --set fks_execution.enabled=false \
        --set fks_web.enabled=false \
        --set fks_ninja.enabled=false \
        --set postgresql.enabled=true \
        --set redis.enabled=true \
        --set global.domain="${DOMAIN}" \
        --set ingress.enabled=false \
        --set fks_main.env[1].name="ALLOWED_HOSTS" \
        --set fks_main.env[1].value="fkstrading.xyz,*.fkstrading.xyz,localhost,127.0.0.1,100.80.141.117" \
        --wait \
        --timeout 10m
    
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

# Show access information
show_access_info() {
    echo ""
    echo "╔═══════════════════════════════════════════════╗"
    echo "║  FKS Platform - Bitcoin Signal Demo          ║"
    echo "║  Domain: ${DOMAIN}                            ║"
    echo "║  Tailscale IP: ${TAILSCALE_IP}                ║"
    echo "╚═══════════════════════════════════════════════╝"
    echo ""
    
    log_info "=== Access Information ==="
    echo ""
    echo "Domain: ${DOMAIN}"
    echo "Tailscale IP: ${TAILSCALE_IP}"
    echo ""
    echo "⚠️  IMPORTANT: Run 'minikube tunnel' in a separate terminal to expose services"
    echo ""
    echo "Web Interface:"
    echo "  URL: http://${DOMAIN}"
    echo "  Admin: http://${DOMAIN}/admin/"
    echo ""
    echo "API Services:"
    echo "  Main API: http://${DOMAIN}"
    echo "  API Gateway: http://api.${DOMAIN}"
    echo "  App Service (Signals): http://app.${DOMAIN}"
    echo "  Data Service: http://data.${DOMAIN}"
    echo ""
    echo "Bitcoin Signal Demo:"
    echo "  Generate Signal: http://app.${DOMAIN}/api/v1/signals/latest/BTCUSDT?category=swing&use_ai=false"
    echo "  Health Check: http://app.${DOMAIN}/health"
    echo "  Data Service: http://data.${DOMAIN}/health"
    echo ""
    echo "View Pod Status:"
    echo "  kubectl get pods -n $NAMESPACE"
    echo ""
    echo "View Ingress:"
    echo "  kubectl get ingress -n $NAMESPACE"
    echo ""
    echo "View Logs:"
    echo "  kubectl logs -n $NAMESPACE -l app=fks-app -f"
    echo "  kubectl logs -n $NAMESPACE -l app=fks-data -f"
    echo ""
    echo "Start Minikube Tunnel:"
    echo "  minikube tunnel"
    echo ""
}

# Main execution
main() {
    echo ""
    echo "╔═══════════════════════════════════════════════╗"
    echo "║  FKS Platform - Bitcoin Signal Demo          ║"
    echo "║  Domain Deployment: ${DOMAIN}                  ║"
    echo "╚═══════════════════════════════════════════════╝"
    echo ""
    
    check_prerequisites
    install_nginx_ingress
    apply_ingress
    deploy_platform
    wait_for_pods
    show_access_info
}

# Run main function
main

