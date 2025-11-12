#!/bin/bash
set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

PROJECT_ROOT="/home/jordan/Documents/code/fks"
DOCKER_DIR="$PROJECT_ROOT/docker"

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}FKS Docker Images Build Script${NC}"
echo -e "${BLUE}========================================${NC}"

cd $PROJECT_ROOT

# Build or pull images
build_image() {
    local service=$1
    local dockerfile=$2
    local tag=$3
    
    log_info "Building $service image..."
    
    if [ -f "$dockerfile" ]; then
        docker build -f "$dockerfile" -t "$tag" . || {
            log_error "Failed to build $service"
            return 1
        }
        log_success "$service image built: $tag"
        
        # Load into minikube
        if command -v minikube &> /dev/null && minikube status &> /dev/null; then
            log_info "Loading $service into minikube..."
            minikube image load "$tag"
            log_success "$service loaded into minikube"
        fi
    else
        log_warning "Dockerfile not found: $dockerfile"
        log_info "Attempting to pull from registry..."
        docker pull "$tag" || log_warning "Could not pull $tag"
    fi
}

# Web service (Django)
build_image "web" "$DOCKER_DIR/Dockerfile" "nuniesmith/fks:web-latest"

# API service
build_image "api" "$DOCKER_DIR/Dockerfile.api" "nuniesmith/fks:api-latest"

# App service  
build_image "app" "$DOCKER_DIR/Dockerfile.app" "nuniesmith/fks:app-latest"

# Data service
# Note: Dockerfile not found in docker/, may need to create or use base image
if [ ! -f "$DOCKER_DIR/Dockerfile.data" ]; then
    log_warning "Dockerfile.data not found, creating from base template..."
    cat > "$DOCKER_DIR/Dockerfile.data" <<'EOF'
FROM python:3.11-slim

WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y \
    gcc \
    postgresql-client \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Copy requirements
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy application code
COPY src/ ./src/
COPY manage.py .

# Expose port
EXPOSE 8003

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=40s --retries=3 \
    CMD curl -f http://localhost:8003/health || exit 1

# Run data service
CMD ["python", "-m", "uvicorn", "src.services.data.main:app", "--host", "0.0.0.0", "--port", "8003"]
EOF
fi

build_image "data" "$DOCKER_DIR/Dockerfile.data" "nuniesmith/fks:data-latest"

# AI service
if [ ! -f "$DOCKER_DIR/Dockerfile.ai" ]; then
    log_warning "Dockerfile.ai not found, creating from GPU template..."
    cp "$DOCKER_DIR/Dockerfile.gpu" "$DOCKER_DIR/Dockerfile.ai" 2>/dev/null || {
        cat > "$DOCKER_DIR/Dockerfile.ai" <<'EOF'
FROM python:3.11-slim

WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y \
    gcc \
    g++ \
    postgresql-client \
    curl \
    git \
    && rm -rf /var/lib/apt/lists/*

# Copy requirements (AI may need additional packages)
COPY requirements.txt requirements.dev.txt ./
RUN pip install --no-cache-dir -r requirements.txt -r requirements.dev.txt

# Copy application code
COPY src/ ./src/
COPY manage.py .

# Expose port
EXPOSE 8007

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD curl -f http://localhost:8007/health || exit 1

# Run AI service
CMD ["python", "-m", "uvicorn", "src.services.ai.main:app", "--host", "0.0.0.0", "--port", "8007"]
EOF
    }
fi

build_image "ai" "$DOCKER_DIR/Dockerfile.ai" "nuniesmith/fks:ai-latest"

# Execution service (already built from Phase 5)
log_info "Execution service using existing image or will be built separately"

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Docker Images Summary${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
docker images | grep -E "fks|nuniesmith"
echo ""

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Minikube Images${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
if command -v minikube &> /dev/null && minikube status &> /dev/null; then
    minikube image ls | grep fks || echo "No FKS images in minikube yet"
fi
echo ""

log_success "Docker images build complete! 🚀"
echo ""
echo "Next steps:"
echo "  1. Review images: docker images | grep fks"
echo "  2. Deploy to K8s: ./k8s/scripts/deploy-all-services.sh"
echo "  3. Monitor: kubectl get pods -n fks-trading -w"
