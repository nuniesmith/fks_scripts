#!/bin/bash
# Stability Test Status Script
# Comprehensive status check for stability test

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo "======================================"
echo "Stability Test - System Status"
echo "======================================"
echo "Timestamp: $(date '+%Y-%m-%d %H:%M:%S')"
echo ""

# 1. Docker Container Status
echo -e "${BLUE}1. Docker Container Status${NC}"
echo "--------------------------------------"
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | head -20
echo ""

# 2. Service Health Checks
echo -e "${BLUE}2. Service Health Checks${NC}"
echo "--------------------------------------"
SERVICES=(
    "fks_app:8002"
    "fks_data:8003"
    "fks_web:8004"
    "fks_ai:8001"
    "fks_portfolio:8012"
)

HEALTHY=0
UNHEALTHY=0

for service_entry in "${SERVICES[@]}"; do
    name=$(echo $service_entry | cut -d: -f1)
    port=$(echo $service_entry | cut -d: -f2)
    
    if docker ps --format '{{.Names}}' | grep -q "^${name}$"; then
        if curl -s -f -m 5 "http://localhost:$port/health" > /dev/null 2>&1; then
            echo -e "${GREEN}✅ $name${NC}"
            HEALTHY=$((HEALTHY + 1))
        else
            echo -e "${RED}❌ $name (health check failed)${NC}"
            UNHEALTHY=$((UNHEALTHY + 1))
        fi
    else
        echo -e "${RED}❌ $name (not running)${NC}"
        UNHEALTHY=$((UNHEALTHY + 1))
    fi
done

echo ""
echo "Healthy: $HEALTHY | Unhealthy: $UNHEALTHY"
echo ""

# 3. Resource Usage
echo -e "${BLUE}3. Resource Usage${NC}"
echo "--------------------------------------"
docker stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.NetIO}}" | head -10
echo ""

# 4. Recent Errors
echo -e "${BLUE}4. Recent Errors (Last Hour)${NC}"
echo "--------------------------------------"
SERVICES_SHORT=("fks_app" "fks_data" "fks_web" "fks_ai" "fks_portfolio")
ERROR_FOUND=false

for service in "${SERVICES_SHORT[@]}"; do
    if docker ps --format '{{.Names}}' | grep -q "^${service}$"; then
        ERROR_COUNT=$(docker logs $service --since 1h 2>&1 | grep -iE "error|exception|crash|failed|fatal" | wc -l)
        if [ $ERROR_COUNT -gt 0 ]; then
            echo -e "${RED}$service: $ERROR_COUNT errors${NC}"
            ERROR_FOUND=true
        fi
    fi
done

if [ "$ERROR_FOUND" = false ]; then
    echo "✅ No errors in last hour"
fi

echo ""

# 5. System Summary
echo -e "${BLUE}5. System Summary${NC}"
echo "--------------------------------------"
TOTAL_CONTAINERS=$(docker ps --format '{{.Names}}' | wc -l)
RUNNING_SERVICES=$(echo "${SERVICES[@]}" | wc -w)

echo "Total running containers: $TOTAL_CONTAINERS"
echo "Services monitored: $RUNNING_SERVICES"
echo "Healthy services: $HEALTHY"
echo "Unhealthy services: $UNHEALTHY"

if [ $UNHEALTHY -eq 0 ]; then
    echo ""
    echo -e "${GREEN}✅ All systems operational${NC}"
    exit 0
else
    echo ""
    echo -e "${RED}⚠️  Some services are unhealthy${NC}"
    exit 1
fi

