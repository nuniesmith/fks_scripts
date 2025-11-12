#!/bin/bash
# Build all optimized Docker images for FKS services

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"

echo "=========================================="
echo "FKS Docker Image Optimization Build"
echo "=========================================="
echo ""

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if shared base should be used
USE_SHARED_BASE=${1:-false}

if [ "$USE_SHARED_BASE" = "true" ] || [ "$USE_SHARED_BASE" = "shared" ]; then
    echo -e "${YELLOW}Building with shared base image...${NC}"
    echo ""
    
    # Check if base image exists
    if ! docker image inspect nuniesmith/fks:builder-base >/dev/null 2>&1; then
        echo "Shared base image not found. Building it first..."
        cd "$REPO_ROOT/repo/docker-base"
        docker build -t nuniesmith/fks:builder-base -f Dockerfile.builder .
        echo -e "${GREEN}✅ Base image built${NC}"
        echo ""
    else
        echo -e "${GREEN}✅ Using existing base image${NC}"
        echo ""
    fi
    
    DOCKERFILE_SUFFIX="optimized-shared"
else
    echo -e "${YELLOW}Building standalone optimized images...${NC}"
    echo ""
    DOCKERFILE_SUFFIX="optimized"
fi

# Build training service
echo "Building training service..."
cd "$REPO_ROOT/repo/training"
if [ -f "Dockerfile.$DOCKERFILE_SUFFIX" ]; then
    docker build -f "Dockerfile.$DOCKERFILE_SUFFIX" -t fks_training:optimized .
    echo -e "${GREEN}✅ Training service built${NC}"
else
    echo -e "${YELLOW}⚠️  Dockerfile.$DOCKERFILE_SUFFIX not found, skipping${NC}"
fi
echo ""

# Build AI service
echo "Building AI service..."
cd "$REPO_ROOT/repo/ai"
if [ -f "Dockerfile.$DOCKERFILE_SUFFIX" ]; then
    docker build -f "Dockerfile.$DOCKERFILE_SUFFIX" -t fks_ai:optimized .
    echo -e "${GREEN}✅ AI service built${NC}"
else
    echo -e "${YELLOW}⚠️  Dockerfile.$DOCKERFILE_SUFFIX not found, using standalone${NC}"
    docker build -f Dockerfile.optimized -t fks_ai:optimized .
    echo -e "${GREEN}✅ AI service built${NC}"
fi
echo ""

# Build analyze service
echo "Building analyze service..."
cd "$REPO_ROOT/repo/analyze"
docker build -f Dockerfile.optimized -t fks_analyze:optimized .
echo -e "${GREEN}✅ Analyze service built${NC}"
echo ""

# Show image sizes
echo "=========================================="
echo "Image Sizes:"
echo "=========================================="
docker images --format "table {{.Repository}}\t{{.Tag}}\t{{.Size}}" | grep -E "(fks_|REPOSITORY)" | head -5
echo ""

echo -e "${GREEN}✅ All optimized images built successfully!${NC}"

