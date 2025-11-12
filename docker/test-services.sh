#!/bin/bash
# Test optimized Docker images

set -e

echo "=========================================="
echo "Testing FKS Optimized Docker Images"
echo "=========================================="
echo ""

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Function to test a service
test_service() {
    local service=$1
    local port=$2
    local image=$3
    
    echo -e "${YELLOW}Testing $service on port $port...${NC}"
    
    # Start container
    CONTAINER_ID=$(docker run -d -p $port:$port --name "fks_${service}_test" "$image" 2>&1)
    
    if [ $? -ne 0 ]; then
        echo -e "${RED}❌ Failed to start $service container${NC}"
        echo "$CONTAINER_ID"
        return 1
    fi
    
    echo "Container started: $CONTAINER_ID"
    
    # Wait for service to start
    echo "Waiting for service to be ready..."
    sleep 5
    
    # Test health endpoint
    for i in {1..10}; do
        if curl -f -s "http://localhost:$port/health" >/dev/null 2>&1; then
            echo -e "${GREEN}✅ $service is healthy!${NC}"
            
            # Show health response
            echo "Health check response:"
            curl -s "http://localhost:$port/health" | python3 -m json.tool 2>/dev/null || curl -s "http://localhost:$port/health"
            echo ""
            
            # Cleanup
            docker stop "fks_${service}_test" >/dev/null 2>&1
            docker rm "fks_${service}_test" >/dev/null 2>&1
            return 0
        fi
        echo "  Attempt $i/10: Waiting..."
        sleep 2
    done
    
    echo -e "${RED}❌ $service failed to become healthy${NC}"
    echo "Container logs:"
    docker logs "fks_${service}_test" 2>&1 | tail -20
    docker stop "fks_${service}_test" >/dev/null 2>&1
    docker rm "fks_${service}_test" >/dev/null 2>&1
    return 1
}

# Test services
FAILED=0

test_service "training" "8005" "fks_training:optimized" || FAILED=1
test_service "ai" "8007" "fks_ai:optimized" || FAILED=1
test_service "analyze" "8008" "fks_analyze:optimized" || FAILED=1

echo "=========================================="
if [ $FAILED -eq 0 ]; then
    echo -e "${GREEN}✅ All services tested successfully!${NC}"
    exit 0
else
    echo -e "${RED}❌ Some services failed tests${NC}"
    exit 1
fi

