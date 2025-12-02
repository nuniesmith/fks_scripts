#!/bin/bash
# Stability Test - Dashboard Check
# Analyzes web dashboard service for issues

set -e

# Colors for output
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

SERVICE="fks_web"
TIME_WINDOW="24h"  # Day 4

echo "======================================"
echo "Dashboard Service Analysis"
echo "======================================"
echo "Service: $SERVICE"
echo "Time Window: Last $TIME_WINDOW (Day 4)"
echo "Timestamp: $(date '+%Y-%m-%d %H:%M:%S')"
echo ""

# Check if container is running
if ! docker ps --format '{{.Names}}' | grep -q "^${SERVICE}$"; then
    echo -e "${RED}❌ $SERVICE: Container not running${NC}"
    exit 1
fi

echo -e "${BLUE}--- Dashboard Health ---${NC}"

# Check health endpoint
if curl -s -f -m 5 "http://localhost:8001/health" > /dev/null 2>&1; then
    echo -e "${GREEN}✅ Service health check: PASSED${NC}"
else
    echo -e "${RED}❌ Service health check: FAILED${NC}"
fi

# Check if web page is accessible
if curl -s -f -m 5 "http://localhost:8001/" > /dev/null 2>&1; then
    echo -e "${GREEN}✅ Web page accessible${NC}"
else
    echo -e "${RED}❌ Web page not accessible${NC}"
fi

echo ""
echo -e "${BLUE}--- Dashboard Errors ---${NC}"

# Count dashboard errors
ERROR_COUNT=$(docker logs $SERVICE --since $TIME_WINDOW 2>&1 | grep -iE "error|exception|failed" | wc -l)
echo "Total Errors: $ERROR_COUNT"

if [ $ERROR_COUNT -gt 0 ]; then
    echo ""
    echo "Error Types:"
    docker logs $SERVICE --since $TIME_WINDOW 2>&1 | grep -iE "error|exception|failed" | \
        sed 's/.*\([Ee]rror\|[Ee]xception\|[Ff]ailed\).*/\1/i' | \
        sort | uniq -c | sort -rn | head -10 | sed 's/^/  /'
fi

echo ""
echo -e "${BLUE}--- HTTP Errors ---${NC}"

# Check for HTTP errors (4xx, 5xx)
HTTP_ERRORS=$(docker logs $SERVICE --since $TIME_WINDOW 2>&1 | grep -iE "HTTP.*[45][0-9]{2}|[45][0-9]{2}.*error" | wc -l)
echo "HTTP Errors (4xx/5xx): $HTTP_ERRORS"

if [ $HTTP_ERRORS -gt 0 ]; then
    echo ""
    echo "HTTP Error Distribution:"
    docker logs $SERVICE --since $TIME_WINDOW 2>&1 | grep -oE "HTTP/[0-9.]+ [45][0-9]{2}" | \
        sort | uniq -c | sort -rn | head -10 | sed 's/^/  /'
fi

echo ""
echo -e "${BLUE}--- Database Connection Issues ---${NC}"

# Check for database connection errors
DB_ERRORS=$(docker logs $SERVICE --since $TIME_WINDOW 2>&1 | grep -iE "database.*error|postgres.*error|db.*connection.*error|operationalerror" | wc -l)
echo "Database Connection Errors: $DB_ERRORS"

if [ $DB_ERRORS -gt 0 ]; then
    echo ""
    echo "Recent Database Errors:"
    docker logs $SERVICE --since $TIME_WINDOW 2>&1 | grep -iE "database.*error|postgres.*error|db.*connection.*error|operationalerror" | tail -10 | sed 's/^/  /'
fi

echo ""
echo -e "${BLUE}--- Template/View Errors ---${NC}"

# Check for template/view errors
TEMPLATE_ERRORS=$(docker logs $SERVICE --since $TIME_WINDOW 2>&1 | grep -iE "template.*error|template.*not.*found|view.*error|render.*error" | wc -l)
echo "Template/View Errors: $TEMPLATE_ERRORS"

