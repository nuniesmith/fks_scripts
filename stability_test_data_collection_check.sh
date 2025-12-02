#!/bin/bash
# Stability Test - Data Collection Check
# Analyzes data collection service for issues

set -e

# Colors for output
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

SERVICE="fks_data"
TIME_WINDOW="48h"  # Days 2-3

echo "======================================"
echo "Data Collection Service Analysis"
echo "======================================"
echo "Service: $SERVICE"
echo "Time Window: Last $TIME_WINDOW (Days 2-3)"
echo "Timestamp: $(date '+%Y-%m-%d %H:%M:%S')"
echo ""

# Check if container is running
if ! docker ps --format '{{.Names}}' | grep -q "^${SERVICE}$"; then
    echo -e "${RED}❌ $SERVICE: Container not running${NC}"
    exit 1
fi

echo -e "${BLUE}--- Data Collection Health ---${NC}"

# Check health endpoint
if curl -s -f -m 5 "http://localhost:8003/health" > /dev/null 2>&1; then
    echo -e "${GREEN}✅ Service health check: PASSED${NC}"
else
    echo -e "${RED}❌ Service health check: FAILED${NC}"
fi

echo ""
echo -e "${BLUE}--- Data Collection Errors ---${NC}"

# Count data collection errors
ERROR_COUNT=$(docker logs $SERVICE --since $TIME_WINDOW 2>&1 | grep -iE "error|exception|failed|collection.*fail" | wc -l)
echo "Total Errors: $ERROR_COUNT"

if [ $ERROR_COUNT -gt 0 ]; then
    echo ""
    echo "Error Types:"
    docker logs $SERVICE --since $TIME_WINDOW 2>&1 | grep -iE "error|exception|failed|collection.*fail" | \
        sed 's/.*\([Ee]rror\|[Ee]xception\|[Ff]ailed\).*/\1/i' | \
        sort | uniq -c | sort -rn | head -10 | sed 's/^/  /'
fi

echo ""
echo -e "${BLUE}--- Data Collection Warnings ---${NC}"
WARNING_COUNT=$(docker logs $SERVICE --since $TIME_WINDOW 2>&1 | grep -i "warning" | wc -l)
echo "Total Warnings: $WARNING_COUNT"

echo ""
echo -e "${BLUE}--- Collection Failures ---${NC}"

# Check for specific data collection failure patterns
COLLECTION_FAILURES=$(docker logs $SERVICE --since $TIME_WINDOW 2>&1 | grep -iE "failed to collect|collection.*fail|data.*collect.*error" | wc -l)
echo "Collection Failures: $COLLECTION_FAILURES"

if [ $COLLECTION_FAILURES -gt 0 ]; then
    echo ""
    echo "Recent Collection Failures:"
    docker logs $SERVICE --since $TIME_WINDOW 2>&1 | grep -iE "failed to collect|collection.*fail|data.*collect.*error" | tail -10 | sed 's/^/  /'
fi

echo ""
echo -e "${BLUE}--- API Connection Issues ---${NC}"
API_ERRORS=$(docker logs $SERVICE --since $TIME_WINDOW 2>&1 | grep -iE "connection.*error|timeout|api.*error|http.*error" | wc -l)
echo "API Connection Errors: $API_ERRORS"

if [ $API_ERRORS -gt 0 ]; then
    echo ""
    echo "Recent API Errors:"
    docker logs $SERVICE --since $TIME_WINDOW 2>&1 | grep -iE "connection.*error|timeout|api.*error|http.*error" | tail -10 | sed 's/^/  /'
fi

echo ""
echo -e "${BLUE}--- Database Issues ---${NC}"
DB_ERRORS=$(docker logs $SERVICE --since $TIME_WINDOW 2>&1 | grep -iE "database.*error|postgres.*error|db.*error|connection.*pool" | wc -l)
echo "Database Errors: $DB_ERRORS"

if [ $DB_ERRORS -gt 0 ]; then
    echo ""
    echo "Recent Database Errors:"
    docker logs $SERVICE --since $TIME_WINDOW 2>&1 | grep -iE "database.*error|postgres.*error|db.*error|connection.*pool" | tail -10 | sed 's/^/  /'
fi

echo ""
echo -e "${BLUE}--- Celery Worker Status ---${NC}"
# Check Celery worker if available
if docker ps --format '{{.Names}}' | grep -q "celery_worker"; then
    CELERY_ERRORS=$(docker logs fks_data_celery_worker --since $TIME_WINDOW 2>&1 | grep -iE "error|exception|failed|task.*fail" | wc -l)
    echo "Celery Worker Errors: $CELERY_ERRORS"
else
    echo "Celery worker not running or not found"
fi

echo ""
echo "======================================"
echo "Summary"
echo "======================================"
echo "Total Errors: $ERROR_COUNT"
echo "Collection Failures: $COLLECTION_FAILURES"
echo "API Errors: $API_ERRORS"
echo "Database Errors: $DB_ERRORS"

if [ $COLLECTION_FAILURES -gt 10 ] || [ $ERROR_COUNT -gt 50 ]; then
    echo ""
    echo -e "${RED}⚠️  High error rate detected - review logs${NC}"
    exit 1
else
    echo ""
    echo -e "${GREEN}✅ Data collection appears stable${NC}"
    exit 0
fi

