#!/bin/bash
# Stability Test Log Analyzer
# Analyzes logs for Day 1 review - identifies errors, crashes, and patterns

set -e

# Colors for output
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

# Services to analyze
SERVICES=(
    "fks_app"
    "fks_data"
    "fks_web"
    "fks_ai"
    "fks_portfolio"
)

# Time window (last 24 hours)
TIME_WINDOW="24h"

echo "======================================"
echo "Stability Test - Day 1 Log Analysis"
echo "======================================"
echo "Timestamp: $(date '+%Y-%m-%d %H:%M:%S')"
echo "Analyzing logs from last $TIME_WINDOW"
echo ""

# Create output directory
OUTPUT_DIR="stability_test_analysis_$(date +%Y%m%d)"
mkdir -p "$OUTPUT_DIR"

TOTAL_ERRORS=0
TOTAL_CRASHES=0
TOTAL_WARNINGS=0

# Analyze each service
for service in "${SERVICES[@]}"; do
    # Check if container exists
    if ! docker ps -a --format '{{.Names}}' | grep -q "^${service}$"; then
        echo -e "${RED}❌ $service: Container not found${NC}"
        continue
    fi
    
    echo -e "${BLUE}--- Analyzing $service ---${NC}"
    
    # Get logs from last 24 hours
    SERVICE_LOG="$OUTPUT_DIR/${service}_analysis.log"
    
    # Count errors
    ERROR_COUNT=$(docker logs $service --since $TIME_WINDOW 2>&1 | grep -iE "error|exception|crash|failed|fatal" | wc -l)
    
    # Count crashes
    CRASH_COUNT=$(docker logs $service --since $TIME_WINDOW 2>&1 | grep -iE "crash|fatal|segfault|killed|terminated" | wc -l)
    
    # Count warnings
    WARNING_COUNT=$(docker logs $service --since $TIME_WINDOW 2>&1 | grep -iE "warning|warn" | wc -l)
    
    # Get error patterns
    echo "Error Count: $ERROR_COUNT"
    echo "Crash Count: $CRASH_COUNT"
    echo "Warning Count: $WARNING_COUNT"
    
    if [ $ERROR_COUNT -gt 0 ] || [ $CRASH_COUNT -gt 0 ]; then
        echo -e "${RED}⚠️  Issues found in $service${NC}"
        
        # Extract errors to file
        docker logs $service --since $TIME_WINDOW 2>&1 | grep -iE "error|exception|crash|failed|fatal" > "$OUTPUT_DIR/${service}_errors.log"
        
        # Get unique error patterns
        echo ""
        echo "Top error patterns:"
        docker logs $service --since $TIME_WINDOW 2>&1 | grep -iE "error|exception" | sed 's/.*\(error\|exception\|failed\).*/\1/i' | sort | uniq -c | sort -rn | head -5 | sed 's/^/  /'
    else
        echo -e "${GREEN}✅ No critical issues found${NC}"
    fi
    
    TOTAL_ERRORS=$((TOTAL_ERRORS + ERROR_COUNT))
    TOTAL_CRASHES=$((TOTAL_CRASHES + CRASH_COUNT))
    TOTAL_WARNINGS=$((TOTAL_WARNINGS + WARNING_COUNT))
    
    echo ""
done

# Summary
echo "======================================"
echo "Day 1 Analysis Summary"
echo "======================================"
echo "Total Errors: $TOTAL_ERRORS"
echo "Total Crashes: $TOTAL_CRASHES"
echo "Total Warnings: $TOTAL_WARNINGS"
echo ""
echo "Analysis saved to: $OUTPUT_DIR/"

# Check for critical issues
if [ $TOTAL_CRASHES -gt 0 ]; then
    echo -e "${RED}⚠️  CRITICAL: $TOTAL_CRASHES crash(es) detected${NC}"
    exit 1
elif [ $TOTAL_ERRORS -gt 100 ]; then
    echo -e "${YELLOW}⚠️  HIGH: $TOTAL_ERRORS errors detected${NC}"
    exit 1
else
    echo -e "${GREEN}✅ System appears stable${NC}"
    exit 0
fi