if [ $TEMPLATE_ERRORS -gt 0 ]; then
    echo ""
    echo "Recent Template/View Errors:"
    docker logs $SERVICE --since $TIME_WINDOW 2>&1 | grep -iE "template.*error|template.*not.*found|view.*error|render.*error" | tail -10 | sed 's/^/  /'
fi

echo ""
echo -e "${BLUE}--- API Endpoint Errors ---${NC}"

# Check for API endpoint errors
API_ERRORS=$(docker logs $SERVICE --since $TIME_WINDOW 2>&1 | grep -iE "api.*error|endpoint.*error|request.*error|json.*error" | wc -l)
echo "API Endpoint Errors: $API_ERRORS"

if [ $API_ERRORS -gt 0 ]; then
    echo ""
    echo "Recent API Endpoint Errors:"
    docker logs $SERVICE --since $TIME_WINDOW 2>&1 | grep -iE "api.*error|endpoint.*error|request.*error|json.*error" | tail -10 | sed 's/^/  /'
fi

echo ""
echo -e "${BLUE}--- Static File Errors ---${NC}"

# Check for static file errors
STATIC_ERRORS=$(docker logs $SERVICE --since $TIME_WINDOW 2>&1 | grep -iE "static.*file.*not.*found|404.*css|404.*js|static.*error" | wc -l)
echo "Static File Errors: $STATIC_ERRORS"

echo ""
echo -e "${BLUE}--- Performance Issues ---${NC}"

# Check for performance warnings
PERF_WARNINGS=$(docker logs $SERVICE --since $TIME_WINDOW 2>&1 | grep -iE "slow.*query|timeout|performance|response.*time.*high" | wc -l)
echo "Performance Warnings: $PERF_WARNINGS"

if [ $PERF_WARNINGS -gt 0 ]; then
    echo ""
    echo "Recent Performance Warnings:"
    docker logs $SERVICE --since $TIME_WINDOW 2>&1 | grep -iE "slow.*query|timeout|performance|response.*time.*high" | tail -10 | sed 's/^/  /'
fi

echo ""
echo -e "${BLUE}--- Authentication/Authorization Errors ---${NC}"

# Check for auth errors
AUTH_ERRORS=$(docker logs $SERVICE --since $TIME_WINDOW 2>&1 | grep -iE "authentication.*error|authorization.*error|permission.*denied|unauthorized" | wc -l)
echo "Authentication/Authorization Errors: $AUTH_ERRORS"

echo ""
echo -e "${BLUE}--- Request Patterns ---${NC}"

# Count requests by method
GET_REQUESTS=$(docker logs $SERVICE --since $TIME_WINDOW 2>&1 | grep -cE "GET " || echo "0")
POST_REQUESTS=$(docker logs $SERVICE --since $TIME_WINDOW 2>&1 | grep -cE "POST " || echo "0")
PUT_REQUESTS=$(docker logs $SERVICE --since $TIME_WINDOW 2>&1 | grep -cE "PUT " || echo "0")
DELETE_REQUESTS=$(docker logs $SERVICE --since $TIME_WINDOW 2>&1 | grep -cE "DELETE " || echo "0")

echo "GET Requests: $GET_REQUESTS"
echo "POST Requests: $POST_REQUESTS"
echo "PUT Requests: $PUT_REQUESTS"
echo "DELETE Requests: $DELETE_REQUESTS"

echo ""
echo "======================================"
echo "Summary"
echo "======================================"
echo "Total Errors: $ERROR_COUNT"
echo "HTTP Errors: $HTTP_ERRORS"
echo "Database Errors: $DB_ERRORS"
echo "Template/View Errors: $TEMPLATE_ERRORS"
echo "API Endpoint Errors: $API_ERRORS"
echo "Static File Errors: $STATIC_ERRORS"
echo "Performance Warnings: $PERF_WARNINGS"
echo "Auth Errors: $AUTH_ERRORS"

if [ $HTTP_ERRORS -gt 20 ] || [ $ERROR_COUNT -gt 50 ]; then
    echo ""
    echo -e "${RED}⚠️  High error rate detected - review logs${NC}"
    exit 1
else
    echo ""
    echo -e "${GREEN}✅ Dashboard appears stable${NC}"
    exit 0
fi


