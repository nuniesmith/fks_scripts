#!/bin/bash
# Start Kubernetes Dashboard with Auto-Login
# This script automatically starts kubectl proxy and opens the dashboard with saved token

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TOKEN_FILE="$PROJECT_ROOT/k8s/dashboard-token.txt"
PROXY_PORT=8001
DASHBOARD_NAMESPACE="kubernetes-dashboard"

# Functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if kubectl is available
check_kubectl() {
    if ! command -v kubectl &> /dev/null; then
        log_error "kubectl is not installed"
        exit 1
    fi
}

# Check if cluster is running
check_cluster() {
    if ! kubectl cluster-info &> /dev/null; then
        log_error "Kubernetes cluster is not running"
        log_info "Please start your cluster first: minikube start"
        exit 1
    fi
}

# Get or create admin token
get_admin_token() {
    log_info "Getting admin token..."
    
    # Check if token file exists and is recent (less than 24 hours old)
    if [ -f "$TOKEN_FILE" ]; then
        # Check if token is still valid (file modified within last 24 hours)
        if [ $(find "$TOKEN_FILE" -mtime -1 2>/dev/null) ]; then
            log_info "Using existing token from $TOKEN_FILE"
            TOKEN=$(grep -A 1 "^Token:" "$TOKEN_FILE" 2>/dev/null | tail -n 1 | xargs)
            if [ -n "$TOKEN" ]; then
                echo "$TOKEN"
                return 0
            fi
        fi
    fi
    
    # Create admin user if it doesn't exist
    log_info "Creating admin user..."
    kubectl apply -f - <<EOF 2>/dev/null || true
apiVersion: v1
kind: ServiceAccount
metadata:
  name: admin-user
  namespace: ${DASHBOARD_NAMESPACE}
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
  namespace: ${DASHBOARD_NAMESPACE}
---
apiVersion: v1
kind: Secret
metadata:
  name: admin-user-token
  namespace: ${DASHBOARD_NAMESPACE}
  annotations:
    kubernetes.io/service-account.name: admin-user
type: kubernetes.io/service-account-token
EOF
    
    # Wait for token to be created
    log_info "Waiting for token to be created..."
    sleep 5
    
    # Get token from secret
    TOKEN=$(kubectl get secret admin-user-token -n "$DASHBOARD_NAMESPACE" -o jsonpath='{.data.token}' 2>/dev/null | base64 --decode)
    
    if [ -z "$TOKEN" ]; then
        log_error "Failed to get admin token"
        exit 1
    fi
    
    # Save token to file
    mkdir -p "$(dirname "$TOKEN_FILE")"
    cat > "$TOKEN_FILE" <<EOF
Kubernetes Dashboard Admin Token
================================

Token:
$TOKEN

Access URL:
http://localhost:${PROXY_PORT}/api/v1/namespaces/${DASHBOARD_NAMESPACE}/services/https:kubernetes-dashboard:/proxy/

Generated: $(date)
EOF
    
    log_success "Token saved to $TOKEN_FILE"
    echo "$TOKEN"
}

# Start kubectl proxy
start_proxy() {
    log_info "Checking for existing kubectl proxy..."
    
    # Kill any existing kubectl proxy on the port
    PROXY_PID=$(lsof -ti:${PROXY_PORT} 2>/dev/null || true)
    if [ -n "$PROXY_PID" ]; then
        log_warning "Stopping existing kubectl proxy (PID: $PROXY_PID)..."
        kill $PROXY_PID 2>/dev/null || true
        sleep 2
    fi
    
    log_info "Starting kubectl proxy on port ${PROXY_PORT}..."
    kubectl proxy --port=${PROXY_PORT} --address=127.0.0.1 --disable-filter=true > /dev/null 2>&1 &
    PROXY_PID=$!
    
    # Wait for proxy to start
    sleep 3
    
    # Check if proxy is running
    if ! kill -0 $PROXY_PID 2>/dev/null; then
        log_error "Failed to start kubectl proxy"
        exit 1
    fi
    
    log_success "kubectl proxy started (PID: $PROXY_PID)"
    echo "$PROXY_PID"
}

