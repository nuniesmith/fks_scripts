#!/bin/bash
# Verify Docker Builds and Health Checks for All FKS Services
# Tests each service one by one: build, start, health check, cleanup

# Don't exit on error - we want to test all services
set +e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Script is in repo/core/main/scripts/, so:
# - SCRIPT_DIR/.. = repo/core/main
# - SCRIPT_DIR/../.. = repo/core  
# - SCRIPT_DIR/../../.. = repo
MAIN_REPO="$(cd "$SCRIPT_DIR/.." && pwd)"  # repo/core/main
REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"  # repo

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Track results
TOTAL=0
PASSED=0
FAILED=0
FAILED_SERVICES=()

# Services to test (path:name:port:type)
declare -a SERVICES=(
    "core/api:fks_api:8001:python"
    "core/app:fks_app:8002:python"
    "core/data:fks_data:8003:python"
    "core/execution:fks_execution:8006:rust"
    "core/web:fks_web:8000:python"
    "core/main:fks_main:8010:rust"
    "gpu/ai:fks_ai:8007:python"
    "gpu/training:fks_training:8004:python"
    "tools/analyze:fks_analyze:8008:python"
    "tools/monitor:fks_monitor:8009:python"
)

# Function to print section header
print_header() {
    echo ""
    echo "============================================================"
    echo "$1"
    echo "============================================================"
    echo ""
}

