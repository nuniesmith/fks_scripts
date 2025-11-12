#!/bin/bash
# Deploy All 14 FKS Services to Kubernetes
# This script ensures all services are running and healthy

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
    
    log_success "Prerequisites check passed ✓"
}

# Check and start Kubernetes cluster
check_and_start_cluster() {
    log_info "Checking Kubernetes cluster status..."
    
    if ! kubectl cluster-info &> /dev/null; then
        log_warning "Kubernetes cluster is not running"
        
        # Check if minikube is available
        if command -v minikube &> /dev/null; then
            log_info "Starting minikube cluster..."
            minikube start --cpus=6 --memory=16384 --disk-size=50g --driver=docker || {
                log_error "Failed to start minikube"
                exit 1
            }
            
            # Enable addons
            log_info "Enabling minikube addons..."
            minikube addons enable ingress || log_warning "Failed to enable ingress addon"
            minikube addons enable metrics-server || log_warning "Failed to enable metrics-server addon"
            minikube addons enable dashboard || log_warning "Failed to enable dashboard addon"
            
            log_success "Minikube started and addons enabled ✓"
        else
            log_error "minikube is not installed and no Kubernetes cluster is running"
            log_error "Please start your Kubernetes cluster or install minikube"
            exit 1
        fi
    else
        log_success "Kubernetes cluster is running ✓"
        
        # Check if minikube
        if command -v minikube &> /dev/null && minikube status &> /dev/null; then
            log_info "Minikube cluster detected"
            
            # Ensure addons are enabled
            minikube addons enable ingress || log_warning "Failed to enable ingress addon"
            minikube addons enable metrics-server || log_warning "Failed to enable metrics-server addon"
            minikube addons enable dashboard || log_warning "Failed to enable dashboard addon"
        fi
    fi
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
    
    helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
    helm repo update
    
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
    log_info "Applying ingress configuration..."
    
    cd "$K8S_DIR"
    
    # Create namespace first
    kubectl create namespace "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -
    
    # Apply ingress configuration if it exists
    if [ -f "ingress.yaml" ]; then
        log_info "Applying ingress.yaml..."
        kubectl apply -f ingress.yaml -n "$NAMESPACE" || log_warning "Ingress configuration may already exist"
        log_success "Ingress configuration applied ✓"
    else
        log_warning "Ingress configuration file not found. Using Helm chart ingress instead."
    fi
}

# Deploy all services
deploy_all_services() {
    log_info "Deploying all FKS services..."
    
    cd "$K8S_DIR"
    
    # Create namespace
    kubectl create namespace "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -
    
    # Deploy using Helm with all services enabled
    log_info "Deploying with Helm (enabling all available services)..."
    
    # Note: Some services may not be in the Helm chart yet (auth, portfolio, monitor, meta, analyze, training)
    # We'll enable what's available in the chart
    helm upgrade --install "$RELEASE_NAME" \
        ./charts/fks-platform \
        --namespace "$NAMESPACE" \
        --create-namespace \
        --set fks_main.enabled=true \
        --set fks_api.enabled=true \
        --set fks_app.enabled=true \
        --set fks_data.enabled=true \
        --set fks_ai.enabled=false \
        --set fks_execution.enabled=true \
        --set fks_web.enabled=true \
        --set fks_ninja.enabled=false \
        --set postgresql.enabled=true \
        --set redis.enabled=true \
        --set ingress.enabled=false \
        --set global.domain="fkstrading.xyz" \
        --set fks_main.env[1].name="ALLOWED_HOSTS" \
        --set fks_main.env[1].value="fkstrading.xyz,*.fkstrading.xyz,localhost,127.0.0.1,100.80.141.117" \
        --wait \
        --timeout 15m
    
    log_success "Services deployed ✓"
}

# Wait for pods to be ready
wait_for_pods() {
    log_info "Waiting for all pods to be ready..."
    
    # Wait for all pods
    kubectl wait --for=condition=ready pod \
        --all \
        -n "$NAMESPACE" \
        --timeout=600s || log_warning "Some pods may not be ready yet"
    
    # Show pod status
    echo ""
    log_info "Pod status:"
    kubectl get pods -n "$NAMESPACE" -o wide
}

