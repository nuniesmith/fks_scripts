#!/bin/bash
# FKS Trading Platform - Unified Startup Script
# Supports both Docker Compose and Kubernetes deployments

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Configuration
# Resolve symlink to actual script location
SCRIPT_SOURCE="${BASH_SOURCE[0]}"
while [ -L "$SCRIPT_SOURCE" ]; do
    SCRIPT_SOURCE="$(readlink -f "$SCRIPT_SOURCE")"
done
SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_SOURCE")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"  # Go up two levels from repo/main to fks root
REPO_DIR="$PROJECT_ROOT/repo"
NAMESPACE="${NAMESPACE:-fks-trading}"

# Defaults
DEPLOYMENT_TYPE="${DEPLOYMENT_TYPE:-compose}"  # compose or k8s
ENABLE_DASHBOARD="${ENABLE_DASHBOARD:-false}"
K8S_CLUSTER_TYPE="${K8S_CLUSTER_TYPE:-minikube}"  # minikube, single-node, multi-node
BUILD_IMAGES="${BUILD_IMAGES:-true}"  # Auto-build images for k8s
FIX_NAMESPACE="${FIX_NAMESPACE:-false}"  # Fix namespace issues

# Logging functions
log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_step() { echo -e "${CYAN}[STEP]${NC} $1"; }

# Print banner
print_banner() {
    echo ""
    echo -e "${CYAN}╔═══════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║  FKS Trading Platform - Startup               ║${NC}"
    echo -e "${CYAN}║  Deployment Type: ${DEPLOYMENT_TYPE^^}${NC}$(printf '%*s' $((25-${#DEPLOYMENT_TYPE})) '')  ║"
    echo -e "${CYAN}╚═══════════════════════════════════════════════╝${NC}"
    echo ""
}

# Show usage
show_usage() {
    cat << EOF
FKS Trading Platform - Unified Startup Script

Usage: $0 [OPTIONS]

OPTIONS:
    -t, --type TYPE          Deployment type: compose or k8s (default: compose)
    -d, --dashboard          Enable Kubernetes dashboard (k8s only)
    -c, --cluster TYPE       K8s cluster type: minikube, single-node, multi-node (default: minikube)
    -n, --namespace NAME     Kubernetes namespace (default: fks-trading)
    -b, --build-images       Build Docker images before deployment (k8s only, default: true)
    --no-build               Skip building images (k8s only)
    -f, --fix                 Fix namespace issues (k8s only: secrets, pods, restarts)
    -h, --help               Show this help message

ENVIRONMENT VARIABLES:
    DEPLOYMENT_TYPE          Set default deployment type (compose|k8s)
    ENABLE_DASHBOARD         Enable K8s dashboard (true|false)
    K8S_CLUSTER_TYPE         K8s cluster type (minikube|single-node|multi-node)
    NAMESPACE                Kubernetes namespace
    BUILD_IMAGES             Build images before deployment (true|false, default: true)
    FIX_NAMESPACE            Fix namespace issues automatically (true|false, default: false)

EXAMPLES:
    # Docker Compose deployment
    $0 --type compose
    DEPLOYMENT_TYPE=compose $0

    # Kubernetes with Minikube
    $0 --type k8s
    $0 --type k8s --dashboard

    # Kubernetes multi-node cluster
    $0 --type k8s --cluster multi-node --dashboard

    # Build images and fix namespace
    $0 --type k8s --build-images --fix

    # Skip image building
    $0 --type k8s --no-build

EOF
}

# Parse arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -t|--type)
                DEPLOYMENT_TYPE="$2"
                shift 2
                ;;
            -d|--dashboard)
                ENABLE_DASHBOARD=true
                shift
                ;;
            -c|--cluster)
                K8S_CLUSTER_TYPE="$2"
                shift 2
                ;;
            -n|--namespace)
                NAMESPACE="$2"
                shift 2
                ;;
            -b|--build-images)
                BUILD_IMAGES=true
                shift
                ;;
            --no-build)
                BUILD_IMAGES=false
                shift
                ;;
            -f|--fix)
                FIX_NAMESPACE=true
                shift
                ;;
            -h|--help)
                show_usage
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                show_usage
                exit 1
                ;;
        esac
    done
}

