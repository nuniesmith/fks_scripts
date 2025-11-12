#!/bin/bash
# Simple Kubernetes Dashboard Starter
# Starts kubectl proxy and opens dashboard with token in clipboard

set -e

# Configuration
TOKEN_FILE="k8s/dashboard-token.txt"
PROXY_PORT=8001
DASHBOARD_NAMESPACE="kubernetes-dashboard"

# Get token
if [ ! -f "$TOKEN_FILE" ]; then
    echo "❌ Token file not found: $TOKEN_FILE"
    echo "Please run: ./scripts/setup-k8s-dashboard.sh"
    exit 1
fi

TOKEN=$(grep -A 1 "^Token:" "$TOKEN_FILE" | tail -n 1 | xargs)

if [ -z "$TOKEN" ]; then
    echo "❌ Could not extract token from $TOKEN_FILE"
    exit 1
fi

# Kill existing proxy
pkill -f "kubectl proxy" 2>/dev/null || true
sleep 1

# Start kubectl proxy
echo "🚀 Starting kubectl proxy..."
kubectl proxy --port=$PROXY_PORT --address=127.0.0.1 --disable-filter=true > /dev/null 2>&1 &
PROXY_PID=$!
sleep 2

# Copy token to clipboard
if command -v xclip &> /dev/null; then
    echo -n "$TOKEN" | xclip -selection clipboard
    echo "✅ Token copied to clipboard (xclip)"
elif command -v xsel &> /dev/null; then
    echo -n "$TOKEN" | xsel --clipboard --input
    echo "✅ Token copied to clipboard (xsel)"
elif command -v pbcopy &> /dev/null; then
    echo -n "$TOKEN" | pbcopy
    echo "✅ Token copied to clipboard (pbcopy)"
else
    echo "⚠️  No clipboard tool found. Token:"
    echo "$TOKEN"
fi

# Open dashboard
DASHBOARD_URL="http://localhost:${PROXY_PORT}/api/v1/namespaces/${DASHBOARD_NAMESPACE}/services/https:kubernetes-dashboard:/proxy/"
echo "🌐 Opening dashboard: $DASHBOARD_URL"

if command -v xdg-open &> /dev/null; then
    xdg-open "$DASHBOARD_URL" &>/dev/null &
elif command -v open &> /dev/null; then
    open "$DASHBOARD_URL" &>/dev/null &
else
    echo "⚠️  Could not detect browser. Please open: $DASHBOARD_URL"
fi

echo ""
echo "✅ Dashboard started!"
echo "   URL: $DASHBOARD_URL"
echo "   Token: (copied to clipboard - just paste it)"
echo "   Proxy PID: $PROXY_PID"
echo ""
echo "To stop: kill $PROXY_PID or pkill -f 'kubectl proxy'"
echo ""

