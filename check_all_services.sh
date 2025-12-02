#!/bin/bash
# FKS Service Health Check Script
# Task: TASK-012 - Create health check script for all services
# Usage: ./check_all_services.sh

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
SERVICE_REGISTRY="$REPO_ROOT/services/config/service_registry.json"

# Check if service registry exists
if [ ! -f "$SERVICE_REGISTRY" ]; then
    echo -e "${RED}Error: Service registry not found at $SERVICE_REGISTRY${NC}"
    exit 1
fi

# Counters
TOTAL=0
HEALTHY=0
UNHEALTHY=0
UNHEALTHY_SERVICES=()

# Function to check service health
check_service_health() {
    local service_name=$1
    local port=$2
    local health_url=$3
    local base_url=$4
    
    TOTAL=$((TOTAL + 1))
    
    echo -n "  ${CYAN}$service_name${NC} (port $port)... "
    
    # Try health endpoint
    if curl -sf --max-time 5 "$health_url" > /dev/null 2>&1; then
        # Get health response
        response=$(curl -s --max-time 5 "$health_url" 2>/dev/null)
        if echo "$response" | grep -qi "healthy\|ok\|status.*ok"; then
            echo -e "${GREEN}✓ HEALTHY${NC}"
            HEALTHY=$((HEALTHY + 1))
            return 0
        else
            echo -e "${YELLOW}⚠ RESPONDING (status unclear)${NC}"
            UNHEALTHY=$((UNHEALTHY + 1))
            UNHEALTHY_SERVICES+=("$service_name")
            return 1
        fi
    else
        echo -e "${RED}✗ UNHEALTHY or UNAVAILABLE${NC}"
        UNHEALTHY=$((UNHEALTHY + 1))
        UNHEALTHY_SERVICES+=("$service_name")
        return 1
    fi
}

# Function to check Docker container status
check_docker_container() {
    local service_name=$1
    local container_name="fks-${service_name#fks_}"
    
    if docker ps --format '{{.Names}}' | grep -q "^${container_name}$" 2>/dev/null; then
        local status=$(docker inspect --format='{{.State.Status}}' "$container_name" 2>/dev/null)
        if [ "$status" = "running" ]; then
            return 0
        fi
    fi
    return 1
}

# Parse service registry and check services
echo -e "${BLUE}================================================${NC}"
echo -e "${BLUE}  FKS Platform - Service Health Check${NC}"
echo -e "${BLUE}================================================${NC}"
echo ""
echo -e "Timestamp: ${CYAN}$(date '+%Y-%m-%d %H:%M:%S')${NC}"
echo ""

# Extract services from registry using jq
if command -v jq &> /dev/null; then
    echo -e "${BLUE}Checking services from registry...${NC}\n"
    
    # Get all services
    services=$(jq -r '.services | keys[]' "$SERVICE_REGISTRY" 2>/dev/null)
    
    for service_key in $services; do
        port=$(jq -r ".services[\"$service_key\"].port" "$SERVICE_REGISTRY" 2>/dev/null)
        health_url=$(jq -r ".services[\"$service_key\"].health_url" "$SERVICE_REGISTRY" 2>/dev/null)
        base_url=$(jq -r ".services[\"$service_key\"].base_url" "$SERVICE_REGISTRY" 2>/dev/null)
        
        # Convert Docker URL to localhost if needed
        if echo "$health_url" | grep -q "fks-"; then
            health_url=$(echo "$health_url" | sed "s|http://fks-[^:]*:|http://localhost:|")
        fi
        
        # Fallback to localhost if health_url is empty
        if [ -z "$health_url" ] || [ "$health_url" = "null" ]; then
            health_url="http://localhost:$port/health"
        fi
        
        # Special handling for services with non-standard health endpoints
        case "$service_key" in
            fks_analyze)
                # fks_analyze uses /health/health endpoint
                if echo "$health_url" | grep -q "/health$" && ! echo "$health_url" | grep -q "/health/health"; then
                    health_url="${health_url}/health"
                fi
                # Use Docker port mapping (8081) for localhost checks
                port_docker=$(jq -r ".services[\"$service_key\"].port_docker // empty" "$SERVICE_REGISTRY" 2>/dev/null)
                if [ -n "$port_docker" ] && [ "$port_docker" != "null" ]; then
                    health_url=$(echo "$health_url" | sed "s|:${port}|:${port_docker}|")
                fi
                ;;
            fks_web)
                # fks_web uses port 8000 in Docker, 3001 in K8s
                port_docker=$(jq -r ".services[\"$service_key\"].port_docker // empty" "$SERVICE_REGISTRY" 2>/dev/null)
                if [ -n "$port_docker" ] && [ "$port_docker" != "null" ]; then
                    health_url=$(echo "$health_url" | sed "s|:${port}|:${port_docker}|")
                fi
                ;;
        esac
        
        check_service_health "$service_key" "$port" "$health_url" "$base_url"
    done
else
    # Fallback: manual service list if jq not available
    echo -e "${YELLOW}Warning: jq not found, using manual service list${NC}\n"
    
    # Manual service list based on service registry
    declare -A services_ports=(
        ["fks_web"]="8000"
        ["fks_api"]="8001"
        ["fks_app"]="8002"
        ["fks_data"]="8003"
        ["fks_execution"]="8004"
        ["fks_meta"]="8005"
        ["fks_ninja"]="8006"
        ["fks_ai"]="8007"
        ["fks_analyze"]="8008"
        ["fks_auth"]="8009"
        ["fks_main"]="8010"
        ["fks_training"]="8011"
        ["fks_portfolio"]="8012"
        ["fks_monitor"]="8013"
        ["fks_crypto"]="8014"
        ["fks_futures"]="8015"
    )
    
    for service_name in "${!services_ports[@]}"; do
        port="${services_ports[$service_name]}"
        health_url="http://localhost:$port/health"
        check_service_health "$service_name" "$port" "$health_url" ""
    done
fi

# Summary
echo ""
echo -e "${BLUE}================================================${NC}"
echo -e "${BLUE}  Summary${NC}"
echo -e "${BLUE}================================================${NC}"
echo ""
echo -e "Total Services: ${CYAN}$TOTAL${NC}"
echo -e "Healthy: ${GREEN}$HEALTHY${NC}"
echo -e "Unhealthy: ${RED}$UNHEALTHY${NC}"
echo ""

if [ $UNHEALTHY -gt 0 ]; then
    echo -e "${YELLOW}Unhealthy Services:${NC}"
    for service in "${UNHEALTHY_SERVICES[@]}"; do
        echo -e "  - ${RED}$service${NC}"
    done
    echo ""
    echo -e "${YELLOW}Recommendation: Review logs for unhealthy services${NC}"
    echo -e "  Example: ${CYAN}docker logs fks-${UNHEALTHY_SERVICES[0]#fks_}${NC}"
    exit 1
else
    echo -e "${GREEN}✓ All services are healthy!${NC}"
    exit 0
fi