# Check prerequisites
check_prerequisites() {
    log_step "Checking prerequisites..."
    
    if [ "$DEPLOYMENT_TYPE" == "compose" ]; then
        # Check Docker Compose
        if docker compose version >/dev/null 2>&1; then
            DOCKER_COMPOSE_CMD="docker compose"
        elif command -v docker-compose >/dev/null 2>&1; then
            DOCKER_COMPOSE_CMD="docker-compose"
        else
            log_error "Docker Compose not found"
            exit 1
        fi
        log_success "Docker Compose found"
        
    elif [ "$DEPLOYMENT_TYPE" == "k8s" ]; then
        # Check kubectl
        if ! command -v kubectl &> /dev/null; then
            log_error "kubectl not found"
            exit 1
        fi
        log_success "kubectl found"
        
        # Check cluster type specific tools
        case "$K8S_CLUSTER_TYPE" in
            minikube)
                if ! command -v minikube &> /dev/null; then
                    log_error "minikube not found"
                    exit 1
                fi
                log_success "minikube found"
                ;;
            single-node|multi-node)
                if ! command -v kubeadm &> /dev/null; then
                    log_warning "kubeadm not found (required for $K8S_CLUSTER_TYPE cluster)"
                fi
                ;;
        esac
    fi
    
    log_success "Prerequisites check complete"
}

# Setup Kubernetes cluster
setup_k8s_cluster() {
    log_step "Setting up Kubernetes cluster ($K8S_CLUSTER_TYPE)..."
    
    case "$K8S_CLUSTER_TYPE" in
        minikube)
            if minikube status &> /dev/null; then
                log_info "Minikube cluster exists, starting it..."
                minikube start
            else
                log_info "Creating new minikube cluster..."
                minikube start \
                    --cpus=4 \
                    --memory=8192 \
                    --disk-size=30g \
                    --addons=ingress \
                    --addons=metrics-server
            fi
            
            # Configure Docker to use minikube
            eval $(minikube -p minikube docker-env)
            log_success "Minikube cluster ready"
            ;;
            
        single-node)
            log_info "Setting up single-node Kubernetes cluster..."
            log_warning "This requires root privileges and will initialize kubeadm"
            
            if [ "$EUID" -ne 0 ]; then
                log_error "Single-node cluster setup requires root privileges"
                log_info "Run: sudo $0 --type k8s --cluster single-node"
                exit 1
            fi
            
            # Initialize kubeadm if not already done
            if [ ! -f /etc/kubernetes/admin.conf ]; then
                log_info "Initializing kubeadm..."
                kubeadm init --pod-network-cidr=10.244.0.0/16
                
                # Setup kubeconfig
                mkdir -p $HOME/.kube
                cp /etc/kubernetes/admin.conf $HOME/.kube/config
                chown $(id -u):$(id -g) $HOME/.kube/config
            fi
            
            log_success "Single-node cluster ready"
            ;;
            
        multi-node)
            log_info "Setting up multi-node Kubernetes cluster..."
            log_warning "Multi-node setup requires manual configuration"
            log_info "Master node: kubeadm init"
            log_info "Worker nodes: kubeadm join <master-ip>:6443 --token <token>"
            
            # Check if this is master or worker
            if kubectl cluster-info &> /dev/null 2>&1; then
                log_success "Connected to existing cluster"
            else
                log_error "Not connected to a cluster"
                log_info "For master: sudo kubeadm init"
                log_info "For worker: kubeadm join <master-ip>:6443 --token <token>"
                exit 1
            fi
            ;;
    esac
}

