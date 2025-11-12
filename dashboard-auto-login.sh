#!/bin/bash
# Kubernetes Dashboard Auto-Login
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
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${CYAN}╔═══════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║  Kubernetes Dashboard - Auto Login           ║${NC}"
echo -e "${CYAN}╚═══════════════════════════════════════════════╝${NC}"
echo ""

# Check if token file exists
if [ ! -f "$TOKEN_FILE" ]; then
    echo -e "${YELLOW}⚠️  Token file not found. Creating admin user...${NC}"
    ./scripts/setup-k8s-dashboard.sh
fi

# Get token
TOKEN=$(grep -A 1 "^Token:" "$TOKEN_FILE" 2>/dev/null | tail -n 1 | xargs)

if [ -z "$TOKEN" ]; then
    echo -e "${YELLOW}❌ Could not get token. Creating admin user...${NC}"
    kubectl apply -f "$PROJECT_ROOT/k8s/manifests/dashboard-admin-user.yaml" 2>/dev/null || true
    sleep 5
    TOKEN=$(kubectl get secret admin-user-token -n "$DASHBOARD_NAMESPACE" -o jsonpath='{.data.token}' 2>/dev/null | base64 -d 2>/dev/null || kubectl get secret admin-user-secret -n "$DASHBOARD_NAMESPACE" -o jsonpath='{.data.token}' 2>/dev/null | base64 -d 2>/dev/null || echo "")
    
    if [ -z "$TOKEN" ]; then
        echo -e "${YELLOW}❌ Could not get token. Please run: ./scripts/setup-k8s-dashboard.sh${NC}"
        exit 1
    fi
fi

# Kill existing proxy
echo -e "${BLUE}🛑 Stopping existing kubectl proxy...${NC}"
pkill -f "kubectl proxy" 2>/dev/null || true
sleep 1

# Start kubectl proxy
echo -e "${BLUE}🚀 Starting kubectl proxy on port $PROXY_PORT...${NC}"
kubectl proxy --port=$PROXY_PORT --address=127.0.0.1 --disable-filter=true > /dev/null 2>&1 &
PROXY_PID=$!
sleep 3

# Verify proxy is running
if ! kill -0 $PROXY_PID 2>/dev/null; then
    echo -e "${YELLOW}❌ Failed to start kubectl proxy${NC}"
    exit 1
fi

# Copy token to clipboard
echo -e "${BLUE}📋 Copying token to clipboard...${NC}"
CLIPBOARD_SUCCESS=false
if command -v xclip &> /dev/null; then
    echo -n "$TOKEN" | xclip -selection clipboard && CLIPBOARD_SUCCESS=true
elif command -v xsel &> /dev/null; then
    echo -n "$TOKEN" | xsel --clipboard --input && CLIPBOARD_SUCCESS=true
elif command -v wl-copy &> /dev/null; then
    echo -n "$TOKEN" | wl-copy && CLIPBOARD_SUCCESS=true
elif command -v pbcopy &> /dev/null; then
    echo -n "$TOKEN" | pbcopy && CLIPBOARD_SUCCESS=true
fi

# Dashboard URL
DASHBOARD_URL="http://localhost:${PROXY_PORT}/api/v1/namespaces/${DASHBOARD_NAMESPACE}/services/https:kubernetes-dashboard:/proxy/"

# Open browser
echo -e "${BLUE}🌐 Opening dashboard in browser...${NC}"
if command -v xdg-open &> /dev/null; then
    xdg-open "$DASHBOARD_URL" &>/dev/null &
elif command -v open &> /dev/null; then
    open "$DASHBOARD_URL" &>/dev/null &
fi

# Display info
echo ""
echo -e "${GREEN}╔═══════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║  Dashboard Started Successfully!              ║${NC}"
echo -e "${GREEN}╚═══════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${CYAN}Dashboard URL:${NC}"
echo "  $DASHBOARD_URL"
echo ""
echo -e "${CYAN}Token:${NC}"
if [ "$CLIPBOARD_SUCCESS" = true ]; then
    echo -e "  ${GREEN}✅ Copied to clipboard!${NC}"
    echo -e "  ${YELLOW}Just paste it when prompted (Ctrl+V / Cmd+V)${NC}"
else
    echo -e "  ${YELLOW}⚠️  Could not copy to clipboard. Token:${NC}"
    echo "  $TOKEN"
fi
echo ""
echo -e "${CYAN}Proxy PID:${NC} $PROXY_PID"
echo ""
echo -e "${YELLOW}To stop dashboard:${NC}"
echo "  kill $PROXY_PID"
echo "  or: pkill -f 'kubectl proxy'"
echo ""
echo -e "${YELLOW}To restart:${NC}"
echo "  ./scripts/dashboard-auto-login.sh"
echo ""

