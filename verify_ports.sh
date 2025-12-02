#!/bin/bash
# Verify all FKS services are running on correct ports
# Usage: ./verify_ports.sh

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Service registry
declare -A SERVICES=(
    ["fks_web"]=8000
    ["fks_api"]=8001
    ["fks_app"]=8002
    ["fks_data"]=8003
    ["fks_execution"]=8004
    ["fks_meta"]=8005
    ["fks_ai"]=8007
    ["fks_analyze"]=8008
    ["fks_auth"]=8009
    ["fks_main"]=8010
    ["fks_training"]=8011
    ["fks_portfolio"]=8012
    ["fks_monitor"]=8013
)

echo "🔍 Verifying FKS Service Ports..."
echo "=================================="
echo ""

FAILED=0
PASSED=0

for service in "${!SERVICES[@]}"; do
    port=${SERVICES[$service]}
    url="http://localhost:${port}/health"
    
    echo -n "Checking ${service} on port ${port}... "
    
    # Try to connect
    if curl -f -s --max-time 5 "${url}" > /dev/null 2>&1; then
        echo -e "${GREEN}✓ PASSED${NC}"
        ((PASSED++))
    else
        echo -e "${RED}✗ FAILED${NC} (Service not responding)"
        ((FAILED++))
    fi
done

echo ""
echo "=================================="
echo "Results: ${GREEN}${PASSED} passed${NC}, ${RED}${FAILED} failed${NC}"
echo ""

if [ $FAILED -eq 0 ]; then
    echo -e "${GREEN}All services are healthy!${NC}"
    exit 0
else
    echo -e "${YELLOW}Some services are not responding.${NC}"
    echo "Make sure all services are running: docker-compose up -d"
    exit 1
fi