# Setup Kubernetes dashboard
setup_k8s_dashboard() {
    if [ "$ENABLE_DASHBOARD" != "true" ]; then
        return 0
    fi
    
    log_step "Setting up Kubernetes dashboard..."
    
    # Enable dashboard addon for minikube
    if [ "$K8S_CLUSTER_TYPE" == "minikube" ]; then
        minikube addons enable dashboard 2>/dev/null || true
        log_success "Dashboard addon enabled"
    else
        # Install dashboard manually for other cluster types
        log_info "Installing Kubernetes dashboard..."
        kubectl apply -f https://raw.githubusercontent.com/kubernetes/dashboard/v2.7.0/aio/deploy/recommended.yaml
        
        # Create admin service account
        kubectl apply -f - <<EOF 2>/dev/null || true
apiVersion: v1
kind: ServiceAccount
metadata:
  name: admin-user
  namespace: kubernetes-dashboard
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: admin-user
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-admin
subjects:
- kind: ServiceAccount
  name: admin-user
  namespace: kubernetes-dashboard
EOF
        log_success "Dashboard installed"
    fi
    
    # Get access token
    log_info "Retrieving dashboard access token..."
    TOKEN=$(kubectl -n kubernetes-dashboard get secret \
        $(kubectl -n kubernetes-dashboard get sa admin-user -o jsonpath="{.secrets[0].name}" 2>/dev/null) \
        -o jsonpath="{.data.token}" 2>/dev/null | base64 -d 2>/dev/null || echo "")
    
    if [ -n "$TOKEN" ]; then
        log_success "Dashboard token retrieved"
        echo ""
        echo -e "${GREEN}Dashboard Access:${NC}"
        if [ "$K8S_CLUSTER_TYPE" == "minikube" ]; then
            echo "  URL: minikube dashboard"
            echo "  Or: http://localhost:8001/api/v1/namespaces/kubernetes-dashboard/services/https:kubernetes-dashboard:/proxy/"
        else
            echo "  URL: kubectl proxy then visit:"
            echo "  http://localhost:8001/api/v1/namespaces/kubernetes-dashboard/services/https:kubernetes-dashboard:/proxy/"
        fi
        echo -e "${GREEN}Token:${NC}"
        echo "  $TOKEN"
        echo ""
    else
        log_warning "Token not available yet. Get it with:"
        echo "  kubectl -n kubernetes-dashboard get secret \$(kubectl -n kubernetes-dashboard get sa admin-user -o jsonpath='{.secrets[0].name}') -o jsonpath='{.data.token}' | base64 -d"
    fi
    
    # Start proxy if not minikube
    if [ "$K8S_CLUSTER_TYPE" != "minikube" ]; then
        if ! pgrep -f "kubectl proxy" > /dev/null; then
            log_info "Starting kubectl proxy in background..."
            nohup kubectl proxy --port=8001 > /tmp/kubectl-proxy.log 2>&1 &
            sleep 2
            log_success "kubectl proxy started"
        fi
    fi
}

