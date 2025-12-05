#!/bin/bash
# Complete test workflow: verify routes, then run rate limiting tests

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

API_URL="${1:-http://localhost:8001}"
TOKEN="${2:-}"

echo "🧪 Rate Limiting Test Workflow"
echo "================================"
echo "API URL: $API_URL"
echo ""

# Step 1: Verify routes are registered
echo "Step 1: Verifying v1/trading routes are registered..."
if ! bash "$SCRIPT_DIR/verify_routes.sh" "$API_URL" > /dev/null 2>&1; then
    echo ""
    echo "❌ Routes not registered!"
    echo ""
    echo "The API server needs to be restarted to register v1 routes."
    echo "After restarting, run this script again."
    echo ""
    echo "To restart:"
    echo "  cd $PROJECT_ROOT/services/api"
    echo "  # Stop current API, then:"
    echo "  python src/main.py"
    echo ""
    exit 1
fi

echo "✅ Routes are registered!"
echo ""

# Step 2: Run rate limiting tests
echo "Step 2: Running rate limiting tests..."
echo ""

if [ -n "$TOKEN" ]; then
    echo "Using authentication token..."
    python3 "$SCRIPT_DIR/test_rate_limiting.py" --base-url "$API_URL" --token "$TOKEN" --full-suite
else
    echo "Running without authentication (IP-based rate limiting)..."
    python3 "$SCRIPT_DIR/test_rate_limiting.py" --base-url "$API_URL" --full-suite
fi

TEST_EXIT_CODE=$?

echo ""
if [ $TEST_EXIT_CODE -eq 0 ]; then
    echo "✅ All tests completed successfully!"
else
    echo "⚠️  Some tests had issues - review output above"
fi

exit $TEST_EXIT_CODE
