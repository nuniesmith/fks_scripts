#!/bin/bash
# Setup Kubernetes Dashboard with admin access
# This script installs the Kubernetes Dashboard and configures access

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Configuration
DASHBOARD_NAMESPACE="kubernetes-dashboard"
DASHBOARD_VERSION="v2.7.0"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
# Token file should be in infrastructure/main/k8s/ (not services/main/k8s/)
TOKEN_FILE="$REPO_DIR/infrastructure/main/k8s/dashboard-token.txt"

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

# Check prerequisites
check_prerequisites() {
    log_info "Checking prerequisites..."
    
    if ! command -v kubectl &> /dev/null; then
        log_error "kubectl is not installed"
        exit 1
    fi
    
    if ! kubectl cluster-info &> /dev/null; then
        log_error "Cannot connect to Kubernetes cluster"
        exit 1
    fi
    
    log_success "Prerequisites check passed ✓"
}

# Install dashboard
install_dashboard() {
    log_info "Installing Kubernetes Dashboard ${DASHBOARD_VERSION}..."
    
    # Check if dashboard is already installed
    if kubectl get namespace "$DASHBOARD_NAMESPACE" &> /dev/null; then
        log_warning "Dashboard namespace already exists. Checking if dashboard is installed..."
        if kubectl get deployment kubernetes-dashboard -n "$DASHBOARD_NAMESPACE" &> /dev/null; then
            log_success "Dashboard is already installed ✓"
            return 0
        fi
    fi
    
    # Deploy dashboard
    log_info "Deploying Kubernetes Dashboard..."
    kubectl apply -f https://raw.githubusercontent.com/kubernetes/dashboard/${DASHBOARD_VERSION}/aio/deploy/recommended.yaml
    
    # Wait for dashboard to be ready
    log_info "Waiting for dashboard pods to be ready..."
    kubectl wait --for=condition=ready pod \
        -l k8s-app=kubernetes-dashboard \
        -n "$DASHBOARD_NAMESPACE" \
        --timeout=300s || log_warning "Dashboard pods may not be ready yet"
    
    log_success "Dashboard installed ✓"
}

# Create admin user
create_admin_user() {
    log_info "Creating admin user and service account..."
    
    # Check if admin user already exists
    if kubectl get serviceaccount admin-user -n "$DASHBOARD_NAMESPACE" &> /dev/null; then
        log_warning "Admin user already exists. Skipping creation..."
    else
        # Create service account
        kubectl create serviceaccount admin-user -n "$DASHBOARD_NAMESPACE" || true
        
        # Create cluster role binding
        kubectl create clusterrolebinding admin-user \
            --clusterrole=cluster-admin \
            --serviceaccount="$DASHBOARD_NAMESPACE:admin-user" || true
        
        log_success "Admin user created ✓"
    fi
    
    # Create or update secret for token
    log_info "Creating/updating admin user secret..."
    cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Secret
metadata:
  name: admin-user-secret
  namespace: ${DASHBOARD_NAMESPACE}
  annotations:
    kubernetes.io/service-account.name: admin-user
type: kubernetes.io/service-account-token
EOF
    
    # Wait for secret to be populated
    log_info "Waiting for secret to be populated..."
    sleep 5
    
    # Retry getting token if it's not ready
    for i in {1..10}; do
        TOKEN=$(kubectl get secret admin-user-secret -n "$DASHBOARD_NAMESPACE" -o jsonpath='{.data.token}' 2>/dev/null | base64 -d 2>/dev/null || echo "")
        if [ -n "$TOKEN" ] && [ "$TOKEN" != "null" ]; then
            break
        fi
        log_info "Waiting for token... (attempt $i/10)"
        sleep 2
    done
    
    if [ -z "$TOKEN" ] || [ "$TOKEN" == "null" ]; then
        log_warning "Token not ready yet. You may need to wait a few minutes and run:"
        echo "  kubectl get secret admin-user-secret -n $DASHBOARD_NAMESPACE -o jsonpath='{.data.token}' | base64 -d"
        return 1
    fi
    
    # Save token to file
    mkdir -p "$(dirname "$TOKEN_FILE")"
    echo "Kubernetes Dashboard Admin Token" > "$TOKEN_FILE"
    echo "=================================" >> "$TOKEN_FILE"
    echo "" >> "$TOKEN_FILE"
    echo "Token:" >> "$TOKEN_FILE"
    echo "$TOKEN" >> "$TOKEN_FILE"
    echo "" >> "$TOKEN_FILE"
    echo "Access URL:" >> "$TOKEN_FILE"
    echo "http://localhost:8001/api/v1/namespaces/${DASHBOARD_NAMESPACE}/services/https:kubernetes-dashboard:/proxy/" >> "$TOKEN_FILE"
    echo "" >> "$TOKEN_FILE"
    echo "To start the dashboard:" >> "$TOKEN_FILE"
    echo "1. Run: kubectl proxy" >> "$TOKEN_FILE"
    echo "2. Open the URL above in your browser" >> "$TOKEN_FILE"
    echo "3. Choose \"Token\" authentication" >> "$TOKEN_FILE"
    echo "4. Paste the token above" >> "$TOKEN_FILE"
    echo "" >> "$TOKEN_FILE"
    echo "To start proxy in background:" >> "$TOKEN_FILE"
    echo "kubectl proxy &" >> "$TOKEN_FILE"
    echo "" >> "$TOKEN_FILE"
    echo "To stop proxy:" >> "$TOKEN_FILE"
    echo "pkill -f \"kubectl proxy\"" >> "$TOKEN_FILE"
    
    log_success "Token saved to $TOKEN_FILE ✓"
    echo ""
    log_info "Dashboard Token:"
    echo "$TOKEN"
    echo ""
}