# Start Docker Compose services
start_compose() {
    log_step "Starting Docker Compose services..."
    
    # Create network
    if ! docker network inspect fks-network >/dev/null 2>&1; then
        log_info "Creating fks-network..."
        docker network create fks-network
    fi
    
    # Build and start services
    local services=("data" "api" "web" "ai" "execution" "monitor" "analyze" "app" "main" "portfolio")
    local failed_services=()
    local success_count=0
    
    for service in "${services[@]}"; do
        local service_dir="$REPO_DIR/$service"
        
        if [ ! -f "$service_dir/docker-compose.yml" ]; then
            log_warning "Skipping $service (no docker-compose.yml)"
            continue
        fi
        
        log_info "Starting $service..."
        cd "$service_dir" || continue
        
        if $DOCKER_COMPOSE_CMD up -d --build 2>&1; then
            log_success "$service started"
            success_count=$((success_count + 1))
        else
            log_error "$service failed to start"
            failed_services+=("$service")
        fi
    done
    
    echo ""
    log_success "Started: $success_count service(s)"
    if [ ${#failed_services[@]} -gt 0 ]; then
        log_warning "Failed: ${failed_services[*]}"
    fi
}

# Build Docker images for Kubernetes
build_k8s_images() {
    if [ "$BUILD_IMAGES" != "true" ]; then
        return 0
    fi
    
    log_step "Building Docker images for Kubernetes..."
    
    # Configure Docker for minikube if needed
    if [ "$K8S_CLUSTER_TYPE" == "minikube" ] && minikube status &> /dev/null; then
        eval $(minikube -p minikube docker-env)
        log_info "Docker configured for minikube"
    fi
    
    # Service definitions: service_name|image_name|dockerfile_path|context_dir
    declare -a SERVICES=(
        "main|nuniesmith/fks:main-latest|repo/main/Dockerfile|repo/main"
        "api|nuniesmith/fks:api-latest|repo/api/Dockerfile|repo/api"
        "app|nuniesmith/fks:app-latest|repo/app/Dockerfile|repo/app"
        "web|nuniesmith/fks:web-latest|repo/web/Dockerfile|repo/web"
        "ai|nuniesmith/fks:ai-latest|repo/ai/Dockerfile|repo/ai"
        "data|nuniesmith/fks:data-latest|repo/data/Dockerfile|repo/data"
        "execution|nuniesmith/fks:execution-latest|repo/execution/Dockerfile|repo/execution"
        "analyze|nuniesmith/fks:analyze-latest|repo/analyze/Dockerfile|repo/analyze"
        "monitor|nuniesmith/fks:monitor-latest|repo/monitor/Dockerfile|repo/monitor"
        "portfolio|nuniesmith/fks_portfolio:latest|repo/portfolio/Dockerfile|repo/portfolio"
    )
    
    local failed_services=()
    local success_count=0
    
    for service_info in "${SERVICES[@]}"; do
        IFS='|' read -r service_name image_name dockerfile context_dir <<< "$service_info"
        
        local dockerfile_path="$PROJECT_ROOT/$dockerfile"
        local context_path="$PROJECT_ROOT/$context_dir"
        
        if [ ! -f "$dockerfile_path" ] || [ ! -d "$context_path" ]; then
            log_warning "Skipping $service_name (missing files)"
            log_info "  Looking for: $dockerfile_path"
            log_info "  Context dir: $context_path"
            continue
        fi
        
        log_info "Building $service_name..."
        if docker build -f "$dockerfile_path" -t "$image_name" "$context_path" > /tmp/build-$service_name.log 2>&1; then
            log_success "$service_name built"
            success_count=$((success_count + 1))
        else
            log_error "$service_name build failed"
            tail -10 /tmp/build-$service_name.log | sed 's/^/  /'
            failed_services+=("$service_name")
        fi
    done
    
    echo ""
    log_success "Built: $success_count image(s)"
    if [ ${#failed_services[@]} -gt 0 ]; then
        log_warning "Failed: ${failed_services[*]}"
    fi
}

# Fix namespace issues
fix_namespace() {
    if [ "$FIX_NAMESPACE" != "true" ]; then
        return 0
    fi
    
    log_step "Fixing namespace issues..."
    
    # Check if namespace exists
    if ! kubectl get namespace "$NAMESPACE" &> /dev/null; then
        log_warning "Namespace $NAMESPACE does not exist"
        return 0
    fi
    
    # Fix secrets - add missing postgres-user
    if kubectl get secret fks-secrets -n "$NAMESPACE" &> /dev/null; then
        if ! kubectl get secret fks-secrets -n "$NAMESPACE" -o jsonpath='{.data.postgres-user}' &> /dev/null; then
            log_info "Adding missing postgres-user to secret..."
            local postgres_user_b64
            if command -v base64 >/dev/null 2>&1; then
                # Try with -w flag (GNU base64)
                postgres_user_b64=$(echo -n "fks_user" | base64 -w 0 2>/dev/null || echo -n "fks_user" | base64)
            else
                postgres_user_b64=$(echo -n "fks_user" | base64)
            fi
            kubectl patch secret fks-secrets -n "$NAMESPACE" --type='json' \
                -p="[{\"op\": \"add\", \"path\": \"/data/postgres-user\", \"value\": \"${postgres_user_b64}\"}]" 2>/dev/null || \
                log_warning "Could not add postgres-user automatically"
        fi
    fi
    
    # Clean up failed pods
    log_info "Cleaning up failed pods..."
    kubectl delete pods -n "$NAMESPACE" \
        --field-selector=status.phase!=Running,status.phase!=Succeeded \
        --ignore-not-found=true 2>/dev/null || true
    
    # Restart deployments
    log_info "Restarting deployments..."
    local deployments=("fks-main" "fks-api" "fks-app" "fks-data" "fks-ai" "fks-web" "celery-worker" "celery-beat" "flower")
    for deployment in "${deployments[@]}"; do
        if kubectl get deployment "$deployment" -n "$NAMESPACE" &> /dev/null; then
            kubectl rollout restart deployment "$deployment" -n "$NAMESPACE" &> /dev/null || true
        fi
    done
    
    log_success "Namespace fixes applied"
    
    # Wait a bit for pods to stabilize
    log_info "Waiting for pods to stabilize..."
    sleep 15
}

# Check namespace health
check_namespace_health() {
    log_step "Checking namespace health..."
    
    if ! kubectl get namespace "$NAMESPACE" &> /dev/null; then
        return 0
    fi
    
    local unhealthy=$(kubectl get pods -n "$NAMESPACE" --no-headers 2>/dev/null | grep -v Running | grep -v Completed | wc -l || echo "0")
    
    if [ "$unhealthy" -eq 0 ]; then
        log_success "All pods are healthy! 🎉"
    else
        log_warning "Found $unhealthy unhealthy pod(s)"
        kubectl get pods -n "$NAMESPACE" | grep -v Running | grep -v Completed | head -5
    fi
}

# Fix duplicate port issues in existing resources
fix_duplicate_ports() {
    log_step "Checking for duplicate port issues..."
    
    # Check for fks-main service with duplicate ports
    if kubectl get service fks-main -n "$NAMESPACE" &> /dev/null; then
        local ports_json=$(kubectl get service fks-main -n "$NAMESPACE" -o jsonpath='{.spec.ports[*].name}' 2>/dev/null || echo "")
        if [ -n "$ports_json" ]; then
            local port_count=$(echo "$ports_json" | tr ' ' '\n' | grep -c "^http$" || echo "0")
            if [ "$port_count" -gt 1 ]; then
                log_warning "Found duplicate 'http' ports in fks-main service, deleting to recreate..."
                kubectl delete service fks-main -n "$NAMESPACE" --ignore-not-found=true
                sleep 2
            fi
            # Also check if port number doesn't match expected (8010)
            local current_port=$(kubectl get service fks-main -n "$NAMESPACE" -o jsonpath='{.spec.ports[0].port}' 2>/dev/null || echo "")
            if [ -n "$current_port" ] && [ "$current_port" != "8010" ]; then
                log_warning "fks-main service has port $current_port but should be 8010, deleting to recreate..."
                kubectl delete service fks-main -n "$NAMESPACE" --ignore-not-found=true
                sleep 2
            fi
        fi
    fi
    
    # Check for fks-main deployment with duplicate ports
    if kubectl get deployment fks-main -n "$NAMESPACE" &> /dev/null; then
        local container_ports=$(kubectl get deployment fks-main -n "$NAMESPACE" -o jsonpath='{.spec.template.spec.containers[0].ports[*].name}' 2>/dev/null | tr ' ' '\n' | grep -c "^http$" || echo "0")
        if [ "$container_ports" -gt 1 ]; then
            log_warning "Found duplicate 'http' ports in fks-main deployment, deleting to recreate..."
            kubectl delete deployment fks-main -n "$NAMESPACE" --ignore-not-found=true
            # Wait for deletion
            kubectl wait --for=delete deployment/fks-main -n "$NAMESPACE" --timeout=60s 2>/dev/null || true
        fi
        # Also check if container port doesn't match expected (8010)
        local current_container_port=$(kubectl get deployment fks-main -n "$NAMESPACE" -o jsonpath='{.spec.template.spec.containers[0].ports[0].containerPort}' 2>/dev/null || echo "")
        if [ -n "$current_container_port" ] && [ "$current_container_port" != "8010" ]; then
            log_warning "fks-main deployment has containerPort $current_container_port but should be 8010, deleting to recreate..."
            kubectl delete deployment fks-main -n "$NAMESPACE" --ignore-not-found=true
            kubectl wait --for=delete deployment/fks-main -n "$NAMESPACE" --timeout=60s 2>/dev/null || true
        fi
    fi
}

# Start Kubernetes services
start_k8s() {
    log_step "Starting Kubernetes services..."
    
    # Setup cluster
    setup_k8s_cluster
    
    # Create namespace
    if ! kubectl get namespace "$NAMESPACE" &> /dev/null; then
        log_info "Creating namespace: $NAMESPACE"
        kubectl create namespace "$NAMESPACE"
    fi
    
    # Build images if requested
    if [ "$BUILD_IMAGES" == "true" ]; then
        build_k8s_images
    fi
    
    # Fix duplicate port issues before deploying
    fix_duplicate_ports
    
    # Deploy using Helm or manifests
    local chart_path="$PROJECT_ROOT/repo/main/k8s/charts/fks-platform"
    if [ -f "$chart_path/Chart.yaml" ]; then
        log_info "Deploying with Helm..."
        
        if helm list -n "$NAMESPACE" | grep -q "fks-platform"; then
            # Try upgrade, capture output and exit code
            local helm_output
            local helm_exit_code
            helm_output=$(helm upgrade fks-platform "$chart_path" \
                --namespace "$NAMESPACE" \
                -f "$chart_path/values.yaml" \
                --timeout 20m 2>&1)
            helm_exit_code=$?
            
            echo "$helm_output" | tee /tmp/helm-upgrade.log
            
            if [ $helm_exit_code -eq 0 ]; then
                log_success "Helm upgrade completed"
            else
                log_warning "Helm upgrade failed (exit code: $helm_exit_code)"
                if echo "$helm_output" | grep -q "Duplicate value.*http"; then
                    log_warning "Helm upgrade failed due to duplicate ports, attempting to fix..."
                    fix_duplicate_ports
                    sleep 5
                    # Retry upgrade
                    if helm upgrade fks-platform "$chart_path" \
                        --namespace "$NAMESPACE" \
                        -f "$chart_path/values.yaml" \
                        --timeout 20m 2>&1 | tee /tmp/helm-upgrade-retry.log; then
                        log_success "Helm upgrade completed after fixing duplicate ports"
                    else
                        log_error "Helm upgrade failed even after fixing duplicate ports"
                        log_error "Check /tmp/helm-upgrade-retry.log for details"
                    fi
                else
                    log_error "Helm upgrade failed for unknown reason"
                    log_error "Check /tmp/helm-upgrade.log for details"
                fi
            fi
        else
            helm install fks-platform "$chart_path" \
                --namespace "$NAMESPACE" \
                -f "$chart_path/values.yaml" \
                --create-namespace \
                --timeout 20m || log_warning "Helm install may have issues"
        fi
    else
        log_info "Deploying with Kubernetes manifests..."
        local manifests_dir="$PROJECT_ROOT/repo/main/k8s/manifests"
        if [ -f "$manifests_dir/all-services.yaml" ]; then
            kubectl apply -f "$manifests_dir/all-services.yaml" -n "$NAMESPACE"
        else
            log_error "No deployment files found"
            exit 1
        fi
    fi
    
    # Setup dashboard if requested
    setup_k8s_dashboard
    
    # Fix namespace if requested
    fix_namespace
    
    # Wait for pods
    log_info "Waiting for pods to be ready..."
    kubectl wait --for=condition=ready pod --all -n "$NAMESPACE" --timeout=300s 2>/dev/null || true
    
    # Check health
    check_namespace_health
    
    # Show status
    echo ""
    log_step "Deployment Status"
    kubectl get pods -n "$NAMESPACE"
    echo ""
    kubectl get svc -n "$NAMESPACE"
}

# Main function
main() {
    parse_args "$@"
    print_banner
    check_prerequisites
    
    if [ "$DEPLOYMENT_TYPE" == "compose" ]; then
        start_compose
    elif [ "$DEPLOYMENT_TYPE" == "k8s" ]; then
        start_k8s
    else
        log_error "Invalid deployment type: $DEPLOYMENT_TYPE"
        log_info "Use: compose or k8s"
        exit 1
    fi
    
    echo ""
    log_success "Startup complete! 🚀"
    echo ""
    
    if [ "$DEPLOYMENT_TYPE" == "k8s" ]; then
        log_info "Useful commands:"
        echo "  View pods:    kubectl get pods -n $NAMESPACE"
        echo "  View logs:   kubectl logs -n $NAMESPACE -l app=fks-web -f"
        echo "  Shell:       kubectl exec -n $NAMESPACE -it deployment/fks-web -- /bin/bash"
        if [ "$ENABLE_DASHBOARD" == "true" ] && [ "$K8S_CLUSTER_TYPE" == "minikube" ]; then
            echo "  Dashboard:   minikube dashboard"
        fi
    fi
}

# Run main
main "$@"
