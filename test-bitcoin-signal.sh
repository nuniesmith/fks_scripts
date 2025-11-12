#!/bin/bash
# Test Bitcoin Signal Generation
# Quick test script to verify Bitcoin signal generation works

set -e

echo "=== Bitcoin Signal Generation Test ==="
echo ""

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Service URLs
DATA_SERVICE="http://localhost:8003"
APP_SERVICE="http://localhost:8002"
WEB_SERVICE="http://localhost:8000"

# Test function
test_service() {
    local name=$1
    local url=$2
    echo -n "Testing $name... "
    
    if curl -s -f "$url/health" > /dev/null 2>&1; then
        echo -e "${GREEN}✓ OK${NC}"
        return 0
    else
        echo -e "${RED}✗ FAILED${NC}"
        echo "  Service not responding at $url/health"
        return 1
    fi
}

# Test Bitcoin price
test_bitcoin_price() {
    echo -n "Testing Bitcoin price fetch... "
    
    response=$(curl -s "$DATA_SERVICE/api/v1/data/price?symbol=BTCUSDT" 2>&1)
    
    if echo "$response" | grep -q '"price"'; then
        price=$(echo "$response" | grep -o '"price":[0-9.]*' | cut -d':' -f2)
        echo -e "${GREEN}✓ OK${NC} (Price: \$$price)"
        return 0
    else
        echo -e "${RED}✗ FAILED${NC}"
        echo "  Response: $response"
        return 1
    fi
}

# Test Bitcoin OHLCV
test_bitcoin_ohlcv() {
    echo -n "Testing Bitcoin OHLCV fetch... "
    
    response=$(curl -s "$DATA_SERVICE/api/v1/data/ohlcv?symbol=BTCUSDT&interval=1h&limit=100" 2>&1)
    
    if echo "$response" | grep -q '"data"'; then
        count=$(echo "$response" | grep -o '"data":\[' | wc -l)
        echo -e "${GREEN}✓ OK${NC} (Data available)"
        return 0
    else
        echo -e "${RED}✗ FAILED${NC}"
        echo "  Response: $response"
        return 1
    fi
}

# Test Bitcoin signal generation
test_bitcoin_signal() {
    echo -n "Testing Bitcoin signal generation... "
    
    response=$(curl -s "$APP_SERVICE/api/v1/signals/latest/BTCUSDT?category=swing&use_ai=false" 2>&1)
    
    if echo "$response" | grep -q '"signal_type"'; then
        signal_type=$(echo "$response" | grep -o '"signal_type":"[^"]*"' | cut -d'"' -f4)
        confidence=$(echo "$response" | grep -o '"confidence":[0-9.]*' | cut -d':' -f2)
        entry=$(echo "$response" | grep -o '"entry_price":[0-9.]*' | cut -d':' -f2)
        
        echo -e "${GREEN}✓ OK${NC}"
        echo "  Signal: $signal_type"
        echo "  Confidence: $confidence"
        echo "  Entry: \$$entry"
        return 0
    else
        echo -e "${RED}✗ FAILED${NC}"
        echo "  Response: $response"
        return 1
    fi
}

# Main test flow
echo "Step 1: Testing Services"
echo "-----------------------"
test_service "fks_data" "$DATA_SERVICE" || exit 1
test_service "fks_app" "$APP_SERVICE" || exit 1
test_service "fks_web" "$WEB_SERVICE" || exit 1
echo ""

echo "Step 2: Testing Data Fetch"
echo "-------------------------"
test_bitcoin_price || exit 1
test_bitcoin_ohlcv || exit 1
echo ""

echo "Step 3: Testing Signal Generation"
echo "---------------------------------"
test_bitcoin_signal || exit 1
echo ""

echo -e "${GREEN}=== All Tests Passed! ===${NC}"
echo ""
echo "Next steps:"
echo "1. Open dashboard: http://localhost:8000/portfolio/signals/?symbols=BTCUSDT&category=swing"
echo "2. Review Bitcoin signals"
echo "3. Test approval workflow"
echo ""