# Check pod health
check_pod_health() {
    log_info "Checking pod health..."
    
    # Get all pods
    PODS=$(kubectl get pods -n "$NAMESPACE" -o jsonpath='{.items[*].metadata.name}' 2>/dev/null || echo "")
    
    if [ -z "$PODS" ]; then
        log_warning "No pods found in namespace $NAMESPACE"
        return 1
    fi
    
    HEALTHY_COUNT=0
    UNHEALTHY_COUNT=0
    FAILED_PODS=()
    
    for pod in $PODS; do
        STATUS=$(kubectl get pod "$pod" -n "$NAMESPACE" -o jsonpath='{.status.phase}' 2>/dev/null || echo "Unknown")
        READY=$(kubectl get pod "$pod" -n "$NAMESPACE" -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null || echo "Unknown")
        
        if [ "$STATUS" == "Running" ] && [ "$READY" == "True" ]; then
            log_success "Pod $pod is healthy (Status: $STATUS, Ready: $READY)"
            HEALTHY_COUNT=$((HEALTHY_COUNT + 1))
        else
            log_warning "Pod $pod is not healthy (Status: $STATUS, Ready: $READY)"
            UNHEALTHY_COUNT=$((UNHEALTHY_COUNT + 1))
            FAILED_PODS+=("$pod")
            
            # Show pod events
            log_info "Events for $pod:"
            kubectl describe pod "$pod" -n "$NAMESPACE" | grep -A 10 "Events:" || true
            echo ""
        fi
    done
    
    echo ""
    log_info "Pod health summary:"
    log_info "  Healthy: $HEALTHY_COUNT"
    log_info "  Unhealthy: $UNHEALTHY_COUNT"
    
    if [ ${#FAILED_PODS[@]} -gt 0 ]; then
        log_warning "Failed pods:"
        for pod in "${FAILED_PODS[@]}"; do
            log_warning "  - $pod"
            # Show pod logs
            log_info "Recent logs for $pod:"
            kubectl logs "$pod" -n "$NAMESPACE" --tail=20 || true
            echo ""
        done
    fi
    
    return $UNHEALTHY_COUNT
}

# Check service health
check_service_health() {
    log_info "Checking service health..."
    
    # Get all services
    SERVICES=$(kubectl get svc -n "$NAMESPACE" -o jsonpath='{.items[*].metadata.name}' 2>/dev/null || echo "")
    
    if [ -z "$SERVICES" ]; then
        log_warning "No services found in namespace $NAMESPACE"
        return 1
    fi
    
    HEALTHY_COUNT=0
    UNHEALTHY_COUNT=0
    
    for service in $SERVICES; do
        # Skip infrastructure services for now
        if [[ "$service" == *"postgresql"* ]] || [[ "$service" == *"redis"* ]]; then
            continue
        fi
        
        # Check if service has endpoints
        ENDPOINTS=$(kubectl get endpoints "$service" -n "$NAMESPACE" -o jsonpath='{.subsets[*].addresses[*].ip}' 2>/dev/null || echo "")
        
        if [ -z "$ENDPOINTS" ]; then
            log_warning "Service $service has no endpoints"
            UNHEALTHY_COUNT=$((UNHEALTHY_COUNT + 1))
        else
            log_success "Service $service has endpoints: $ENDPOINTS"
            HEALTHY_COUNT=$((HEALTHY_COUNT + 1))
        fi
    done
    
    echo ""
    log_info "Service health summary:"
    log_info "  Healthy: $HEALTHY_COUNT"
    log_info "  Unhealthy: $UNHEALTHY_COUNT"
}

# Test service endpoints
test_service_endpoints() {
    log_info "Testing service endpoints..."
    
    # Port-forward services for testing
    log_info "Setting up port-forwarding for testing..."
    
    # Test fks_app
    log_info "Testing fks_app health endpoint..."
    kubectl port-forward -n "$NAMESPACE" svc/fks-app 8002:8002 &
    APP_PF_PID=$!
    sleep 5
    if curl -s http://localhost:8002/health > /dev/null 2>&1; then
        log_success "fks_app health endpoint is accessible ✓"
    else
        log_warning "fks_app health endpoint is not accessible"
    fi
    kill $APP_PF_PID 2>/dev/null || true
    
    # Test fks_data
    log_info "Testing fks_data health endpoint..."
    kubectl port-forward -n "$NAMESPACE" svc/fks-data 8003:8003 &
    DATA_PF_PID=$!
    sleep 5
    if curl -s http://localhost:8003/health > /dev/null 2>&1; then
        log_success "fks_data health endpoint is accessible ✓"
    else
        log_warning "fks_data health endpoint is not accessible"
    fi
    kill $DATA_PF_PID 2>/dev/null || true
}

# Fix common issues
fix_common_issues() {
    log_info "Checking for common issues..."
    
    # Check for ImagePullBackOff
    IMAGE_PULL_BACKOFF=$(kubectl get pods -n "$NAMESPACE" -o jsonpath='{.items[?(@.status.containerStatuses[0].state.waiting.reason=="ImagePullBackOff")].metadata.name}' 2>/dev/null || echo "")
    
    if [ -n "$IMAGE_PULL_BACKOFF" ]; then
        log_warning "Found ImagePullBackOff errors. Attempting to fix..."
        for pod in $IMAGE_PULL_BACKOFF; do
            log_info "Deleting pod $pod to force image pull..."
            kubectl delete pod "$pod" -n "$NAMESPACE" || true
        done
    fi
    
    # Check for CrashLoopBackOff
    CRASH_LOOP_BACKOFF=$(kubectl get pods -n "$NAMESPACE" -o jsonpath='{.items[?(@.status.containerStatuses[0].state.waiting.reason=="CrashLoopBackOff")].metadata.name}' 2>/dev/null || echo "")
    
    if [ -n "$CRASH_LOOP_BACKOFF" ]; then
        log_warning "Found CrashLoopBackOff errors. Checking logs..."
        for pod in $CRASH_LOOP_BACKOFF; do
            log_info "Logs for $pod:"
            kubectl logs "$pod" -n "$NAMESPACE" --tail=50 || true
        done
    fi
}

# Show deployment summary
show_deployment_summary() {
    echo ""
    echo "╔═══════════════════════════════════════════════╗"
    echo "║  FKS Platform - All Services Deployment      ║"
    echo "╚═══════════════════════════════════════════════╝"
    echo ""
    
    log_info "=== Deployment Summary ==="
    echo ""
    
    # Show pod status
    log_info "Pod Status:"
    kubectl get pods -n "$NAMESPACE" -o wide
    echo ""
    
    # Show service status
    log_info "Service Status:"
    kubectl get svc -n "$NAMESPACE"
    echo ""
    
    # Show deployment status
    log_info "Deployment Status:"
    kubectl get deployments -n "$NAMESPACE"
    echo ""
    
    # Show ingress status
    log_info "Ingress Status:"
    kubectl get ingress -n "$NAMESPACE" 2>/dev/null || log_warning "No ingress found"
    echo ""
    
    log_info "=== Access Information ==="
    echo ""
    echo "Namespace: $NAMESPACE"
    echo ""
    echo "To view logs:"
    echo "  kubectl logs -n $NAMESPACE -l app=fks-app -f"
    echo "  kubectl logs -n $NAMESPACE -l app=fks-data -f"
    echo ""
    echo "To view pod details:"
    echo "  kubectl describe pod <pod-name> -n $NAMESPACE"
    echo ""
    echo "To port-forward services:"
    echo "  kubectl port-forward -n $NAMESPACE svc/fks-app 8002:8002 &"
    echo "  kubectl port-forward -n $NAMESPACE svc/fks-data 8003:8003 &"
    echo "  kubectl port-forward -n $NAMESPACE svc/fks-main 8000:8000 &"
    echo "  kubectl port-forward -n $NAMESPACE svc/fks-api 8001:8001 &"
    echo ""
    echo "To access via domain (after minikube tunnel):"
    echo "  http://fkstrading.xyz"
    echo "  http://app.fkstrading.xyz"
    echo "  http://data.fkstrading.xyz"
    echo ""
}

# Main execution
main() {
    echo ""
    echo "╔═══════════════════════════════════════════════╗"
    echo "║  FKS Platform - All 14 Services Deployment   ║"
    echo "╚═══════════════════════════════════════════════╝"
    echo ""
    
    check_prerequisites
    check_and_start_cluster
    check_nginx_ingress
    apply_ingress
    deploy_all_services
    wait_for_pods
    fix_common_issues
    check_pod_health
    check_service_health
    test_service_endpoints
    show_deployment_summary
    
    echo ""
    log_success "✓ All services deployment complete!"
    echo ""
}

# Run main function
main

