#!/bin/bash
# Create Dashboard Bookmarklet with Token
# This script creates a bookmarklet that auto-fills the dashboard token

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TOKEN_FILE="$PROJECT_ROOT/k8s/dashboard-token.txt"
BOOKMARKLET_FILE="$PROJECT_ROOT/k8s/dashboard-bookmarklet.js"

# Functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Get token from file
get_token() {
    if [ ! -f "$TOKEN_FILE" ]; then
        log_error "Token file not found: $TOKEN_FILE"
        log_info "Please run: ./scripts/setup-k8s-dashboard.sh"
        exit 1
    fi
    
    TOKEN=$(grep -A 1 "^Token:" "$TOKEN_FILE" | tail -n 1 | xargs)
    
    if [ -z "$TOKEN" ]; then
        log_error "Could not extract token from $TOKEN_FILE"
        exit 1
    fi
    
    echo "$TOKEN"
}

# Create bookmarklet
create_bookmarklet() {
    local TOKEN=$1
    
    log_info "Creating bookmarklet..."
    
    # Escape token for JavaScript
    TOKEN_ESCAPED=$(echo "$TOKEN" | sed "s/'/\\\'/g")
    
    # Create bookmarklet JavaScript
    cat > "$BOOKMARKLET_FILE" <<EOF
// Kubernetes Dashboard Auto-Login Bookmarklet
// Created: $(date)
// 
// To use:
// 1. Copy the code below (starting with javascript:)
// 2. Create a bookmark in your browser
// 3. Paste the code as the bookmark URL
// 4. When on the dashboard login page, click the bookmark

(function() {
    const TOKEN = '${TOKEN_ESCAPED}';
    
    // Find token input field
    const tokenInput = document.querySelector('input[type="text"][placeholder*="token" i], input[type="text"][name*="token" i], input[type="password"], input[type="text"]');
    
    if (tokenInput) {
        // Set token value
        tokenInput.value = TOKEN;
        tokenInput.type = 'text';
        
        // Trigger events
        ['input', 'change', 'keyup'].forEach(eventType => {
            const event = new Event(eventType, { bubbles: true });
            tokenInput.dispatchEvent(event);
        });
        
        // Focus the input
        tokenInput.focus();
        
        // Try to find and click the login button
        setTimeout(() => {
            const selectors = [
                'button[type="submit"]',
                'button:contains("Sign")',
                'button:contains("Login")',
                'md-button[type="submit"]',
                '.mat-button[type="submit"]',
                'button.mat-primary'
            ];
            
            let loginButton = null;
            for (const selector of selectors) {
                loginButton = document.querySelector(selector);
                if (loginButton) break;
            }
            
            if (loginButton) {
                loginButton.click();
                console.log('Auto-login successful!');
            } else {
                // Try to find button by text content
                const buttons = document.querySelectorAll('button, md-button, .mat-button');
                for (const btn of buttons) {
                    if (btn.textContent && (btn.textContent.includes('Sign') || btn.textContent.includes('Login'))) {
                        btn.click();
                        console.log('Auto-login successful!');
                        return;
                    }
                }
                alert('Token filled! Please click the Sign In button manually.');
            }
        }, 500);
    } else {
        alert('Token input field not found. Token copied to clipboard.\n\nPlease paste it manually.');
        if (navigator.clipboard) {
            navigator.clipboard.writeText(TOKEN);
        } else {
            prompt('Copy this token:', TOKEN);
        }
    }
})();
EOF
    
    log_success "Bookmarklet created: $BOOKMARKLET_FILE"
    
    # Create one-line bookmarklet URL
    BOOKMARKLET_URL=$(cat "$BOOKMARKLET_FILE" | grep -v "//" | tr '\n' ' ' | sed "s/  */ /g" | sed "s/^javascript://" | sed "s/javascript: //")
    BOOKMARKLET_URL="javascript:$BOOKMARKLET_URL"
    
    # Save bookmarklet URL to file
    BOOKMARKLET_URL_FILE="$PROJECT_ROOT/k8s/dashboard-bookmarklet-url.txt"
    echo "$BOOKMARKLET_URL" > "$BOOKMARKLET_URL_FILE"
    
    log_success "Bookmarklet URL saved: $BOOKMARKLET_URL_FILE"
    
    echo ""
    log_info "=== Bookmarklet Instructions ==="
    echo ""
    echo "1. Copy the URL below (starting with javascript:):"
    echo ""
    echo "$BOOKMARKLET_URL" | head -c 200
    echo "..."
    echo ""
    echo "2. Create a bookmark in your browser:"
    echo "   - Name: K8s Dashboard Auto-Login"
    echo "   - URL: (paste the javascript: URL above)"
    echo ""
    echo "3. When on the dashboard login page, click the bookmark"
    echo ""
    echo "Full URL saved to: $BOOKMARKLET_URL_FILE"
    echo ""
}

# Main execution
main() {
    echo ""
    echo "╔═══════════════════════════════════════════════╗"
    echo "║  Kubernetes Dashboard - Bookmarklet Creator  ║"
    echo "╚═══════════════════════════════════════════════╝"
    echo ""
    
    TOKEN=$(get_token)
    create_bookmarklet "$TOKEN"
    
    echo ""
    log_success "✓ Bookmarklet created successfully!"
    echo ""
}

# Run main function
main

