#!/bin/bash
# FKS Trading Platform - Build and Start All Services
# This script builds Docker images for all FKS services and starts them
# Run from repo/main directory

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Configuration
# Resolve symlink to actual script location (allows running from root via symlink)
SCRIPT_SOURCE="${BASH_SOURCE[0]}"
while [ -L "$SCRIPT_SOURCE" ]; do
    SCRIPT_SOURCE="$(readlink -f "$SCRIPT_SOURCE")"
done
SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_SOURCE")" && pwd)"
# FKS_ROOT is the directory containing the repo/ directory (two levels up from repo/main)
FKS_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
REPO_DIR="$FKS_ROOT/repo"
DOCKER_USERNAME="${DOCKER_USERNAME:-nuniesmith}"
IMAGE_TAG="${IMAGE_TAG:-latest}"

# All FKS services
SERVICES=(
    "ai"
    "analyze"
    "api"
    "app"
    "auth"
    "data"
    "execution"
    "main"
    "meta"
    "monitor"
    "portfolio"
    "ninja"
    "training"
    "web"
)

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
    echo -e "${CYAN}║  FKS Trading Platform - Build All Services    ║${NC}"
    echo -e "${CYAN}╚═══════════════════════════════════════════════╝${NC}"
    echo ""
}

# Check prerequisites
check_prerequisites() {
    log_step "Checking prerequisites..."
    
    if ! command -v docker &> /dev/null; then
        log_error "Docker is not installed"
        exit 1
    fi
    
    if ! docker info &> /dev/null; then
        log_error "Docker daemon is not running"
        exit 1
    fi
    
    log_success "Prerequisites check passed"
}

# Build a single service
build_service() {
    local service=$1
    local service_dir="$REPO_DIR/$service"
    local image_name="$DOCKER_USERNAME/fks:$service-$IMAGE_TAG"
    
    if [ ! -d "$service_dir" ]; then
        log_warning "Service directory not found: $service_dir"
        return 1
    fi
    
    log_info "Building $service..."
    cd "$service_dir"
    
    # Check for Dockerfile
    if [ ! -f "Dockerfile" ]; then
        log_warning "No Dockerfile found for $service, skipping..."
        return 1
    fi
    
    # Build the image
    if docker build -t "$image_name" .; then
        log_success "✓ Built $service: $image_name"
        
        # Load into minikube if available
        if command -v minikube &> /dev/null && minikube status &> /dev/null 2>&1; then
            log_info "Loading $service into minikube..."
            minikube image load "$image_name" || log_warning "Failed to load into minikube"
        fi
        
        return 0
    else
        log_error "✗ Failed to build $service"
        return 1
    fi
}

# Build all services
build_all_services() {
    log_step "Building all FKS services..."
    
    local failed_services=()
    local successful_services=()
    
    for service in "${SERVICES[@]}"; do
        if build_service "$service"; then
            successful_services+=("$service")
        else
            failed_services+=("$service")
        fi
    done
    
    echo ""
    log_step "Build Summary"
    echo "=========================================="
    
    if [ ${#successful_services[@]} -gt 0 ]; then
        log_success "Successfully built (${#successful_services[@]}):"
        for svc in "${successful_services[@]}"; do
            echo "  ✓ $svc"
        done
    fi
    
    if [ ${#failed_services[@]} -gt 0 ]; then
        log_error "Failed to build (${#failed_services[@]}):"
        for svc in "${failed_services[@]}"; do
            echo "  ✗ $svc"
        done
        return 1
    fi
    
    return 0
}

# Start all services using Docker Compose
start_all_compose() {
    log_step "Starting all services with Docker Compose..."
    
    # Check if we should use the unified start script
    if [ -f "$FKS_ROOT/start.sh" ]; then
        log_info "Using unified start script..."
        cd "$FKS_ROOT"
        ./start.sh --type compose
    else
        log_warning "Unified start script not found, starting services individually..."
        # Start each service's docker-compose
        for service in "${SERVICES[@]}"; do
            local service_dir="$REPO_DIR/$service"
            if [ -f "$service_dir/docker-compose.yml" ]; then
                log_info "Starting $service..."
                cd "$service_dir"
                docker-compose up -d || log_warning "Failed to start $service"
            fi
        done
    fi
}

# Start all services using Kubernetes
start_all_k8s() {
    log_step "Starting all services with Kubernetes..."
    
    if [ -f "$FKS_ROOT/start.sh" ]; then
        log_info "Using unified start script..."
        cd "$FKS_ROOT"
        ./start.sh --type k8s --build-images
    else
        log_error "Unified start script not found"
        return 1
    fi
}

# Show usage
show_usage() {
    cat << EOF
FKS Trading Platform - Build and Start All Services

Usage: $0 [OPTIONS] [COMMAND]

COMMANDS:
    build           Build Docker images for all services
    start           Start all services (Docker Compose)
    start-k8s       Start all services (Kubernetes)
    build-start     Build and start all services (Docker Compose)
    build-start-k8s Build and start all services (Kubernetes)
    help            Show this help message

OPTIONS:
    --tag TAG       Docker image tag (default: latest)
    --user USER     Docker username (default: nuniesmith)
    --services      Comma-separated list of services to build/start
    -h, --help      Show this help message

ENVIRONMENT VARIABLES:
    DOCKER_USERNAME Docker username (default: nuniesmith)
    IMAGE_TAG       Docker image tag (default: latest)

EXAMPLES:
    # Build all services
    $0 build

    # Build and start with Docker Compose
    $0 build-start

    # Build and start with Kubernetes
    $0 build-start-k8s

    # Build specific services
    $0 build --services api,web,data

    # Custom tag
    $0 build --tag v1.0.0

EOF
}

# Parse arguments
parse_args() {
    COMMAND=""
    SERVICES_FILTER=""
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            build|start|start-k8s|build-start|build-start-k8s)
                COMMAND="$1"
                shift
                ;;
            --tag)
                IMAGE_TAG="$2"
                shift 2
                ;;
            --user)
                DOCKER_USERNAME="$2"
                shift 2
                ;;
            --services)
                SERVICES_FILTER="$2"
                shift 2
                ;;
            -h|--help|help)
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
    
    # Filter services if specified
    if [ -n "$SERVICES_FILTER" ]; then
        IFS=',' read -ra FILTERED <<< "$SERVICES_FILTER"
        SERVICES=("${FILTERED[@]}")
    fi
}

# Main function
main() {
    print_banner
    check_prerequisites
    parse_args "$@"
    
    case "$COMMAND" in
        build)
            build_all_services
            ;;
        start)
            start_all_compose
            ;;
        start-k8s)
            start_all_k8s
            ;;
        build-start)
            build_all_services && start_all_compose
            ;;
        build-start-k8s)
            build_all_services && start_all_k8s
            ;;
        "")
            log_error "No command specified"
            show_usage
            exit 1
            ;;
        *)
            log_error "Unknown command: $COMMAND"
            show_usage
            exit 1
            ;;
    esac
}

# Run main (change to FKS_ROOT for consistency)
cd "$FKS_ROOT"
main "$@"

