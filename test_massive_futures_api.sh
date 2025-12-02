#!/bin/bash
# Script to test Massive.com Futures REST API endpoints
# Usage: ./test_massive_futures_api.sh [base_url] [api_key]

set -e

BASE_URL="${1:-http://localhost:8003}"
API_KEY="${2:-}"

echo "=== Massive.com Futures API Test ==="
echo "Base URL: $BASE_URL"
echo ""

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Test counter
TESTS_PASSED=0
TESTS_FAILED=0

# Function to test endpoint
test_endpoint() {
    local name="$1"
    local url="$2"
    local expected_status="${3:-200}"
    
    echo -n "Testing $name... "
    
    response=$(curl -s -w "\n%{http_code}" "$url" 2>&1)
    http_code=$(echo "$response" | tail -n1)
    body=$(echo "$response" | sed '$d')
    
    if [ "$http_code" -eq "$expected_status" ]; then
        echo -e "${GREEN}✓${NC} (HTTP $http_code)"
        # Check if response is valid JSON
        if echo "$body" | jq . >/dev/null 2>&1; then
            echo "  Response: Valid JSON"
            # Show sample data if available
            if echo "$body" | jq -e '.results[0]' >/dev/null 2>&1; then
                result_count=$(echo "$body" | jq '.results | length')
                echo "  Results: $result_count items"
            fi
        else
            echo "  Response: Not JSON (may be error message)"
        fi
        ((TESTS_PASSED++))
        return 0
    else
        echo -e "${RED}✗${NC} (HTTP $http_code)"
        echo "  Error: $body" | head -3
        ((TESTS_FAILED++))
        return 1
    fi
}

# Test 1: Health check
echo "📊 Test 1: Service Health"
test_endpoint "Health Check" "$BASE_URL/health" 200
echo ""

# Test 2: Contracts list
echo "📊 Test 2: Contracts List"
test_endpoint "Get Contracts (ES)" "$BASE_URL/api/v1/futures/contracts?product_code=ES&limit=10" 200
echo ""

# Test 3: Contracts with filters
echo "📊 Test 3: Contracts with Filters"
test_endpoint "Get Active Contracts" "$BASE_URL/api/v1/futures/contracts?active=true&limit=5" 200
echo ""

# Test 4: Specific contract
echo "📊 Test 4: Contract Details"
# Try to get a contract (ESU0 is common)
test_endpoint "Get Contract ESU0" "$BASE_URL/api/v1/futures/contracts/ESU0" 200
echo ""

# Test 5: Products list
echo "📊 Test 5: Products List"
test_endpoint "Get Products" "$BASE_URL/api/v1/futures/products?limit=10" 200
echo ""

# Test 6: Product details
echo "📊 Test 6: Product Details"
test_endpoint "Get Product ES" "$BASE_URL/api/v1/futures/products/ES" 200
echo ""

# Test 7: Schedules
echo "📊 Test 7: Schedules"
test_endpoint "Get Schedules" "$BASE_URL/api/v1/futures/schedules?limit=5" 200
echo ""

# Test 8: Aggregates (OHLCV)
echo "📊 Test 8: Aggregate Bars"
test_endpoint "Get Aggregates (ESU0)" "$BASE_URL/api/v1/futures/aggs/ESU0?resolution=1min&limit=100" 200
echo ""

# Test 9: Trades
echo "📊 Test 9: Trades"
test_endpoint "Get Trades (ESU0)" "$BASE_URL/api/v1/futures/trades/ESU0?limit=10" 200
echo ""

# Test 10: Quotes
echo "📊 Test 10: Quotes"
test_endpoint "Get Quotes (ESU0)" "$BASE_URL/api/v1/futures/quotes/ESU0?limit=10" 200
echo ""

# Test 11: Market Status
echo "📊 Test 11: Market Status"
test_endpoint "Get Market Status" "$BASE_URL/api/v1/futures/market-status" 200
echo ""

# Test 12: Exchanges
echo "📊 Test 12: Exchanges"
test_endpoint "Get Exchanges" "$BASE_URL/api/v1/futures/exchanges" 200
echo ""

# Summary
echo "=== Test Summary ==="
echo -e "${GREEN}Passed: $TESTS_PASSED${NC}"
echo -e "${RED}Failed: $TESTS_FAILED${NC}"
echo ""

if [ $TESTS_FAILED -eq 0 ]; then
    echo -e "${GREEN}✅ All tests passed!${NC}"
    exit 0
else
    echo -e "${YELLOW}⚠️  Some tests failed. Check API key configuration and service status.${NC}"
    echo ""
    echo "💡 Troubleshooting:"
    echo "  1. Check if fks_data service is running: docker compose ps fks-data"
    echo "  2. Verify API key is set: docker compose exec fks-data env | grep MASSIVE"
    echo "  3. Check service logs: docker compose logs fks-data"
    exit 1
fi
