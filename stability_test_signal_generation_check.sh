#!/bin/bash
# Stability Test - Signal Generation Check
# Analyzes signal generation service for issues

set -e

# Colors for output
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

SERVICE="fks_app"
TIME_WINDOW="48h"  # Days 2-3

echo "======================================"
echo "Signal Generation Service Analysis"
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

echo -e "${BLUE}--- Signal Generation Health ---${NC}"

# Check health endpoint
if curl -s -f -m 5 "http://localhost:8002/health" > /dev/null 2>&1; then
    echo -e "${GREEN}✅ Service health check: PASSED${NC}"
else
    echo -e "${RED}❌ Service health check: FAILED${NC}"
fi

echo ""
echo -e "${BLUE}--- Signal Generation Errors ---${NC}"

# Count signal generation errors
ERROR_COUNT=$(docker logs $SERVICE --since $TIME_WINDOW 2>&1 | grep -iE "error|exception|failed|signal.*fail" | wc -l)
echo "Total Errors: $ERROR_COUNT"

if [ $ERROR_COUNT -gt 0 ]; then
    echo ""
    echo "Error Types:"
    docker logs $SERVICE --since $TIME_WINDOW 2>&1 | grep -iE "error|exception|failed|signal.*fail" | \
        sed 's/.*\([Ee]rror\|[Ee]xception\|[Ff]ailed\).*/\1/i' | \
        sort | uniq -c | sort -rn | head -10 | sed 's/^/  /'
fi

echo ""
echo -e "${BLUE}--- Signal Generation Failures ---${NC}"

# Check for specific signal generation failure patterns
SIGNAL_FAILURES=$(docker logs $SERVICE --since $TIME_WINDOW 2>&1 | grep -iE "failed to generate|signal.*generation.*fail|generate.*signal.*error" | wc -l)
echo "Signal Generation Failures: $SIGNAL_FAILURES"

if [ $SIGNAL_FAILURES -gt 0 ]; then
    echo ""
    echo "Recent Signal Generation Failures:"
    docker logs $SERVICE --since $TIME_WINDOW 2>&1 | grep -iE "failed to generate|signal.*generation.*fail|generate.*signal.*error" | tail -10 | sed 's/^/  /'
fi

echo ""
echo -e "${BLUE}--- Data Dependency Issues ---${NC}"
DATA_ERRORS=$(docker logs $SERVICE --since $TIME_WINDOW 2>&1 | grep -iE "missing.*data|no.*data|data.*not.*available|insufficient.*data" | wc -l)
echo "Data Dependency Errors: $DATA_ERRORS"

if [ $DATA_ERRORS -gt 0 ]; then
    echo ""
    echo "Recent Data Dependency Errors:"
    docker logs $SERVICE --since $TIME_WINDOW 2>&1 | grep -iE "missing.*data|no.*data|data.*not.*available|insufficient.*data" | tail -10 | sed 's/^/  /'
fi

echo ""
echo -e "${BLUE}--- Pipeline Issues ---${NC}"
PIPELINE_ERRORS=$(docker logs $SERVICE --since $TIME_WINDOW 2>&1 | grep -iE "pipeline.*error|pipeline.*fail|signal.*pipeline" | wc -l)
echo "Pipeline Errors: $PIPELINE_ERRORS"

if [ $PIPELINE_ERRORS -gt 0 ]; then
    echo ""
    echo "Recent Pipeline Errors:"
    docker logs $SERVICE --since $TIME_WINDOW 2>&1 | grep -iE "pipeline.*error|pipeline.*fail|signal.*pipeline" | tail -10 | sed 's/^/  /'
fi

echo ""
echo -e "${BLUE}--- AI Enhancement Issues ---${NC}"
AI_ERRORS=$(docker logs $SERVICE --since $TIME_WINDOW 2>&1 | grep -iE "ai.*error|enhancement.*fail|ai.*service.*error" | wc -l)
echo "AI Enhancement Errors: $AI_ERRORS"

if [ $AI_ERRORS -gt 0 ]; then
    echo ""
    echo "Recent AI Enhancement Errors:"
    docker logs $SERVICE --since $TIME_WINDOW 2>&1 | grep -iE "ai.*error|enhancement.*fail|ai.*service.*error" | tail -10 | sed 's/^/  /'
fi

echo ""
echo -e "${BLUE}--- Validation Issues ---${NC}"
VALIDATION_ERRORS=$(docker logs $SERVICE --since $TIME_WINDOW 2>&1 | grep -iE "validation.*error|validation.*fail|invalid.*signal" | wc -l)
echo "Validation Errors: $VALIDATION_ERRORS"

if [ $VALIDATION_ERRORS -gt 0 ]; then
    echo ""
    echo "Recent Validation Errors:"
    docker logs $SERVICE --since $TIME_WINDOW 2>&1 | grep -iE "validation.*error|validation.*fail|invalid.*signal" | tail -10 | sed 's/^/  /'
fi

echo ""
echo -e "${BLUE}--- Quality Scoring Issues ---${NC}"
QUALITY_ERRORS=$(docker logs $SERVICE --since $TIME_WINDOW 2>&1 | grep -iE "quality.*error|quality.*score.*error|scoring.*error" | wc -l)
echo "Quality Scoring Errors: $QUALITY_ERRORS"

echo ""
echo "======================================"
echo "Summary"
echo "======================================"
echo "Total Errors: $ERROR_COUNT"
echo "Signal Generation Failures: $SIGNAL_FAILURES"
echo "Data Dependency Errors: $DATA_ERRORS"
echo "Pipeline Errors: $PIPELINE_ERRORS"
echo "AI Enhancement Errors: $AI_ERRORS"
echo "Validation Errors: $VALIDATION_ERRORS"

if [ $SIGNAL_FAILURES -gt 10 ] || [ $ERROR_COUNT -gt 50 ]; then
    echo ""
    echo -e "${RED}⚠️  High error rate detected - review logs${NC}"
    exit 1
else
    echo ""
    echo -e "${GREEN}✅ Signal generation appears stable${NC}"
    exit 0
fi

