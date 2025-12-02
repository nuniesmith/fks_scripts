#!/bin/bash
# Stability Test Error Summary
# Creates a detailed error summary report for Day 1 review

set -e

# Colors for output
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

# Services to check
SERVICES=(
    "fks_app"
    "fks_data"
    "fks_web"
    "fks_ai"
    "fks_portfolio"
)

# Time window (last 24 hours)
TIME_WINDOW="24h"

OUTPUT_FILE="stability_test_day1_error_summary_$(date +%Y%m%d).txt"

echo "======================================"
echo "Stability Test - Day 1 Error Summary"
echo "======================================" > "$OUTPUT_FILE"
echo "Generated: $(date '+%Y-%m-%d %H:%M:%S')" >> "$OUTPUT_FILE"
echo "Time Window: Last $TIME_WINDOW" >> "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"

# Analyze each service
for service in "${SERVICES[@]}"; do
    if ! docker ps -a --format '{{.Names}}' | grep -q "^${service}$"; then
        echo "❌ $service: Container not found" >> "$OUTPUT_FILE"
        continue
    fi
    
    echo "======================================" >> "$OUTPUT_FILE"
    echo "Service: $service" >> "$OUTPUT_FILE"
    echo "======================================" >> "$OUTPUT_FILE"
    
    # Get error counts
    ERROR_COUNT=$(docker logs $service --since $TIME_WINDOW 2>&1 | grep -iE "error|exception" | wc -l)
    CRASH_COUNT=$(docker logs $service --since $TIME_WINDOW 2>&1 | grep -iE "crash|fatal|segfault|killed" | wc -l)
    WARNING_COUNT=$(docker logs $service --since $TIME_WINDOW 2>&1 | grep -i "warning" | wc -l)
    
    echo "Errors: $ERROR_COUNT" >> "$OUTPUT_FILE"
    echo "Crashes: $CRASH_COUNT" >> "$OUTPUT_FILE"
    echo "Warnings: $WARNING_COUNT" >> "$OUTPUT_FILE"
    echo "" >> "$OUTPUT_FILE"
    
    # Get unique error messages
    if [ $ERROR_COUNT -gt 0 ]; then
        echo "Error Messages (sample):" >> "$OUTPUT_FILE"
        docker logs $service --since $TIME_WINDOW 2>&1 | grep -iE "error|exception" | tail -10 | sed 's/^/  /' >> "$OUTPUT_FILE"
        echo "" >> "$OUTPUT_FILE"
    fi
    
    # Get crash information
    if [ $CRASH_COUNT -gt 0 ]; then
        echo "CRASHES DETECTED:" >> "$OUTPUT_FILE"
        docker logs $service --since $TIME_WINDOW 2>&1 | grep -iE "crash|fatal|segfault|killed" | sed 's/^/  /' >> "$OUTPUT_FILE"
        echo "" >> "$OUTPUT_FILE"
    fi
    
    # Get error patterns
    echo "Error Patterns:" >> "$OUTPUT_FILE"
    docker logs $service --since $TIME_WINDOW 2>&1 | grep -iE "error|exception" | \
        sed 's/.*\([Ee]rror\|[Ee]xception\).*/\1/i' | \
        sort | uniq -c | sort -rn | head -10 | sed 's/^/  /' >> "$OUTPUT_FILE"
    echo "" >> "$OUTPUT_FILE"
done

echo "======================================" >> "$OUTPUT_FILE"
echo "Analysis complete. Report saved to: $OUTPUT_FILE" >> "$OUTPUT_FILE"

# Display summary
cat "$OUTPUT_FILE"
echo ""
echo "Full report saved to: $OUTPUT_FILE"