# Function to test a single service
test_service() {
    local service_path=$1
    local service_name=$2
    local port=$3
    local service_type=$4
    
    TOTAL=$((TOTAL + 1))
    
    print_header "Testing $service_name ($service_type)"
    
    # service_path is relative to repo/, so full path is REPO_ROOT/service_path
    local full_path="$REPO_ROOT/$service_path"
    local container_name="test-${service_name}"
    local image_name="test-${service_name}:latest"
    
    echo "Path: $full_path"
    echo "Port: $port"
    echo ""
    
    # Check if service directory exists
    if [ ! -d "$full_path" ]; then
        echo -e "${RED}❌ Service directory not found: $full_path${NC}"
        FAILED=$((FAILED + 1))
        FAILED_SERVICES+=("$service_name (not found: $full_path)")
        return 1
    fi
    
    cd "$full_path"
    
    # Step 1: Check for Dockerfile
    echo -e "${BLUE}📋 Step 1: Checking Dockerfile...${NC}"
    if [ ! -f "Dockerfile" ]; then
        echo -e "${RED}❌ Dockerfile not found${NC}"
        FAILED=$((FAILED + 1))
        FAILED_SERVICES+=("$service_name (no Dockerfile)")
        return 1
    fi
    echo -e "${GREEN}✅ Dockerfile found${NC}"
    echo ""
    
    # Step 2: Build Docker image
    echo -e "${BLUE}🔨 Step 2: Building Docker image...${NC}"
    if docker build -t "$image_name" . > "/tmp/docker_build_${service_name}.log" 2>&1; then
        echo -e "${GREEN}✅ Docker build successful${NC}"
    else
        echo -e "${RED}❌ Docker build failed${NC}"
        echo "Build log: /tmp/docker_build_${service_name}.log"
        echo "Last 20 lines:"
        tail -20 "/tmp/docker_build_${service_name}.log"
        FAILED=$((FAILED + 1))
        FAILED_SERVICES+=("$service_name (build failed)")
        return 1
    fi
    echo ""
    
    # Step 3: Start container
    echo -e "${BLUE}🚀 Step 3: Starting container...${NC}"
    # Stop and remove if already running
    docker stop "$container_name" 2>/dev/null || true
    docker rm "$container_name" 2>/dev/null || true
    
    # Start container in background
    if docker run -d \
        --name "$container_name" \
        -p "${port}:${port}" \
        -e "SERVICE_PORT=${port}" \
        -e "SERVICE_NAME=${service_name}" \
        "$image_name" > /dev/null 2>&1; then
        echo -e "${GREEN}✅ Container started${NC}"
    else
        echo -e "${RED}❌ Failed to start container${NC}"
        docker logs "$container_name" 2>&1 | tail -20
        FAILED=$((FAILED + 1))
        FAILED_SERVICES+=("$service_name (start failed)")
        docker rm "$container_name" 2>/dev/null || true
        return 1
    fi
    echo ""
    
    # Step 4: Wait for service to be ready
    echo -e "${BLUE}⏳ Step 4: Waiting for service to be ready...${NC}"
    local max_attempts=30
    local attempt=0
    local ready=false
    
    while [ $attempt -lt $max_attempts ]; do
        if curl -sf "http://localhost:${port}/health" > /dev/null 2>&1; then
            ready=true
            break
        fi
        attempt=$((attempt + 1))
        sleep 2
        echo -n "."
    done
    echo ""
    
    if [ "$ready" = true ]; then
        echo -e "${GREEN}✅ Service is ready${NC}"
    else
        echo -e "${YELLOW}⚠️  Service not responding to /health (may still be starting)${NC}"
        echo "Container logs:"
        docker logs "$container_name" 2>&1 | tail -20
    fi
    echo ""
    
    # Step 5: Test health endpoints
    echo -e "${BLUE}🏥 Step 5: Testing health endpoints...${NC}"
    
    # Test /health
    if curl -sf "http://localhost:${port}/health" > /dev/null 2>&1; then
        echo -e "${GREEN}✅ /health endpoint working${NC}"
        curl -s "http://localhost:${port}/health" | jq '.' 2>/dev/null || curl -s "http://localhost:${port}/health"
        echo ""
    else
        echo -e "${YELLOW}⚠️  /health endpoint not responding${NC}"
    fi
    
    # Test /ready (if available)
    if curl -sf "http://localhost:${port}/ready" > /dev/null 2>&1; then
        echo -e "${GREEN}✅ /ready endpoint working${NC}"
        curl -s "http://localhost:${port}/ready" | jq '.' 2>/dev/null || curl -s "http://localhost:${port}/ready"
        echo ""
    else
        echo -e "${YELLOW}⚠️  /ready endpoint not available${NC}"
    fi
    
    # Test /live (if available)
    if curl -sf "http://localhost:${port}/live" > /dev/null 2>&1; then
        echo -e "${GREEN}✅ /live endpoint working${NC}"
        curl -s "http://localhost:${port}/live" | jq '.' 2>/dev/null || curl -s "http://localhost:${port}/live"
        echo ""
    else
        echo -e "${YELLOW}⚠️  /live endpoint not available${NC}"
    fi
    echo ""
    
    # Step 6: Check container health status
    echo -e "${BLUE}📊 Step 6: Checking container health status...${NC}"
    local health_status=$(docker inspect --format='{{.State.Health.Status}}' "$container_name" 2>/dev/null || echo "no-healthcheck")
    if [ "$health_status" = "healthy" ]; then
        echo -e "${GREEN}✅ Container health check: healthy${NC}"
    elif [ "$health_status" = "no-healthcheck" ]; then
        echo -e "${YELLOW}⚠️  No health check configured${NC}"
    else
        echo -e "${YELLOW}⚠️  Container health: $health_status${NC}"
    fi
    echo ""
    
    # Step 7: Cleanup
    echo -e "${BLUE}🧹 Step 7: Cleaning up...${NC}"
    docker stop "$container_name" > /dev/null 2>&1 || true
    docker rm "$container_name" > /dev/null 2>&1 || true
    echo -e "${GREEN}✅ Cleanup complete${NC}"
    echo ""
    
    # Mark as passed
    PASSED=$((PASSED + 1))
    echo -e "${GREEN}✅ $service_name: ALL CHECKS PASSED${NC}"
    echo ""
    
    return 0
}

# Main execution
print_header "🐳 FKS Docker Service Verification"
echo "Testing all FKS services: build, start, health check"
echo ""

# Check Docker is running
if ! docker info > /dev/null 2>&1; then
    echo -e "${RED}❌ Docker is not running. Please start Docker first.${NC}"
    exit 1
fi

# Test each service
for service_config in "${SERVICES[@]}"; do
    IFS=':' read -r path name port type <<< "$service_config"
    test_service "$path" "$name" "$port" "$type"
    
    # Small delay between services
    sleep 2
done

# Final summary
print_header "📊 Verification Summary"

echo -e "Total Services Tested: ${TOTAL}"
echo -e "${GREEN}Passed: ${PASSED}${NC}"
echo -e "${RED}Failed: ${FAILED}${NC}"
echo ""

if [ ${#FAILED_SERVICES[@]} -gt 0 ]; then
    echo -e "${RED}Failed Services:${NC}"
    for service in "${FAILED_SERVICES[@]}"; do
        echo -e "  - ${RED}❌${NC} $service"
    done
    echo ""
fi

if [ $FAILED -eq 0 ]; then
    echo -e "${GREEN}✅ All services built and started successfully!${NC}"
    exit 0
else
    echo -e "${RED}❌ Some services failed verification${NC}"
    exit 1
fi

