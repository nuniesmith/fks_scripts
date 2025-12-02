#!/bin/bash
# Verify all FKS services health endpoints and status
# Usage: ./verify_all_services.sh [--docker|--k8s]

set -e

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Service registry
SERVICE_REGISTRY="/home/jordan/Nextcloud/code/repos/fks/infrastructure/config/service_registry.json"

# Check if service registry exists
if [ ! -f "$SERVICE_REGISTRY" ]; then
    echo -e "${RED}Error: Service registry not found at $SERVICE_REGISTRY${NC}"
    exit 1
fi

# Parse service registry
echo -e "${BLUE}=== FKS Service Health Verification ===${NC}\n"

# Function to check service health
check_service() {
    local service_name=$1
    local health_url=$2
    local port=$3
    
    echo -n "Checking $service_name (port $port)... "
    
    # Try to connect to health endpoint
    if curl -sf --max-time 5 "$health_url" > /dev/null 2>&1; then
        echo -e "${GREEN}✓ HEALTHY${NC}"
        return 0
    else
        echo -e "${RED}✗ UNHEALTHY or UNAVAILABLE${NC}"
        return 1
    fi
}

# Function to check service in Docker
check_service_docker() {
    local service_name=$1
    local container_name="fks-${service_name#fks_}"
    
    echo -n "Checking $service_name (Docker: $container_name)... "
    
    if docker ps --format '{{.Names}}' | grep -q "^${container_name}$"; then
        if docker inspect --format='{{.State.Status}}' "$container_name" | grep -q "running"; then
            echo -e "${GREEN}✓ RUNNING${NC}"
            return 0
        else
            echo -e "${YELLOW}⚠ EXISTS but not running${NC}"
            return 1
        fi
    else
        echo -e "${RED}✗ NOT FOUND${NC}"
        return 1
    fi
}

# Extract services from registry
services=$(jq -r '.services | keys[]' "$SERVICE_REGISTRY" 2>/dev/null || echo "")

if [ -z "$services" ]; then
    echo -e "${RED}Error: Could not parse service registry${NC}"
    exit 1
fi

# Counters
total=0
healthy=0
unhealthy=0

echo -e "${BLUE}Service Health Status:${NC}\n"

# Check each service
for service in $services; do
    port=$(jq -r ".services[\"$service\"].port" "$SERVICE_REGISTRY" 2>/dev/null)
    health_url=$(jq -r ".services[\"$service\"].health_url" "$SERVICE_REGISTRY" 2>/dev/null)
    
    if [ "$port" != "null" ] && [ "$health_url" != "null" ]; then
        total=$((total + 1))
        if check_service "$service" "$health_url" "$port"; then
            healthy=$((healthy + 1))
        else
            unhealthy=$((unhealthy + 1))
        fi
    fi
done

echo ""
echo -e "${BLUE}=== Summary ===${NC}"
echo -e "Total services: $total"
echo -e "${GREEN}Healthy: $healthy${NC}"
echo -e "${RED}Unhealthy/Unavailable: $unhealthy${NC}"

# Docker status check
if command -v docker > /dev/null 2>&1; then
    echo ""
    echo -e "${BLUE}=== Docker Container Status ===${NC}\n"
    
    for service in $services; do
        service_short="${service#fks_}"
        check_service_docker "$service" "$service_short"
    done
fi

echo ""
echo -e "${BLUE}=== Service Dependencies ===${NC}\n"

# Show dependencies
for service in $services; do
    deps=$(jq -r ".services[\"$service\"].dependencies[]?" "$SERVICE_REGISTRY" 2>/dev/null | tr '\n' ', ' | sed 's/, $//')
    if [ -n "$deps" ]; then
        echo -e "${service}: ${YELLOW}depends on${NC} $deps"
    else
        echo -e "${service}: ${GREEN}no dependencies${NC}"
    fi
done

echo ""
echo -e "${BLUE}=== Next Steps ===${NC}"
echo "1. Fix unhealthy services"
echo "2. Verify service dependencies are running"
echo "3. Check service logs for errors"
echo "4. Test inter-service communication"

