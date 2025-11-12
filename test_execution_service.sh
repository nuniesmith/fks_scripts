#!/bin/bash
# Test FKS Execution Service

set -e

echo "🧪 FKS Execution Service Test Suite"
echo "===================================="
echo ""

# Check if service is accessible
echo "1. Testing health endpoint..."
HEALTH=$(curl -s http://localhost:8000/health)
if echo "$HEALTH" | grep -q "healthy"; then
    echo "   ✅ Health check passed"
else
    echo "   ❌ Health check failed"
    exit 1
fi
echo ""

# Send test webhooks
echo "2. Sending test webhooks (20 requests)..."
SUCCESS=0
FAIL=0

for i in {1..20}; do
    CONFIDENCE=$(awk -v min=0.60 -v max=0.99 'BEGIN{srand(); print min+rand()*(max-min)}')
    SYMBOLS=("BTCUSDT" "ETHUSDT" "SOLUSDT" "ADAUSDT")
    SIDES=("buy" "sell")
    
    SYMBOL=${SYMBOLS[$RANDOM % ${#SYMBOLS[@]}]}
    SIDE=${SIDES[$RANDOM % ${#SIDES[@]}]}
    
    RESPONSE=$(curl -s -X POST http://localhost:8000/webhook/tradingview \
        -H "Content-Type: application/json" \
        -d "{\"symbol\":\"$SYMBOL\",\"side\":\"$SIDE\",\"confidence\":$CONFIDENCE}")
    
    if echo "$RESPONSE" | grep -q "simulated"; then
        ((SUCCESS++))
        echo "   [$i/20] ✅ $SYMBOL $SIDE @ $CONFIDENCE"
    else
        ((FAIL++))
        echo "   [$i/20] ❌ Failed"
    fi
    
    sleep 0.2
done

echo ""
echo "Results: $SUCCESS success, $FAIL failures"
echo ""

# Check metrics
echo "3. Checking Prometheus metrics..."
METRICS=$(curl -s http://localhost:8000/metrics)
if [ -n "$METRICS" ]; then
    WEBHOOK_COUNT=$(echo "$METRICS" | grep "webhook_requests_total" | grep -v "#" | awk '{print $2}' || echo "0")
    echo "   ✅ Metrics endpoint accessible"
    echo "   📊 Total webhooks: $WEBHOOK_COUNT"
else
    echo "   ⚠️  Metrics endpoint empty (check FastAPI /metrics mount)"
fi
echo ""

# Pod status
echo "4. Checking pod status..."
kubectl get pods -n fks-trading -l app=fks-execution --no-headers | while read line; do
    POD_NAME=$(echo $line | awk '{print $1}')
    STATUS=$(echo $line | awk '{print $3}')
    echo "   Pod: $POD_NAME - $STATUS"
done
echo ""

echo "===================================="
echo "✅ Test suite complete!"
echo ""
echo "Next steps:"
echo "  • Access Grafana: http://localhost:3000"
echo "  • View metrics in Prometheus: http://localhost:9090"
echo "  • Import dashboard from: /home/jordan/fks/monitoring/grafana/dashboards/"
