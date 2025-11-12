#!/bin/bash
# Test script for TradingView webhook endpoint
# Tests the Rust execution service's webhook handler

set -e

BASE_URL="${BASE_URL:-http://localhost:4700}"
WEBHOOK_ENDPOINT="$BASE_URL/webhook/tradingview"
HEALTH_ENDPOINT="$BASE_URL/health"

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "🧪 FKS Execution Service - Webhook Endpoint Tests"
echo "=================================================="
echo ""

# Check if service is running
echo -n "Checking service health... "
if curl -s "$HEALTH_ENDPOINT" > /dev/null 2>&1; then
    echo -e "${GREEN}✓ Service is running${NC}"
else
    echo -e "${RED}✗ Service is not running${NC}"
    echo "Please start the service first:"
    echo "  cd /home/jordan/fks/src/services/execution"
    echo "  cargo run"
    exit 1
fi

echo ""
echo "Test 1: Buy Market Order"
echo "------------------------"
RESPONSE=$(curl -s -X POST "$WEBHOOK_ENDPOINT" \
  -H "Content-Type: application/json" \
  -d '{
    "symbol": "BTC/USDT",
    "action": "buy",
    "order_type": "market",
    "quantity": 0.01,
    "confidence": 0.85
  }')

echo "Response: $RESPONSE"
if echo "$RESPONSE" | grep -q '"success"'; then
    echo -e "${GREEN}✓ Test 1 passed${NC}"
else
    echo -e "${RED}✗ Test 1 failed${NC}"
fi

echo ""
echo "Test 2: Sell Limit Order with SL/TP"
echo "------------------------------------"
RESPONSE=$(curl -s -X POST "$WEBHOOK_ENDPOINT" \
  -H "Content-Type: application/json" \
  -d '{
    "symbol": "ETH/USDT",
    "action": "sell",
    "order_type": "limit",
    "quantity": 0.5,
    "price": 3500.0,
    "stop_loss": 3600.0,
    "take_profit": 3400.0,
    "confidence": 0.75
  }')

echo "Response: $RESPONSE"
if echo "$RESPONSE" | grep -q '"success"'; then
    echo -e "${GREEN}✓ Test 2 passed${NC}"
else
    echo -e "${RED}✗ Test 2 failed${NC}"
fi

echo ""
echo "Test 3: Minimal Payload (defaults)"
echo "-----------------------------------"
RESPONSE=$(curl -s -X POST "$WEBHOOK_ENDPOINT" \
  -H "Content-Type: application/json" \
  -d '{
    "symbol": "BTC/USDT",
    "action": "buy",
    "quantity": 0.01
  }')

echo "Response: $RESPONSE"
if echo "$RESPONSE" | grep -q '"success"'; then
    echo -e "${GREEN}✓ Test 3 passed${NC}"
else
    echo -e "${RED}✗ Test 3 failed${NC}"
fi

echo ""
echo "Test 4: Invalid Action (should fail)"
echo "-------------------------------------"
RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "$WEBHOOK_ENDPOINT" \
  -H "Content-Type: application/json" \
  -d '{
    "symbol": "BTC/USDT",
    "action": "invalid_action",
    "quantity": 0.01
  }')

HTTP_CODE=$(echo "$RESPONSE" | tail -1)
BODY=$(echo "$RESPONSE" | head -n -1)

echo "HTTP Code: $HTTP_CODE"
echo "Response: $BODY"

if [ "$HTTP_CODE" = "400" ]; then
    echo -e "${GREEN}✓ Test 4 passed (correctly rejected)${NC}"
else
    echo -e "${RED}✗ Test 4 failed (should return 400)${NC}"
fi

echo ""
echo "Test 5: Missing Required Fields (should fail)"
echo "----------------------------------------------"
RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "$WEBHOOK_ENDPOINT" \
  -H "Content-Type: application/json" \
  -d '{
    "symbol": "BTC/USDT",
    "action": "buy"
  }')

HTTP_CODE=$(echo "$RESPONSE" | tail -1)
BODY=$(echo "$RESPONSE" | head -n -1)

echo "HTTP Code: $HTTP_CODE"
echo "Response: $BODY"

if [ "$HTTP_CODE" = "400" ] || [ "$HTTP_CODE" = "422" ]; then
    echo -e "${GREEN}✓ Test 5 passed (correctly rejected)${NC}"
else
    echo -e "${YELLOW}⚠ Test 5: HTTP $HTTP_CODE (expected 400/422)${NC}"
fi

echo ""
echo "=================================================="
echo "All tests completed!"
