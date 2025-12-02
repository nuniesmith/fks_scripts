#!/bin/bash
# Stability Test Health Check Script
# Checks health status of all FKS services

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Services to check
SERVICES=(
    "fks_app:8002"
    "fks_data:8003"
    "fks_web:8004"
    "fks_ai:8001"
    "fks_portfolio:8012"
)

# Results
HEALTHY_COUNT=0
UNHEALTHY_COUNT=0
UNHEALTHY_SERVICES=()

echo "======================================"
echo "Stability Test Health Check"
echo "======================================"
echo "Timestamp: $(date '+%Y-%m-%d %H:%M:%S')"
echo ""

# Check each service
for service_entry in "${SERVICES[@]}"; do
    name=$(echo $service_entry | cut -d: -f1)
    port=$(echo $service_entry | cut -d: -f2)
    
    # Check if container is running
    if ! docker ps --format '{{.Names}}' | grep -q "^${name}$"; then
        echo -e "${RED}❌ $name (port $port): CONTAINER NOT RUNNING${NC}"
        UNHEALTHY_COUNT=$((UNHEALTHY_COUNT + 1))
        UNHEALTHY_SERVICES+=("$name")
        continue
    fi
    
    # Check health endpoint
    if curl -s -f -m 5 "http://localhost:$port/health" > /dev/null 2>&1; then
        echo -e "${GREEN}✅ $name (port $port): HEALTHY${NC}"
        HEALTHY_COUNT=$((HEALTHY_COUNT + 1))
    else
        echo -e "${RED}❌ $name (port $port): HEALTH CHECK FAILED${NC}"
        UNHEALTHY_COUNT=$((UNHEALTHY_COUNT + 1))
        UNHEALTHY_SERVICES+=("$name")
    fi
done

echo ""
echo "======================================"
echo "Summary"
echo "======================================"
echo "Healthy: $HEALTHY_COUNT"
echo "Unhealthy: $UNHEALTHY_COUNT"
echo "Total: ${#SERVICES[@]}"

if [ $UNHEALTHY_COUNT -gt 0 ]; then
    echo ""
    echo -e "${RED}Unhealthy Services:${NC}"
    for service in "${UNHEALTHY_SERVICES[@]}"; do
        echo "  - $service"
    done
    exit 1
else
    echo ""
    echo -e "${GREEN}All services are healthy!${NC}"
    exit 0
fi

