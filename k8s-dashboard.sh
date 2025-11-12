#!/usr/bin/env bash
# FKS Platform - Kubernetes Dashboard Auto-Login Script
# Automatically starts K8s dashboard and logs in with saved token

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TOKEN_FILE="$PROJECT_ROOT/k8s/dashboard-token.txt"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if kubectl is available
if ! command -v kubectl &> /dev/null; then
    log_error "kubectl not found. Please install kubectl first."
    exit 1
fi

# Check if cluster is running
if ! kubectl cluster-info &> /dev/null; then
    log_warn "Kubernetes cluster not running. Starting minikube..."
    
    if ! command -v minikube &> /dev/null; then
        log_error "minikube not found. Please install minikube or start your K8s cluster."
        exit 1
    fi
    
    log_info "Starting minikube with 6 CPUs, 16GB RAM..."
    minikube start --cpus=6 --memory=16384 --disk-size=50g
    
    log_info "Enabling required addons..."
    minikube addons enable ingress
    minikube addons enable metrics-server
    minikube addons enable dashboard
fi

# Deploy Kubernetes Dashboard if not already deployed
log_info "Checking for Kubernetes Dashboard..."
if ! kubectl get namespace kubernetes-dashboard &> /dev/null; then
    log_info "Deploying Kubernetes Dashboard..."
    kubectl apply -f https://raw.githubusercontent.com/kubernetes/dashboard/v2.7.0/aio/deploy/recommended.yaml
    
    # Wait for dashboard to be ready
    log_info "Waiting for dashboard to be ready..."
    kubectl wait --for=condition=available --timeout=300s deployment/kubernetes-dashboard -n kubernetes-dashboard
    
    # Create admin user and get token
    log_info "Creating admin user..."
    cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ServiceAccount
metadata:
  name: admin-user
  namespace: kubernetes-dashboard
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: admin-user
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-admin
subjects:
- kind: ServiceAccount
  name: admin-user
  namespace: kubernetes-dashboard
---
apiVersion: v1
kind: Secret
metadata:
  name: admin-user-token
  namespace: kubernetes-dashboard
  annotations:
    kubernetes.io/service-account.name: admin-user
type: kubernetes.io/service-account-token
EOF
    
    # Wait a moment for token to be created
    sleep 5
    
    # Get token and save it
    TOKEN=$(kubectl get secret admin-user-token -n kubernetes-dashboard -o jsonpath='{.data.token}' | base64 --decode)
    
    # Save token to file
    mkdir -p "$PROJECT_ROOT/k8s"
    cat > "$TOKEN_FILE" <<EOF
Kubernetes Dashboard Admin Token
================================

Token:
$TOKEN

Access URL:
http://localhost:8001/api/v1/namespaces/kubernetes-dashboard/services/https:kubernetes-dashboard:/proxy/

To start the dashboard:
1. Run: kubectl proxy
2. Open the URL above in your browser
3. Choose "Token" authentication
4. Paste the token above

To start proxy in background:
kubectl proxy &

To stop proxy:
pkill -f "kubectl proxy"

EOF
    log_info "Token saved to $TOKEN_FILE"
else
    log_info "Dashboard already deployed"
fi

# Extract token from file
if [ ! -f "$TOKEN_FILE" ]; then
    log_error "Token file not found: $TOKEN_FILE"
    log_error "Please run the K8s dashboard setup first"
    exit 1
fi

TOKEN=$(grep -A 1 "^Token:" "$TOKEN_FILE" | tail -n 1 | xargs)

if [ -z "$TOKEN" ]; then
    log_error "Could not extract token from $TOKEN_FILE"
    exit 1
fi

# Kill any existing kubectl proxy
log_info "Stopping existing kubectl proxy instances..."
pkill -f "kubectl proxy" 2>/dev/null || true
sleep 1

# Start kubectl proxy in background
log_info "Starting kubectl proxy..."
kubectl proxy &
PROXY_PID=$!
sleep 3

# Dashboard URL - Use the service directly without the https: prefix
DASHBOARD_URL="http://localhost:8001/api/v1/namespaces/kubernetes-dashboard/services/kubernetes-dashboard:/proxy/"

echo ""
echo "=============================================="
echo -e "${GREEN}Kubernetes Dashboard is Ready!${NC}"
echo "=============================================="
echo ""
echo "Dashboard URL: $DASHBOARD_URL"
echo ""
echo -e "${YELLOW}Auto-Login Token (copied to clipboard):${NC}"
echo "$TOKEN"
echo ""
echo "Opening browser..."
echo ""
echo -e "${BLUE}Instructions:${NC}"
echo "1. Browser will open automatically"
echo "2. Select 'Token' authentication"
echo "3. Paste token (already in clipboard)"
echo "4. Click 'Sign in'"
echo ""
echo -e "${YELLOW}To stop dashboard:${NC}"
echo "  pkill -f 'kubectl proxy'"
echo ""

# Copy token to clipboard
if command -v xclip &> /dev/null; then
    echo -n "$TOKEN" | xclip -selection clipboard
    log_info "Token copied to clipboard (xclip)"
elif command -v xsel &> /dev/null; then
    echo -n "$TOKEN" | xsel --clipboard --input
    log_info "Token copied to clipboard (xsel)"
elif command -v wl-copy &> /dev/null; then
    echo -n "$TOKEN" | wl-copy
    log_info "Token copied to clipboard (wl-copy)"
else
    log_warn "No clipboard tool found. Please copy token manually from above."
fi

# Open browser
sleep 2
if command -v xdg-open &> /dev/null; then
    xdg-open "$DASHBOARD_URL" &>/dev/null &
elif command -v open &> /dev/null; then
    open "$DASHBOARD_URL" &>/dev/null &
else
    log_warn "Could not detect browser opener. Please open URL manually:"
    echo "$DASHBOARD_URL"
fi

echo ""
log_info "kubectl proxy running in background (PID: $PROXY_PID)"
log_info "Dashboard is now accessible at: $DASHBOARD_URL"
echo ""
