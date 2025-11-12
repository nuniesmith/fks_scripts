#!/bin/bash
# Generate test summary for all FKS services
# Usage: ./test_summary.sh

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}FKS Platform Test Summary${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

# Test directories
AI_DIR="repo/ai"
TRAINING_DIR="repo/training"
ANALYZE_DIR="repo/analyze"

# Function to count tests
count_tests() {
    local service_dir=$1
    local test_dir="$service_dir/tests"
    
    if [ ! -d "$test_dir" ]; then
        echo "0"
        return
    fi
    
    # Count test files
    find "$test_dir" -name "test_*.py" | wc -l
}

# Function to get test structure
get_test_structure() {
    local service_dir=$1
    local test_dir="$service_dir/tests"
    
    if [ ! -d "$test_dir" ]; then
        echo "No tests directory"
        return
    fi
    
    echo "Test Structure:"
    find "$test_dir" -name "test_*.py" | sed "s|$test_dir/||" | sort
}

# Summary
echo -e "${YELLOW}Service Test Summary${NC}"
echo ""

# fks_ai
if [ -d "$AI_DIR/tests" ]; then
    ai_tests=$(count_tests "$AI_DIR")
    echo -e "${GREEN}fks_ai${NC}: $ai_tests test files"
    get_test_structure "$AI_DIR" | head -10
    echo ""
fi

# fks_training
if [ -d "$TRAINING_DIR/tests" ]; then
    training_tests=$(count_tests "$TRAINING_DIR")
    echo -e "${GREEN}fks_training${NC}: $training_tests test files"
    get_test_structure "$TRAINING_DIR" | head -10
    echo ""
fi

# fks_analyze
if [ -d "$ANALYZE_DIR/tests" ]; then
    analyze_tests=$(count_tests "$ANALYZE_DIR")
    echo -e "${GREEN}fks_analyze${NC}: $analyze_tests test files"
    get_test_structure "$ANALYZE_DIR" | head -15
    echo ""
fi

# Total
total_tests=$(($(count_tests "$AI_DIR") + $(count_tests "$TRAINING_DIR") + $(count_tests "$ANALYZE_DIR")))
echo -e "${GREEN}Total Test Files: $total_tests${NC}"
echo ""

echo -e "${YELLOW}Test Execution Commands${NC}"
echo ""
echo "Run all tests:"
echo "  ./repo/main/scripts/run_all_tests.sh all"
echo ""
echo "Run specific service:"
echo "  ./repo/main/scripts/run_all_tests.sh ai"
echo "  ./repo/main/scripts/run_all_tests.sh training"
echo "  ./repo/main/scripts/run_all_tests.sh analyze"
echo ""
echo "Run with coverage:"
echo "  ./repo/main/scripts/run_all_tests.sh all true"
echo ""