# Open dashboard in browser with auto-login
open_dashboard() {
    local TOKEN=$1
    DASHBOARD_URL="http://localhost:${PROXY_PORT}/api/v1/namespaces/${DASHBOARD_NAMESPACE}/services/https:kubernetes-dashboard:/proxy/"
    
    log_info "Dashboard URL: $DASHBOARD_URL"
    log_info "Opening dashboard in browser..."
    
    # Create a temporary HTML file with auto-login script
    TEMP_HTML=$(mktemp /tmp/k8s-dashboard-XXXXXX.html)
    cat > "$TEMP_HTML" <<EOF
<!DOCTYPE html>
<html>
<head>
    <title>Kubernetes Dashboard - Auto Login</title>
    <meta http-equiv="refresh" content="0;url=${DASHBOARD_URL}">
    <script>
        // Wait for page to load, then auto-fill token
        window.addEventListener('load', function() {
            setTimeout(function() {
                // Try to find the token input field
                var tokenInput = document.querySelector('input[type="text"][placeholder*="token"], input[type="text"][name*="token"], input[type="password"]');
                if (tokenInput) {
                    tokenInput.value = '${TOKEN}';
                    tokenInput.type = 'text'; // Make it visible if it's password type
                    
                    // Trigger input event
                    var event = new Event('input', { bubbles: true });
                    tokenInput.dispatchEvent(event);
                    
                    // Try to find and click the login button
                    setTimeout(function() {
                        var loginButton = document.querySelector('button[type="submit"], button:contains("Sign"), button:contains("Login")');
                        if (loginButton) {
                            loginButton.click();
                        }
                    }, 500);
                }
            }, 2000);
        });
    </script>
</head>
<body>
    <p>Redirecting to Kubernetes Dashboard...</p>
    <p>If you are not redirected automatically, <a href="${DASHBOARD_URL}">click here</a>.</p>
    <p>Token has been copied to clipboard. Paste it when prompted.</p>
</body>
</html>
EOF
    
    # Copy token to clipboard (platform-specific)
    if command -v xclip &> /dev/null; then
        echo -n "$TOKEN" | xclip -selection clipboard
        log_info "Token copied to clipboard (xclip)"
    elif command -v xsel &> /dev/null; then
        echo -n "$TOKEN" | xsel --clipboard --input
        log_info "Token copied to clipboard (xsel)"
    elif command -v wl-copy &> /dev/null; then
        echo -n "$TOKEN" | wl-copy
        log_info "Token copied to clipboard (wl-copy)"
    elif command -v pbcopy &> /dev/null; then
        echo -n "$TOKEN" | pbcopy
        log_info "Token copied to clipboard (pbcopy)"
    else
        log_warning "No clipboard tool found. Token will be displayed."
    fi
    
    # Open browser
    if command -v xdg-open &> /dev/null; then
        xdg-open "$TEMP_HTML" &>/dev/null &
    elif command -v open &> /dev/null; then
        open "$TEMP_HTML" &>/dev/null &
    else
        log_warning "Could not detect browser opener. Please open: $DASHBOARD_URL"
        log_info "Token: $TOKEN"
    fi
    
    # Also try opening the dashboard URL directly after a delay
    sleep 2
    if command -v xdg-open &> /dev/null; then
        xdg-open "$DASHBOARD_URL" &>/dev/null &
    elif command -v open &> /dev/null; then
        open "$DASHBOARD_URL" &>/dev/null &
    fi
}

# Create browser bookmarklet script
create_bookmarklet() {
    local TOKEN=$1
    BOOKMARKLET_FILE="$PROJECT_ROOT/k8s/dashboard-bookmarklet.js"
    
    cat > "$BOOKMARKLET_FILE" <<EOF
// Kubernetes Dashboard Auto-Login Bookmarklet
// Add this as a bookmark and click it when on the dashboard login page

(function() {
    var token = '${TOKEN}';
    var tokenInput = document.querySelector('input[type="text"][placeholder*="token"], input[type="text"][name*="token"], input[type="password"]');
    if (tokenInput) {
        tokenInput.value = token;
        tokenInput.type = 'text';
        var event = new Event('input', { bubbles: true });
        tokenInput.dispatchEvent(event);
        
        setTimeout(function() {
            var loginButton = document.querySelector('button[type="submit"], button:contains("Sign"), button:contains("Login")');
            if (loginButton) {
                loginButton.click();
            }
        }, 500);
    } else {
        alert('Token input field not found. Please paste the token manually.');
        prompt('Copy this token:', token);
    }
})();
EOF
    
    log_info "Bookmarklet script created: $BOOKMARKLET_FILE"
    log_info "To use: Create a bookmark with this URL:"
    echo "javascript:$(cat "$BOOKMARKLET_FILE" | tr '\n' ' ' | sed 's/  */ /g')"
}

# Main execution
main() {
    echo ""
    echo "╔═══════════════════════════════════════════════╗"
    echo "║  Kubernetes Dashboard - Auto Login Setup     ║"
    echo "╚═══════════════════════════════════════════════╝"
    echo ""
    
    check_kubectl
    check_cluster
    
    # Deploy dashboard if not already deployed
    if ! kubectl get namespace "$DASHBOARD_NAMESPACE" &> /dev/null; then
        log_info "Deploying Kubernetes Dashboard..."
        kubectl apply -f https://raw.githubusercontent.com/kubernetes/dashboard/v2.7.0/aio/deploy/recommended.yaml
        
        # Wait for dashboard to be ready
        log_info "Waiting for dashboard to be ready..."
        kubectl wait --for=condition=available --timeout=300s deployment/kubernetes-dashboard -n "$DASHBOARD_NAMESPACE" || true
    fi
    
    # Get admin token
    TOKEN=$(get_admin_token)
    
    # Start kubectl proxy
    PROXY_PID=$(start_proxy)
    
    # Open dashboard
    open_dashboard "$TOKEN"
    
    # Create bookmarklet
    create_bookmarklet "$TOKEN"
    
    echo ""
    echo "╔═══════════════════════════════════════════════╗"
    echo "║  Dashboard Started Successfully!             ║"
    echo "╚═══════════════════════════════════════════════╝"
    echo ""
    log_success "Dashboard URL: http://localhost:${PROXY_PORT}/api/v1/namespaces/${DASHBOARD_NAMESPACE}/services/https:kubernetes-dashboard:/proxy/"
    log_success "Token saved to: $TOKEN_FILE"
    log_success "kubectl proxy PID: $PROXY_PID"
    echo ""
    log_info "Token has been copied to clipboard. Paste it when prompted."
    echo ""
    log_info "To stop the dashboard:"
    echo "  kill $PROXY_PID"
    echo "  or run: pkill -f 'kubectl proxy'"
    echo ""
    log_info "To restart with auto-login:"
    echo "  ./scripts/start-k8s-dashboard-auto.sh"
    echo ""
}

# Run main function
main

