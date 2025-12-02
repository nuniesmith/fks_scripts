#!/bin/bash
# FKS Services Health Check Script
# Checks health of all registered services

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Service registry
SERVICES=(
    "fks_web:3001"
    "fks_api:8001"
    "fks_app:8002"
    "fks_data:8003"
    "fks_execution:8004"
    "fks_meta:8005"
    "fks_ninja:8006"
    "fks_ai:8007"
    "fks_analyze:8008"
    "fks_auth:8009"
    "fks_main:8010"
    "fks_training:8011"
    "fks_portfolio:8012"
    "fks_monitor:8013"
    "fks_crypto:8014"
)

echo "=========================================="
echo "FKS Services Health Check"
echo "=========================================="
echo ""

healthy=0
unhealthy=0
not_running=0

for service_port in "${SERVICES[@]}"; do
    IFS=':' read -r service port <<< "$service_port"
    
    # Check if container is running
    if ! docker ps --format "{{.Names}}" | grep -q "^${service}$"; then
        echo -e "${YELLOW}⚠ $service${NC} - Container not running"
        not_running=$((not_running + 1))
        continue
    fi
    
    # Check health endpoint
    if curl -sf "http://localhost:$port/health" > /dev/null 2>&1; then
        echo -e "${GREEN}✓ $service${NC} (port $port) - Healthy"
        healthy=$((healthy + 1))
    else
        echo -e "${RED}✗ $service${NC} (port $port) - Unhealthy"
        unhealthy=$((unhealthy + 1))
    fi
done

echo ""
echo "=========================================="
echo "Summary"
echo "=========================================="
echo -e "${GREEN}Healthy: $healthy${NC}"
echo -e "${RED}Unhealthy: $unhealthy${NC}"
echo -e "${YELLOW}Not Running: $not_running${NC}"
echo "Total: ${#SERVICES[@]}"
echo ""

if [ $unhealthy -eq 0 ] && [ $not_running -eq 0 ]; then
    echo -e "${GREEN}All services are healthy!${NC}"
    exit 0
else
    echo -e "${RED}Some services need attention${NC}"
    exit 1
fi

