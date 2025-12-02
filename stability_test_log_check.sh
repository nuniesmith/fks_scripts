#!/bin/bash
# Stability Test Log Check Script
# Checks logs for errors, exceptions, and warnings

set -e

# Colors for output
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Services to check
SERVICES=(
    "fks_app"
    "fks_data"
    "fks_web"
    "fks_ai"
    "fks_portfolio"
)

# Log lines to check
LOG_LINES=100

echo "======================================"
echo "Stability Test Log Check"
echo "======================================"
echo "Timestamp: $(date '+%Y-%m-%d %H:%M:%S')"
echo "Checking last $LOG_LINES lines from each service"
echo ""

TOTAL_ERRORS=0

# Check each service
for service in "${SERVICES[@]}"; do
    # Check if container exists
    if ! docker ps -a --format '{{.Names}}' | grep -q "^${service}$"; then
        echo -e "${RED}❌ $service: Container not found${NC}"
        continue
    fi
    
    # Check if container is running
    if ! docker ps --format '{{.Names}}' | grep -q "^${service}$"; then
        echo -e "${RED}❌ $service: Container not running${NC}"
        continue
    fi
    
    echo "--- $service ---"
    
    # Get error count
    ERROR_COUNT=$(docker logs $service --tail $LOG_LINES 2>&1 | grep -iE "error|exception|crash|failed|fatal" | wc -l)
    
    if [ $ERROR_COUNT -gt 0 ]; then
        echo -e "${RED}Found $ERROR_COUNT errors/warnings in last $LOG_LINES lines${NC}"
        echo "Recent errors:"
        docker logs $service --tail $LOG_LINES 2>&1 | grep -iE "error|exception|crash|failed|fatal" | tail -5 | sed 's/^/  /'
        TOTAL_ERRORS=$((TOTAL_ERRORS + ERROR_COUNT))
    else
        echo "✅ No errors found in last $LOG_LINES lines"
    fi
    
    echo ""
done

echo "======================================"
echo "Summary"
echo "======================================"
echo "Total errors/warnings found: $TOTAL_ERRORS"

if [ $TOTAL_ERRORS -gt 0 ]; then
    echo -e "${YELLOW}Review logs for details${NC}"
    exit 1
else
    echo "✅ No errors found in recent logs"
    exit 0
fi

