#!/bin/bash
# Kubernetes Dashboard Quick Start with Auto-Login
# One command to start dashboard with token ready to paste

set -e

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TOKEN_FILE="$PROJECT_ROOT/k8s/dashboard-token.txt"
PROXY_PORT=8001
DASHBOARD_NAMESPACE="kubernetes-dashboard"

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${BLUE}🚀 Starting Kubernetes Dashboard...${NC}"

# Check if token file exists
if [ ! -f "$TOKEN_FILE" ]; then
    echo -e "${YELLOW}⚠️  Token file not found. Creating admin user...${NC}"
    ./scripts/setup-k8s-dashboard.sh
fi

# Get token
TOKEN=$(grep -A 1 "^Token:" "$TOKEN_FILE" 2>/dev/null | tail -n 1 | xargs)

if [ -z "$TOKEN" ]; then
    echo "❌ Could not get token. Please run: ./scripts/setup-k8s-dashboard.sh"
    exit 1
fi

# Kill existing proxy
echo "🛑 Stopping existing kubectl proxy..."
pkill -f "kubectl proxy" 2>/dev/null || true
sleep 1

# Start kubectl proxy
echo "🚀 Starting kubectl proxy on port $PROXY_PORT..."
kubectl proxy --port=$PROXY_PORT --address=127.0.0.1 --disable-filter=true > /dev/null 2>&1 &
PROXY_PID=$!
sleep 3

# Verify proxy is running
if ! kill -0 $PROXY_PID 2>/dev/null; then
    echo "❌ Failed to start kubectl proxy"
    exit 1
fi

# Copy token to clipboard
echo "📋 Copying token to clipboard..."
if command -v xclip &> /dev/null; then
    echo -n "$TOKEN" | xclip -selection clipboard
    CLIPBOARD_TOOL="xclip"
elif command -v xsel &> /dev/null; then
    echo -n "$TOKEN" | xsel --clipboard --input
    CLIPBOARD_TOOL="xsel"
elif command -v wl-copy &> /dev/null; then
    echo -n "$TOKEN" | wl-copy
    CLIPBOARD_TOOL="wl-copy"
elif command -v pbcopy &> /dev/null; then
    echo -n "$TOKEN" | pbcopy
    CLIPBOARD_TOOL="pbcopy"
else
    CLIPBOARD_TOOL="none"
    echo -e "${YELLOW}⚠️  No clipboard tool found. Token:${NC}"
    echo "$TOKEN"
fi

# Dashboard URL
DASHBOARD_URL="http://localhost:${PROXY_PORT}/api/v1/namespaces/${DASHBOARD_NAMESPACE}/services/https:kubernetes-dashboard:/proxy/"

# Open browser
echo "🌐 Opening dashboard in browser..."
if command -v xdg-open &> /dev/null; then
    xdg-open "$DASHBOARD_URL" &>/dev/null &
elif command -v open &> /dev/null; then
    open "$DASHBOARD_URL" &>/dev/null &
fi

# Display info
echo ""
echo -e "${GREEN}╔═══════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║  Kubernetes Dashboard Started!               ║${NC}"
echo -e "${GREEN}╚═══════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${BLUE}Dashboard URL:${NC}"
echo "  $DASHBOARD_URL"
echo ""
echo -e "${BLUE}Token:${NC}"
if [ "$CLIPBOARD_TOOL" != "none" ]; then
    echo -e "  ${GREEN}✅ Copied to clipboard (${CLIPBOARD_TOOL})${NC}"
    echo "  Just paste it when prompted (Ctrl+V / Cmd+V)"
else
    echo "  $TOKEN"
fi
echo ""
echo -e "${BLUE}Proxy PID:${NC} $PROXY_PID"
echo ""
echo -e "${YELLOW}To stop dashboard:${NC}"
echo "  kill $PROXY_PID"
echo "  or: pkill -f 'kubectl proxy'"
echo ""
echo -e "${YELLOW}To restart:${NC}"
echo "  ./scripts/k8s-dashboard-quick-start.sh"
echo ""

