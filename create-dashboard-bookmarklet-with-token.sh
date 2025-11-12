#!/bin/bash
# Create Dashboard Bookmarklet with Token from File
# This script reads the token from dashboard-token.txt and creates a bookmarklet

set -e

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TOKEN_FILE="$PROJECT_ROOT/k8s/dashboard-token.txt"
BOOKMARKLET_FILE="$PROJECT_ROOT/k8s/dashboard-bookmarklet-url.txt"
BOOKMARKLET_HTML="$PROJECT_ROOT/k8s/dashboard-bookmarklet.html"

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${CYAN}╔═══════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║  Dashboard Bookmarklet Generator             ║${NC}"
echo -e "${CYAN}╚═══════════════════════════════════════════════╝${NC}"
echo ""

# Get token
if [ ! -f "$TOKEN_FILE" ]; then
    echo -e "${YELLOW}⚠️  Token file not found: $TOKEN_FILE${NC}"
    echo "Please run: ./scripts/setup-k8s-dashboard.sh"
    exit 1
fi

TOKEN=$(grep -A 1 "^Token:" "$TOKEN_FILE" | tail -n 1 | xargs)

if [ -z "$TOKEN" ]; then
    echo -e "${YELLOW}❌ Could not extract token from $TOKEN_FILE${NC}"
    exit 1
fi

echo -e "${BLUE}📋 Token loaded from: $TOKEN_FILE${NC}"

# Escape token for JavaScript (minify and escape)
TOKEN_ESCAPED=$(echo "$TOKEN" | sed "s/'/\\\'/g" | sed "s/\"/\\\"/g" | tr -d '\n' | sed 's/  */ /g')

# Create bookmarklet code
BOOKMARKLET_CODE="(function(){const TOKEN='${TOKEN_ESCAPED}';const tokenInput=document.querySelector('input[type=\"text\"][placeholder*=\"token\" i],input[type=\"text\"][name*=\"token\" i],input[type=\"password\"],input[type=\"text\"]');if(tokenInput){tokenInput.value=TOKEN;tokenInput.type='text';['input','change','keyup'].forEach(eventType=>{const event=new Event(eventType,{bubbles:true});tokenInput.dispatchEvent(event);});tokenInput.focus();setTimeout(()=>{const selectors=['button[type=\"submit\"]','button:contains(\"Sign\")','button:contains(\"Login\")','md-button[type=\"submit\"]','.mat-button[type=\"submit\"]','button.mat-primary'];let loginButton=null;for(const selector of selectors){loginButton=document.querySelector(selector);if(loginButton)break;}if(loginButton){loginButton.click();console.log('Auto-login successful!');}else{const buttons=document.querySelectorAll('button,md-button,.mat-button');for(const btn of buttons){if(btn.textContent&&(btn.textContent.includes('Sign')||btn.textContent.includes('Login'))){btn.click();console.log('Auto-login successful!');return;}}alert('Token filled! Please click the Sign In button manually.');}},500);}else{alert('Token input field not found. Token copied to clipboard.');if(navigator.clipboard){navigator.clipboard.writeText(TOKEN);}else{prompt('Copy this token:',TOKEN);}}})();"

# Create bookmarklet URL
BOOKMARKLET_URL="javascript:$BOOKMARKLET_CODE"

# Save bookmarklet URL to file
mkdir -p "$(dirname "$BOOKMARKLET_FILE")"
echo "$BOOKMARKLET_URL" > "$BOOKMARKLET_FILE"

# Create HTML page with bookmarklet
cat > "$BOOKMARKLET_HTML" <<EOF
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Kubernetes Dashboard - Auto Login Bookmarklet</title>
    <style>
        body {
            font-family: Arial, sans-serif;
            max-width: 800px;
            margin: 50px auto;
            padding: 20px;
            background: #f5f5f5;
        }
        .container {
            background: white;
            padding: 30px;
            border-radius: 8px;
            box-shadow: 0 2px 4px rgba(0,0,0,0.1);
        }
        h1 {
            color: #333;
        }
        .bookmarklet-link {
            display: inline-block;
            background: #1976d2;
            color: white;
            padding: 15px 30px;
            text-decoration: none;
            border-radius: 4px;
            font-size: 18px;
            margin: 20px 0;
        }
        .bookmarklet-link:hover {
            background: #1565c0;
        }
        .info {
            background: #e3f2fd;
            padding: 15px;
            border-radius: 4px;
            margin: 20px 0;
        }
        code {
            background: #f5f5f5;
            padding: 2px 6px;
            border-radius: 3px;
            font-family: monospace;
        }
    </style>
</head>
<body>
    <div class="container">
        <h1>🚀 Kubernetes Dashboard - Auto Login Bookmarklet</h1>
        
        <div class="info">
            <p><strong>Instructions:</strong></p>
            <ol>
                <li>Drag the button below to your browser's bookmarks bar</li>
                <li>Or right-click the button and select "Bookmark Link"</li>
                <li>When on the dashboard login page, click the bookmark</li>
                <li>The token will be automatically filled in and you'll be logged in</li>
            </ol>
        </div>
        
        <div>
            <a href="${BOOKMARKLET_URL}" class="bookmarklet-link" onclick="return false;">
                🔐 K8s Dashboard Auto-Login
            </a>
        </div>
        
        <div class="info">
            <p><strong>Alternative Method:</strong></p>
            <ol>
                <li>Create a new bookmark in your browser (Ctrl+D / Cmd+D)</li>
                <li>Name it: <code>K8s Dashboard Auto-Login</code></li>
                <li>Set the URL to the bookmarklet code below</li>
            </ol>
        </div>
        
        <div>
            <p><strong>Bookmarklet URL:</strong></p>
            <textarea readonly style="width: 100%; min-height: 100px; font-family: monospace; font-size: 10px;">${BOOKMARKLET_URL}</textarea>
        </div>
        
        <div class="info">
            <p><strong>Note:</strong></p>
            <ul>
                <li>This bookmarklet works only on the Kubernetes Dashboard login page</li>
                <li>The token is embedded in the bookmarklet</li>
                <li>If the token expires, regenerate the bookmarklet</li>
                <li>This is safe for local use only</li>
            </ul>
        </div>
    </div>
</body>
</html>
EOF

echo ""
echo -e "${GREEN}╔═══════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║  Bookmarklet Created Successfully!           ║${NC}"
echo -e "${GREEN}╚═══════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${CYAN}Bookmarklet URL saved to:${NC}"
echo "  $BOOKMARKLET_FILE"
echo ""
echo -e "${CYAN}HTML page created:${NC}"
echo "  $BOOKMARKLET_HTML"
echo ""
echo -e "${BLUE}📋 How to Use:${NC}"
echo ""
echo "Method 1: Drag and Drop"
echo "  1. Open: file://$BOOKMARKLET_HTML"
echo "  2. Drag the '🔐 K8s Dashboard Auto-Login' button to your bookmarks bar"
echo "  3. Click the bookmark when on the dashboard login page"
echo ""
echo "Method 2: Manual Bookmark"
echo "  1. Create a new bookmark in your browser"
echo "  2. Name it: K8s Dashboard Auto-Login"
echo "  3. Set URL to: (content of $BOOKMARKLET_FILE)"
echo ""
echo -e "${YELLOW}To regenerate bookmarklet:${NC}"
echo "  ./scripts/create-dashboard-bookmarklet-with-token.sh"
echo ""

