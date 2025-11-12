#!/bin/bash
# Deploy Bitcoin Signal Demo to Kubernetes with fkstrading.xyz domain
# Complete deployment script for Bitcoin signal demo with domain configuration

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
VALUES_FILE="${VALUES_FILE:-$K8S_DIR/charts/fks-platform/values-fkstrading.yaml}"

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

# Check if NGINX Ingress is installed
check_nginx_ingress() {
    log_info "Checking NGINX Ingress Controller..."
    
    if kubectl get namespace ingress-nginx &> /dev/null; then
        log_success "NGINX Ingress Controller found ✓"
        
        # Check if ingress controller is running
        if kubectl get pods -n ingress-nginx -l app.kubernetes.io/component=controller | grep -q Running; then
            log_success "NGINX Ingress Controller is running ✓"
        else
            log_warning "NGINX Ingress Controller is not running. Waiting..."
            kubectl wait --for=condition=ready pod -l app.kubernetes.io/component=controller -n ingress-nginx --timeout=300s || log_warning "Ingress controller may not be ready"
        fi
    else
        log_warning "NGINX Ingress Controller not found. Installing..."
        install_nginx_ingress
    fi
}

# Install NGINX Ingress
install_nginx_ingress() {
    log_info "Installing NGINX Ingress Controller..."
    
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
    
    # Apply ingress configuration
    if [ -f "ingress.yaml" ]; then
        kubectl apply -f ingress.yaml -n "$NAMESPACE" || log_warning "Ingress configuration may already exist"
        log_success "Ingress configuration applied ✓"
    else
        log_warning "Ingress configuration file not found. Using Helm chart ingress instead."
    fi
}

# Deploy platform
deploy_platform() {
    log_info "Deploying FKS platform to Kubernetes with domain ${DOMAIN}..."
    
    cd "$K8S_DIR"
    
    # Create namespace if it doesn't exist
    kubectl create namespace "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -
    
    # Check if values file exists
    if [ ! -f "$VALUES_FILE" ]; then
        log_warning "Values file not found: $VALUES_FILE"
        log_info "Using default values file instead..."
        VALUES_FILE="$K8S_DIR/charts/fks-platform/values.yaml"
    fi
    
    # Deploy using Helm
    log_info "Deploying with Helm using values file: $VALUES_FILE"
    
    # Build Helm command
    HELM_CMD="helm upgrade --install $RELEASE_NAME ./charts/fks-platform --namespace $NAMESPACE --create-namespace"
    
    # Add values file if it exists
    if [ -f "$VALUES_FILE" ]; then
        HELM_CMD="$HELM_CMD -f $VALUES_FILE"
    fi
    
    # Add service overrides
    HELM_CMD="$HELM_CMD --set fks_app.enabled=true --set fks_data.enabled=true --set fks_main.enabled=true --set fks_api.enabled=true"
    HELM_CMD="$HELM_CMD --set fks_ai.enabled=false --set fks_execution.enabled=false --set fks_web.enabled=false --set fks_ninja.enabled=false"
    HELM_CMD="$HELM_CMD --set postgresql.enabled=true --set redis.enabled=true"
    HELM_CMD="$HELM_CMD --set global.domain=${DOMAIN}"
    HELM_CMD="$HELM_CMD --set ingress.enabled=false"  # Disable Helm ingress, use existing ingress.yaml
    HELM_CMD="$HELM_CMD --wait --timeout 10m"
    
    # Execute Helm command
    eval $HELM_CMD
    
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

# Get ingress IP
get_ingress_ip() {
    log_info "Getting ingress IP..."
    
    # Wait for ingress controller to get external IP
    sleep 10
    
    INGRESS_IP=$(kubectl get svc -n ingress-nginx ingress-nginx-controller -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "")
    
    if [ -z "$INGRESS_IP" ]; then
        INGRESS_IP=$(kubectl get svc -n ingress-nginx ingress-nginx-controller -o jsonpath='{.spec.externalIPs[0]}' 2>/dev/null || echo "")
    fi
    
    if [ -z "$INGRESS_IP" ]; then
        log_warning "Ingress IP not found. You may need to run 'minikube tunnel' to expose services."
        INGRESS_IP="<pending>"
    else
        log_success "Ingress IP: $INGRESS_IP ✓"
    fi
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

# Test services
test_services() {
    log_info "Testing services via domain..."
    
    # Wait a bit for services to be ready
    sleep 5
    
    # Test main domain
    log_info "Testing main domain: http://${DOMAIN}"
    if curl -s -k --max-time 5 "http://${DOMAIN}/health" > /dev/null 2>&1; then
        log_success "Main domain is accessible ✓"
    else
        log_warning "Main domain is not accessible yet (may need minikube tunnel)"
    fi
    
    # Test app service
    log_info "Testing app service: http://app.${DOMAIN}"
    if curl -s -k --max-time 5 "http://app.${DOMAIN}/health" > /dev/null 2>&1; then
        log_success "App service is accessible ✓"
    else
        log_warning "App service is not accessible yet"
    fi
    
    # Test Bitcoin signal generation
    log_info "Testing Bitcoin signal generation: http://app.${DOMAIN}/api/v1/signals/latest/BTCUSDT?category=swing&use_ai=false"
    sleep 2
    if curl -s -k --max-time 10 "http://app.${DOMAIN}/api/v1/signals/latest/BTCUSDT?category=swing&use_ai=false" | grep -q "signal_type" 2>/dev/null; then
        log_success "Bitcoin signal generation working ✓"
    else
        log_warning "Bitcoin signal generation may not be working yet (services may still be starting)"
    fi
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
    check_nginx_ingress
    apply_ingress
    deploy_platform
    wait_for_pods
    get_ingress_ip
    show_access_info
    test_services
}

# Run main function
main

