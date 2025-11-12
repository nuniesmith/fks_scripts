#!/bin/bash
# Run all tests for FKS Platform implementations
# Usage: ./run_all_tests.sh [service] [options]

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Default options
SERVICE="${1:-all}"
COVERAGE="${2:-false}"
VERBOSE="${3:-true}"

# Test directories
AI_DIR="repo/ai"
TRAINING_DIR="repo/training"
ANALYZE_DIR="repo/analyze"

# Function to run tests
run_tests() {
    local service_dir=$1
    local service_name=$2
    
    echo -e "${YELLOW}========================================${NC}"
    echo -e "${YELLOW}Testing ${service_name}...${NC}"
    echo -e "${YELLOW}========================================${NC}"
    
    cd "$service_dir" || exit 1
    
    if [ "$COVERAGE" = "true" ]; then
        echo "Running tests with coverage..."
        python -m pytest tests/ -v --cov=src --cov-report=term-missing --cov-report=html
    else
        if [ "$VERBOSE" = "true" ]; then
            python -m pytest tests/ -v --tb=short
        else
            python -m pytest tests/ --tb=short
        fi
    fi
    
    local exit_code=$?
    cd - > /dev/null || exit 1
    
    if [ $exit_code -eq 0 ]; then
        echo -e "${GREEN}✓ ${service_name} tests passed${NC}"
        return 0
    else
        echo -e "${RED}✗ ${service_name} tests failed${NC}"
        return 1
    fi
}

# Main execution
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}FKS Platform Test Suite${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

# Check if we're in the right directory
if [ ! -d "repo" ]; then
    echo -e "${RED}Error: Must run from FKS project root${NC}"
    exit 1
fi

# Track results
FAILED=0
PASSED=0

# Run tests based on service
case "$SERVICE" in
    "ai"|"fks_ai")
        if run_tests "$AI_DIR" "fks_ai"; then
            ((PASSED++))
        else
            ((FAILED++))
        fi
        ;;
    "training"|"fks_training")
        if run_tests "$TRAINING_DIR" "fks_training"; then
            ((PASSED++))
        else
            ((FAILED++))
        fi
        ;;
    "analyze"|"fks_analyze")
        if run_tests "$ANALYZE_DIR" "fks_analyze"; then
            ((PASSED++))
        else
            ((FAILED++))
        fi
        ;;
    "all")
        # Run all tests
        if run_tests "$AI_DIR" "fks_ai"; then
            ((PASSED++))
        else
            ((FAILED++))
        fi
        
        if run_tests "$TRAINING_DIR" "fks_training"; then
            ((PASSED++))
        else
            ((FAILED++))
        fi
        
        if run_tests "$ANALYZE_DIR" "fks_analyze"; then
            ((PASSED++))
        else
            ((FAILED++))
        fi
        ;;
    *)
        echo -e "${RED}Unknown service: $SERVICE${NC}"
        echo "Usage: $0 [ai|training|analyze|all] [coverage] [verbose]"
        exit 1
        ;;
esac

# Summary
echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Test Summary${NC}"
echo -e "${GREEN}========================================${NC}"
echo -e "Passed: ${GREEN}${PASSED}${NC}"
echo -e "Failed: ${RED}${FAILED}${NC}"

if [ $FAILED -eq 0 ]; then
    echo -e "${GREEN}All tests passed! ✓${NC}"
    exit 0
else
    echo -e "${RED}Some tests failed. Please review the output above.${NC}"
    exit 1
fi

