#!/bin/bash
# Verify a single Docker service: build, start, health check, cleanup
# Usage: ./verify_single_service.sh <service_path> <service_name> <port> <type>
# Example: ./verify_single_service.sh core/api fks_api 8001 python

set +e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Parse arguments
SERVICE_PATH=${1:-"core/api"}
SERVICE_NAME=${2:-"fks_api"}
PORT=${3:-"8001"}
SERVICE_TYPE=${4:-"python"}

print_header() {
    echo ""
    echo "============================================================"
    echo "$1"
    echo "============================================================"
    echo ""
}

print_header "Testing $SERVICE_NAME ($SERVICE_TYPE)"

FULL_PATH="$REPO_ROOT/$SERVICE_PATH"
CONTAINER_NAME="test-${SERVICE_NAME}"
IMAGE_NAME="test-${SERVICE_NAME}:latest"

echo "Path: $FULL_PATH"
echo "Port: $PORT"
echo ""

# Check if service directory exists
if [ ! -d "$FULL_PATH" ]; then
    echo -e "${RED}❌ Service directory not found: $FULL_PATH${NC}"
    exit 1
fi

cd "$FULL_PATH"

# Step 1: Check for Dockerfile
echo -e "${BLUE}📋 Step 1: Checking Dockerfile...${NC}"
if [ ! -f "Dockerfile" ]; then
    echo -e "${RED}❌ Dockerfile not found${NC}"
    exit 1
fi
echo -e "${GREEN}✅ Dockerfile found${NC}"
echo ""

# Step 2: Build Docker image
echo -e "${BLUE}🔨 Step 2: Building Docker image...${NC}"
if docker build -t "$IMAGE_NAME" . > "/tmp/docker_build_${SERVICE_NAME}.log" 2>&1; then
    echo -e "${GREEN}✅ Docker build successful${NC}"
else
    echo -e "${RED}❌ Docker build failed${NC}"
    echo "Build log: /tmp/docker_build_${SERVICE_NAME}.log"
    echo "Last 30 lines:"
    tail -30 "/tmp/docker_build_${SERVICE_NAME}.log"
    exit 1
fi
echo ""

# Step 3: Start container
echo -e "${BLUE}🚀 Step 3: Starting container...${NC}"
docker stop "$CONTAINER_NAME" 2>/dev/null || true
docker rm "$CONTAINER_NAME" 2>/dev/null || true

if docker run -d \
    --name "$CONTAINER_NAME" \
    -p "${PORT}:${PORT}" \
    -e "SERVICE_PORT=${PORT}" \
    -e "SERVICE_NAME=${SERVICE_NAME}" \
    "$IMAGE_NAME" > /dev/null 2>&1; then
    echo -e "${GREEN}✅ Container started${NC}"
else
    echo -e "${RED}❌ Failed to start container${NC}"
    docker logs "$CONTAINER_NAME" 2>&1 | tail -20
    docker rm "$CONTAINER_NAME" 2>/dev/null || true
    exit 1
fi
echo ""

# Step 4: Wait for service to be ready
echo -e "${BLUE}⏳ Step 4: Waiting for service to be ready...${NC}"
MAX_ATTEMPTS=30
ATTEMPT=0
READY=false

while [ $ATTEMPT -lt $MAX_ATTEMPTS ]; do
    if curl -sf "http://localhost:${PORT}/health" > /dev/null 2>&1; then
        READY=true
        break
    fi
    ATTEMPT=$((ATTEMPT + 1))
    sleep 2
    echo -n "."
done
echo ""

if [ "$READY" = true ]; then
    echo -e "${GREEN}✅ Service is ready${NC}"
else
    echo -e "${YELLOW}⚠️  Service not responding to /health${NC}"
    echo "Container logs:"
    docker logs "$CONTAINER_NAME" 2>&1 | tail -30
fi
echo ""

# Step 5: Test health endpoints
echo -e "${BLUE}🏥 Step 5: Testing health endpoints...${NC}"

# Test /health
if curl -sf "http://localhost:${PORT}/health" > /dev/null 2>&1; then
    echo -e "${GREEN}✅ /health endpoint working${NC}"
    curl -s "http://localhost:${PORT}/health" | jq '.' 2>/dev/null || curl -s "http://localhost:${PORT}/health"
    echo ""
else
    echo -e "${YELLOW}⚠️  /health endpoint not responding${NC}"
fi

# Test /ready (if available)
if curl -sf "http://localhost:${PORT}/ready" > /dev/null 2>&1; then
    echo -e "${GREEN}✅ /ready endpoint working${NC}"
    curl -s "http://localhost:${PORT}/ready" | jq '.' 2>/dev/null || curl -s "http://localhost:${PORT}/ready"
    echo ""
else
    echo -e "${YELLOW}⚠️  /ready endpoint not available${NC}"
fi

# Test /live (if available)
if curl -sf "http://localhost:${PORT}/live" > /dev/null 2>&1; then
    echo -e "${GREEN}✅ /live endpoint working${NC}"
    curl -s "http://localhost:${PORT}/live" | jq '.' 2>/dev/null || curl -s "http://localhost:${PORT}/live"
    echo ""
else
    echo -e "${YELLOW}⚠️  /live endpoint not available${NC}"
fi
echo ""

# Step 6: Check container health status
echo -e "${BLUE}📊 Step 6: Checking container health status...${NC}"
HEALTH_STATUS=$(docker inspect --format='{{.State.Health.Status}}' "$CONTAINER_NAME" 2>/dev/null || echo "no-healthcheck")
if [ "$HEALTH_STATUS" = "healthy" ]; then
    echo -e "${GREEN}✅ Container health check: healthy${NC}"
elif [ "$HEALTH_STATUS" = "no-healthcheck" ]; then
    echo -e "${YELLOW}⚠️  No health check configured${NC}"
else
    echo -e "${YELLOW}⚠️  Container health: $HEALTH_STATUS${NC}"
fi
echo ""

# Step 7: Cleanup
echo -e "${BLUE}🧹 Step 7: Cleaning up...${NC}"
docker stop "$CONTAINER_NAME" > /dev/null 2>&1 || true
docker rm "$CONTAINER_NAME" > /dev/null 2>&1 || true
echo -e "${GREEN}✅ Cleanup complete${NC}"
echo ""

if [ "$READY" = true ]; then
    echo -e "${GREEN}✅ $SERVICE_NAME: ALL CHECKS PASSED${NC}"
    exit 0
else
    echo -e "${RED}❌ $SERVICE_NAME: FAILED${NC}"
    exit 1
fi

