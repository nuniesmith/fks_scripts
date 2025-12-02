#!/bin/bash
# Stability Test - AI Service Check
# Analyzes AI enhancement service for issues

set -e

# Colors for output
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

SERVICE="fks_ai"
TIME_WINDOW="24h"  # Day 4

echo "======================================"
echo "AI Service Analysis"
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

echo -e "${BLUE}--- AI Service Health ---${NC}"

# Check health endpoint
if curl -s -f -m 5 "http://localhost:8004/health" > /dev/null 2>&1; then
    echo -e "${GREEN}✅ Service health check: PASSED${NC}"
    HEALTH_RESPONSE=$(curl -s "http://localhost:8004/health")
    echo "Health Response: $HEALTH_RESPONSE"
else
    echo -e "${RED}❌ Service health check: FAILED${NC}"
fi

echo ""
echo -e "${BLUE}--- AI Service Errors ---${NC}"

# Count AI service errors
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
echo -e "${BLUE}--- Enhancement Failures ---${NC}"

# Check for enhancement failures
ENHANCEMENT_FAILURES=$(docker logs $SERVICE --since $TIME_WINDOW 2>&1 | grep -iE "enhancement.*fail|failed.*enhance|ai.*fail" | wc -l)
echo "Enhancement Failures: $ENHANCEMENT_FAILURES"

if [ $ENHANCEMENT_FAILURES -gt 0 ]; then
    echo ""
    echo "Recent Enhancement Failures:"
    docker logs $SERVICE --since $TIME_WINDOW 2>&1 | grep -iE "enhancement.*fail|failed.*enhance|ai.*fail" | tail -10 | sed 's/^/  /'
fi

echo ""
echo -e "${BLUE}--- API/Model Issues ---${NC}"

# Check for API/model errors
API_ERRORS=$(docker logs $SERVICE --since $TIME_WINDOW 2>&1 | grep -iE "api.*error|model.*error|openai.*error|anthropic.*error|llm.*error" | wc -l)
echo "API/Model Errors: $API_ERRORS"

if [ $API_ERRORS -gt 0 ]; then
    echo ""
    echo "Recent API/Model Errors:"
    docker logs $SERVICE --since $TIME_WINDOW 2>&1 | grep -iE "api.*error|model.*error|openai.*error|anthropic.*error|llm.*error" | tail -10 | sed 's/^/  /'
fi

echo ""
echo -e "${BLUE}--- Timeout Issues ---${NC}"

# Check for timeout errors
TIMEOUT_ERRORS=$(docker logs $SERVICE --since $TIME_WINDOW 2>&1 | grep -iE "timeout|timed.*out|request.*timeout" | wc -l)
echo "Timeout Errors: $TIMEOUT_ERRORS"

if [ $TIMEOUT_ERRORS -gt 0 ]; then
    echo ""
    echo "Recent Timeout Errors:"
    docker logs $SERVICE --since $TIME_WINDOW 2>&1 | grep -iE "timeout|timed.*out|request.*timeout" | tail -10 | sed 's/^/  /'
fi

echo ""
echo -e "${BLUE}--- Rate Limiting Issues ---${NC}"

# Check for rate limiting
RATE_LIMIT_ERRORS=$(docker logs $SERVICE --since $TIME_WINDOW 2>&1 | grep -iE "rate.*limit|429|too.*many.*requests" | wc -l)
echo "Rate Limit Errors: $RATE_LIMIT_ERRORS"

if [ $RATE_LIMIT_ERRORS -gt 0 ]; then
    echo ""
    echo "Recent Rate Limit Errors:"
    docker logs $SERVICE --since $TIME_WINDOW 2>&1 | grep -iE "rate.*limit|429|too.*many.*requests" | tail -10 | sed 's/^/  /'
fi

echo ""
echo -e "${BLUE}--- Response Quality Issues ---${NC}"

# Check for response quality issues
QUALITY_ERRORS=$(docker logs $SERVICE --since $TIME_WINDOW 2>&1 | grep -iE "invalid.*response|parse.*error|json.*error|malformed.*response" | wc -l)
echo "Response Quality Errors: $QUALITY_ERRORS"

if [ $QUALITY_ERRORS -gt 0 ]; then
    echo ""
    echo "Recent Response Quality Errors:"
    docker logs $SERVICE --since $TIME_WINDOW 2>&1 | grep -iE "invalid.*response|parse.*error|json.*error|malformed.*response" | tail -10 | sed 's/^/  /'
fi

echo ""
echo -e "${BLUE}--- Connection Issues ---${NC}"

# Check for connection errors
CONNECTION_ERRORS=$(docker logs $SERVICE --since $TIME_WINDOW 2>&1 | grep -iE "connection.*error|connection.*refused|connection.*reset" | wc -l)
echo "Connection Errors: $CONNECTION_ERRORS"

echo ""
echo -e "${BLUE}--- Performance Metrics ---${NC}"

# Check for performance warnings
PERF_WARNINGS=$(docker logs $SERVICE --since $TIME_WINDOW 2>&1 | grep -iE "slow|performance|latency|response.*time" | wc -l)
echo "Performance Warnings: $PERF_WARNINGS"

echo ""
echo "======================================"
echo "Summary"
echo "======================================"
echo "Total Errors: $ERROR_COUNT"
echo "Enhancement Failures: $ENHANCEMENT_FAILURES"
echo "API/Model Errors: $API_ERRORS"
echo "Timeout Errors: $TIMEOUT_ERRORS"
echo "Rate Limit Errors: $RATE_LIMIT_ERRORS"
echo "Response Quality Errors: $QUALITY_ERRORS"
echo "Connection Errors: $CONNECTION_ERRORS"

if [ $ENHANCEMENT_FAILURES -gt 10 ] || [ $ERROR_COUNT -gt 50 ]; then
    echo ""
    echo -e "${RED}⚠️  High error rate detected - review logs${NC}"
    exit 1
elif [ $RATE_LIMIT_ERRORS -gt 5 ]; then
    echo ""
    echo -e "${YELLOW}⚠️  Rate limiting issues detected - consider adjusting rate limits${NC}"
    exit 1
else
    echo ""
    echo -e "${GREEN}✅ AI service appears stable${NC}"
    exit 0
fi