# Setup ingress for dashboard (optional)
setup_dashboard_ingress() {
    log_info "Setting up dashboard ingress (optional)..."
    
    read -p "Do you want to expose dashboard via ingress? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_info "Skipping ingress setup. Dashboard will be accessible via kubectl proxy only."
        return 0
    fi
    
    # Get domain from user
    read -p "Enter your domain (e.g., dashboard.fkstrading.xyz): " DOMAIN
    
    if [ -z "$DOMAIN" ]; then
        log_warning "No domain provided. Skipping ingress setup."
        return 0
    fi
    
    # Create ingress for dashboard
    cat <<EOF | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: kubernetes-dashboard-ingress
  namespace: ${DASHBOARD_NAMESPACE}
  annotations:
    nginx.ingress.kubernetes.io/ssl-redirect: "false"
    nginx.ingress.kubernetes.io/backend-protocol: "HTTPS"
    nginx.ingress.kubernetes.io/rewrite-target: /
spec:
  ingressClassName: nginx
  rules:
  - host: ${DOMAIN}
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: kubernetes-dashboard
            port:
              number: 443
EOF
    
    log_success "Dashboard ingress created for ${DOMAIN} ✓"
    log_info "Access dashboard at: http://${DOMAIN}"
}

# Show access information
show_access_info() {
    echo ""
    echo "╔═══════════════════════════════════════════════╗"
    echo "║  Kubernetes Dashboard Setup Complete         ║"
    echo "╚═══════════════════════════════════════════════╝"
    echo ""
    
    log_info "=== Access Information ==="
    echo ""
    echo "Method 1: kubectl proxy (Recommended for local access)"
    echo "  1. Run: kubectl proxy"
    echo "  2. Open: http://localhost:8001/api/v1/namespaces/${DASHBOARD_NAMESPACE}/services/https:kubernetes-dashboard:/proxy/"
    echo "  3. Choose \"Token\" authentication"
    echo "  4. Paste token from: $TOKEN_FILE"
    echo ""
    echo "Method 2: Port-forwarding"
    echo "  1. Run: kubectl port-forward -n ${DASHBOARD_NAMESPACE} svc/kubernetes-dashboard 8443:443"
    echo "  2. Open: https://localhost:8443"
    echo "  3. Accept self-signed certificate warning"
    echo "  4. Choose \"Token\" authentication"
    echo "  5. Paste token from: $TOKEN_FILE"
    echo ""
    echo "Method 3: NodePort (if using minikube)"
    if command -v minikube &> /dev/null; then
        if minikube status &> /dev/null; then
            kubectl patch svc kubernetes-dashboard -n "$DASHBOARD_NAMESPACE" -p '{"spec":{"type":"NodePort"}}' &> /dev/null || true
            NODEPORT=$(kubectl get svc kubernetes-dashboard -n "$DASHBOARD_NAMESPACE" -o jsonpath='{.spec.ports[0].nodePort}' 2>/dev/null || echo "N/A")
            MINIKUBE_IP=$(minikube ip 2>/dev/null || echo "N/A")
            if [ "$NODEPORT" != "N/A" ] && [ "$MINIKUBE_IP" != "N/A" ]; then
                echo "  1. Dashboard is exposed on NodePort: $NODEPORT"
                echo "  2. Access: http://${MINIKUBE_IP}:${NODEPORT}"
                echo "  3. Choose \"Token\" authentication"
                echo "  4. Paste token from: $TOKEN_FILE"
            fi
        fi
    fi
    echo ""
    echo "Token Location:"
    echo "  $TOKEN_FILE"
    echo ""
    echo "Quick Start:"
    echo "  kubectl proxy &"
    echo "  # Then open: http://localhost:8001/api/v1/namespaces/${DASHBOARD_NAMESPACE}/services/https:kubernetes-dashboard:/proxy/"
    echo ""
}

# Main execution
main() {
    echo ""
    echo "╔═══════════════════════════════════════════════╗"
    echo "║  Kubernetes Dashboard Setup                  ║"
    echo "╚═══════════════════════════════════════════════╝"
    echo ""
    
    check_prerequisites
    install_dashboard
    create_admin_user
    show_access_info
    
    echo ""
    log_success "✓ Kubernetes Dashboard setup complete!"
    echo ""
}

# Run main function
main

