#!/bin/bash
# Stability Test - Final 7-Day Analysis
# Comprehensive analysis of the entire 7-day stability test

set -e

# Colors for output
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

# Time window (7 days)
TIME_WINDOW="7d"

# Services to analyze
SERVICES=(
    "fks_app"
    "fks_data"
    "fks_web"
    "fks_ai"
    "fks_portfolio"
)

echo "======================================"
echo "7-Day Stability Test - Final Analysis"
echo "======================================"
echo "Test Period: Last 7 days"
echo "Timestamp: $(date '+%Y-%m-%d %H:%M:%S')"
echo ""

# Create output directory
OUTPUT_DIR="stability_test_final_analysis_$(date +%Y%m%d)"
mkdir -p "$OUTPUT_DIR"

# Summary statistics
TOTAL_ERRORS=0
TOTAL_CRASHES=0
TOTAL_WARNINGS=0
SERVICES_HEALTHY=0
SERVICES_UNHEALTHY=0

echo "======================================"
echo "Service-by-Service Analysis"
echo "======================================" > "$OUTPUT_DIR/final_report.txt"
echo "Generated: $(date '+%Y-%m-%d %H:%M:%S')" >> "$OUTPUT_DIR/final_report.txt"
echo "Test Period: Last 7 days" >> "$OUTPUT_DIR/final_report.txt"
echo "" >> "$OUTPUT_DIR/final_report.txt"

# Analyze each service
for service in "${SERVICES[@]}"; do
    echo -e "${BLUE}--- Analyzing $service ---${NC}"
    echo "======================================" >> "$OUTPUT_DIR/final_report.txt"
    echo "Service: $service" >> "$OUTPUT_DIR/final_report.txt"
    echo "======================================" >> "$OUTPUT_DIR/final_report.txt"
    
    # Check if container exists
    if ! docker ps -a --format '{{.Names}}' | grep -q "^${service}$"; then
        echo -e "${RED}❌ $service: Container not found${NC}"
        echo "Status: Container not found" >> "$OUTPUT_DIR/final_report.txt"
        SERVICES_UNHEALTHY=$((SERVICES_UNHEALTHY + 1))
        continue
    fi
    
    # Check if running
    if docker ps --format '{{.Names}}' | grep -q "^${service}$"; then
        echo -e "${GREEN}✅ $service: Running${NC}"
        echo "Status: Running" >> "$OUTPUT_DIR/final_report.txt"
        SERVICES_HEALTHY=$((SERVICES_HEALTHY + 1))
    else
        echo -e "${RED}❌ $service: Not running${NC}"
        echo "Status: Not running" >> "$OUTPUT_DIR/final_report.txt"
        SERVICES_UNHEALTHY=$((SERVICES_UNHEALTHY + 1))
    fi
    
    # Count errors
    ERROR_COUNT=$(docker logs $service --since $TIME_WINDOW 2>&1 | grep -iE "error|exception" | wc -l)
    echo "Errors: $ERROR_COUNT"
    echo "Errors: $ERROR_COUNT" >> "$OUTPUT_DIR/final_report.txt"
    TOTAL_ERRORS=$((TOTAL_ERRORS + ERROR_COUNT))
    
    # Count crashes
    CRASH_COUNT=$(docker logs $service --since $TIME_WINDOW 2>&1 | grep -iE "crash|fatal|segfault|killed" | wc -l)
    echo "Crashes: $CRASH_COUNT"
    echo "Crashes: $CRASH_COUNT" >> "$OUTPUT_DIR/final_report.txt"
    TOTAL_CRASHES=$((TOTAL_CRASHES + CRASH_COUNT))
    
    # Count warnings
    WARNING_COUNT=$(docker logs $service --since $TIME_WINDOW 2>&1 | grep -i "warning" | wc -l)
    echo "Warnings: $WARNING_COUNT"
    echo "Warnings: $WARNING_COUNT" >> "$OUTPUT_DIR/final_report.txt"
    TOTAL_WARNINGS=$((TOTAL_WARNINGS + WARNING_COUNT))
    
    # Get error patterns
    if [ $ERROR_COUNT -gt 0 ]; then
        echo ""
        echo "Top error patterns:" >> "$OUTPUT_DIR/final_report.txt"
        docker logs $service --since $TIME_WINDOW 2>&1 | grep -iE "error|exception" | \
            sed 's/.*\([Ee]rror\|[Ee]xception\).*/\1/i' | \
            sort | uniq -c | sort -rn | head -5 | sed 's/^/  /' >> "$OUTPUT_DIR/final_report.txt"
    fi
    
    echo "" >> "$OUTPUT_DIR/final_report.txt"
    echo ""
