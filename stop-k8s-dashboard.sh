#!/bin/bash
# Stop Kubernetes Dashboard and kubectl proxy

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

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

# Stop kubectl proxy
stop_proxy() {
    log_info "Stopping kubectl proxy..."
    
    # Find and kill kubectl proxy processes
    PROXY_PIDS=$(pgrep -f "kubectl proxy" || true)
    
    if [ -n "$PROXY_PIDS" ]; then
        for PID in $PROXY_PIDS; do
            log_info "Stopping kubectl proxy (PID: $PID)..."
            kill $PID 2>/dev/null || true
        done
        sleep 2
        log_success "kubectl proxy stopped"
    else
        log_warning "No kubectl proxy processes found"
    fi
}

# Main execution
main() {
    echo ""
    echo "╔═══════════════════════════════════════════════╗"
    echo "║  Kubernetes Dashboard - Stop                 ║"
    echo "╚═══════════════════════════════════════════════╝"
    echo ""
    
    stop_proxy
    
    echo ""
    log_success "Dashboard stopped successfully!"
    echo ""
}

# Run main function
main

