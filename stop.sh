#!/bin/bash
# FKS Trading Platform - Unified Stop Script
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
REMOVE_VOLUMES=false
REMOVE_NETWORK=false
CLEAN_ALL=false

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
    echo -e "${CYAN}║  FKS Trading Platform - Stop                  ║${NC}"
    echo -e "${CYAN}║  Deployment Type: ${DEPLOYMENT_TYPE^^}${NC}$(printf '%*s' $((25-${#DEPLOYMENT_TYPE})) '')║"
    echo -e "${CYAN}╚═══════════════════════════════════════════════╝${NC}"
    echo ""
}

# Show usage
show_usage() {
    cat << EOF
FKS Trading Platform - Unified Stop Script

Usage: $0 [OPTIONS]

OPTIONS:
    -t, --type TYPE          Deployment type: compose or k8s (default: compose)
    -v, --volumes            Remove volumes (compose only)
    -n, --namespace NAME     Kubernetes namespace (default: fks-trading)
    -a, --all                Remove everything including volumes/namespace
    -c, --clean              Clean all resources (k8s: delete namespace)
    -h, --help               Show this help message

ENVIRONMENT VARIABLES:
    DEPLOYMENT_TYPE          Set default deployment type (compose|k8s)
    NAMESPACE                Kubernetes namespace

EXAMPLES:
    # Stop Docker Compose services
    $0 --type compose
    $0 --type compose --volumes

    # Stop Kubernetes services
    $0 --type k8s
    $0 --type k8s --clean

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
            -v|--volumes)
                REMOVE_VOLUMES=true
                shift
                ;;
            -n|--namespace)
                NAMESPACE="$2"
                shift 2
                ;;
            -a|--all)
                REMOVE_VOLUMES=true
                REMOVE_NETWORK=true
                CLEAN_ALL=true
                shift
                ;;
            -c|--clean)
                CLEAN_ALL=true
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

# Stop Docker Compose services
stop_compose() {
    log_step "Stopping Docker Compose services..."
    
    local services=("data" "api" "web" "ai" "execution" "monitor" "analyze" "app" "main" "portfolio")
    local failed_services=()
    local success_count=0
    
    # Detect docker-compose command
    if docker compose version >/dev/null 2>&1; then
        DOCKER_COMPOSE_CMD="docker compose"
    elif command -v docker-compose >/dev/null 2>&1; then
        DOCKER_COMPOSE_CMD="docker-compose"
    else
        log_error "Docker Compose not found"
        exit 1
    fi
    
    for service in "${services[@]}"; do
        local service_dir="$REPO_DIR/$service"
        
        if [ ! -f "$service_dir/docker-compose.yml" ]; then
            continue
        fi
        
        log_info "Stopping $service..."
        cd "$service_dir" || continue
        
        local cmd="$DOCKER_COMPOSE_CMD down"
        if [ "$REMOVE_VOLUMES" == "true" ]; then
            cmd="$cmd -v"
        fi
        
        if eval "$cmd" 2>&1; then
            log_success "$service stopped"
                success_count=$((success_count + 1))
            else
            log_error "$service failed to stop"
                failed_services+=("$service")
        fi
    done
    
    # Remove network if requested
    if [ "$REMOVE_NETWORK" == "true" ]; then
        if docker network inspect fks-network >/dev/null 2>&1; then
            log_info "Removing fks-network..."
            docker network rm fks-network && log_success "Network removed" || log_warning "Network may have active containers"
        fi
    fi
    
    echo ""
    log_success "Stopped: $success_count service(s)"
    if [ ${#failed_services[@]} -gt 0 ]; then
        log_warning "Failed: ${failed_services[*]}"
    fi
}

# Stop Kubernetes services
stop_k8s() {
    log_step "Stopping Kubernetes services..."
    
    # Check if namespace exists
    if ! kubectl get namespace "$NAMESPACE" &> /dev/null; then
        log_warning "Namespace $NAMESPACE does not exist"
        return 0
    fi
    
    # Uninstall Helm release if exists
    if command -v helm &> /dev/null && helm list -n "$NAMESPACE" 2>/dev/null | grep -q "fks-platform"; then
        log_info "Uninstalling Helm release..."
        helm uninstall fks-platform -n "$NAMESPACE" || log_warning "Helm uninstall may have issues"
    fi
    
    # Delete all resources in namespace
    log_info "Deleting resources in namespace $NAMESPACE..."
    kubectl delete all --all -n "$NAMESPACE" --ignore-not-found=true
    
    # Delete PVCs if cleaning
    if [ "$CLEAN_ALL" == "true" ]; then
        log_info "Deleting persistent volume claims..."
        kubectl delete pvc --all -n "$NAMESPACE" --ignore-not-found=true
        
        # Delete secrets
        log_info "Deleting secrets..."
        kubectl delete secret --all -n "$NAMESPACE" --ignore-not-found=true
        
        # Delete configmaps
        log_info "Deleting configmaps..."
        kubectl delete configmap --all -n "$NAMESPACE" --ignore-not-found=true
    fi
    
    # Delete namespace if cleaning
    if [ "$CLEAN_ALL" == "true" ]; then
        log_info "Deleting namespace $NAMESPACE..."
        kubectl delete namespace "$NAMESPACE" --ignore-not-found=true
        log_success "Namespace deleted"
    else
        log_success "Services stopped (namespace preserved)"
        log_info "To remove namespace: $0 --type k8s --clean"
    fi
    
    # Stop kubectl proxy if running
    if pgrep -f "kubectl proxy" > /dev/null; then
        log_info "Stopping kubectl proxy..."
        pkill -f "kubectl proxy"
        log_success "Proxy stopped"
    fi
}

# Main function
main() {
    parse_args "$@"
    print_banner
    
    if [ "$DEPLOYMENT_TYPE" == "compose" ]; then
        stop_compose
    elif [ "$DEPLOYMENT_TYPE" == "k8s" ]; then
        stop_k8s
    else
        log_error "Invalid deployment type: $DEPLOYMENT_TYPE"
        log_info "Use: compose or k8s"
        exit 1
    fi
    
    echo ""
    log_success "Stop complete! ✅"
    echo ""
}

# Run main
main "$@"
