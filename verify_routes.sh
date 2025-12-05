#!/bin/bash
# Quick script to verify v1 trading routes are registered

set -euo pipefail

API_URL="${1:-http://localhost:8001}"

echo "🔍 Checking if v1 trading routes are registered..."
echo "API URL: $API_URL"
echo ""

# Check OpenAPI spec for v1/trading routes
TRADING_ROUTES=$(curl -s "$API_URL/api/openapi.json" 2>/dev/null | \
    python3 -c "import sys, json; data=json.load(sys.stdin); routes=[p for p in data.get('paths', {}).keys() if 'v1/trading' in p]; print('\n'.join(sorted(routes)))" 2>/dev/null || echo "")

if [ -z "$TRADING_ROUTES" ]; then
    echo "❌ No v1/trading routes found!"
    echo ""
    echo "The API server needs to be restarted to register v1 routes."
    echo "After restarting, run this script again to verify."
    exit 1
else
    echo "✅ Found v1/trading routes:"
    echo "$TRADING_ROUTES" | while read -r route; do
        echo "   - $route"
    done
    echo ""
    echo "✅ Routes are registered! You can now run rate limiting tests."
    exit 0
fi