done

# Overall summary
echo "======================================"
echo "7-Day Stability Test Summary"
echo "======================================"
echo "" >> "$OUTPUT_DIR/final_report.txt"
echo "======================================" >> "$OUTPUT_DIR/final_report.txt"
echo "Summary Statistics" >> "$OUTPUT_DIR/final_report.txt"
echo "======================================" >> "$OUTPUT_DIR/final_report.txt"
echo "Services Analyzed: ${#SERVICES[@]}" >> "$OUTPUT_DIR/final_report.txt"
echo "Services Healthy: $SERVICES_HEALTHY" >> "$OUTPUT_DIR/final_report.txt"
echo "Services Unhealthy: $SERVICES_UNHEALTHY" >> "$OUTPUT_DIR/final_report.txt"
echo "Total Errors: $TOTAL_ERRORS" >> "$OUTPUT_DIR/final_report.txt"
echo "Total Crashes: $TOTAL_CRASHES" >> "$OUTPUT_DIR/final_report.txt"
echo "Total Warnings: $TOTAL_WARNINGS" >> "$OUTPUT_DIR/final_report.txt"
echo "" >> "$OUTPUT_DIR/final_report.txt"

echo ""
echo "Services Analyzed: ${#SERVICES[@]}"
echo "Services Healthy: $SERVICES_HEALTHY"
echo "Services Unhealthy: $SERVICES_UNHEALTHY"
echo "Total Errors: $TOTAL_ERRORS"
echo "Total Crashes: $TOTAL_CRASHES"
echo "Total Warnings: $TOTAL_WARNINGS"

# Calculate uptime percentage
if [ ${#SERVICES[@]} -gt 0 ]; then
    UPTIME_PERCENT=$((SERVICES_HEALTHY * 100 / ${#SERVICES[@]}))
    echo "Overall Uptime: ${UPTIME_PERCENT}%"
    echo "Overall Uptime: ${UPTIME_PERCENT}%" >> "$OUTPUT_DIR/final_report.txt"
fi

# Determine overall status
echo "" >> "$OUTPUT_DIR/final_report.txt"
if [ $TOTAL_CRASHES -eq 0 ] && [ $TOTAL_ERRORS -lt 100 ] && [ $SERVICES_UNHEALTHY -eq 0 ]; then
    echo -e "${GREEN}✅ STABILITY TEST: PASSED${NC}"
    echo "Overall Status: PASSED" >> "$OUTPUT_DIR/final_report.txt"
    STATUS="PASSED"
elif [ $TOTAL_CRASHES -lt 3 ] && [ $TOTAL_ERRORS -lt 500 ]; then
    echo -e "${YELLOW}⚠️  STABILITY TEST: PASSED WITH WARNINGS${NC}"
    echo "Overall Status: PASSED WITH WARNINGS" >> "$OUTPUT_DIR/final_report.txt"
    STATUS="PASSED WITH WARNINGS"
else
    echo -e "${RED}❌ STABILITY TEST: FAILED${NC}"
    echo "Overall Status: FAILED" >> "$OUTPUT_DIR/final_report.txt"
    STATUS="FAILED"
fi

echo ""
echo "======================================"
echo "Report saved to: $OUTPUT_DIR/final_report.txt"
echo ""

# Display report
cat "$OUTPUT_DIR/final_report.txt"

exit 0

