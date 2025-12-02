#!/bin/bash
# Generate SSH key pair for GitHub Actions
# This script generates a new SSH key pair for use with GitHub Actions
# Usage: ./generate-github-actions-keys.sh

set -e

# Configuration
KEY_NAME="${KEY_NAME:-github-actions-key}"
KEY_TYPE="${KEY_TYPE:-ed25519}"
KEY_COMMENT="${KEY_COMMENT:-github-actions@fkstrading.xyz}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "🔑 Generating SSH key pair for GitHub Actions"
echo "=============================================="
echo ""

# Check if key already exists
if [ -f "$KEY_NAME" ]; then
    echo -e "${YELLOW}⚠️  Key file $KEY_NAME already exists${NC}"
    read -p "Overwrite? (y/N): " OVERWRITE
    if [[ ! "$OVERWRITE" =~ ^[Yy]$ ]]; then
        echo "❌ Aborted"
        exit 1
    fi
    rm -f "$KEY_NAME" "$KEY_NAME.pub"
fi

# Generate SSH key
echo "📋 Generating SSH key pair..."
echo "   Key name: $KEY_NAME"
echo "   Key type: $KEY_TYPE"
echo "   Comment: $KEY_COMMENT"
echo ""

ssh-keygen -t "$KEY_TYPE" -C "$KEY_COMMENT" -f "$KEY_NAME" -N ""

echo ""
echo -e "${GREEN}✅ SSH key pair generated${NC}"
echo ""

# Display public key
echo "═══════════════════════════════════════════════════════"
echo "📋 Public Key (add to servers):"
echo "═══════════════════════════════════════════════════════"
cat "$KEY_NAME.pub"
echo ""

# Display private key location
echo "═══════════════════════════════════════════════════════"
echo "📋 Private Key (add to GitHub Secrets):"
echo "═══════════════════════════════════════════════════════"
echo "File: $KEY_NAME"
echo ""

# Instructions
echo "═══════════════════════════════════════════════════════"
echo "📋 Setup Instructions:"
echo "═══════════════════════════════════════════════════════"
echo ""
echo "1. Add public key to jump server (github.fkstrading.xyz):"
echo "   cat $KEY_NAME.pub | ssh root@github.fkstrading.xyz 'tee -a /home/github-actions/.ssh/authorized_keys'"
echo "   # Or run: ./setup-github-actions-user.sh"
echo ""
echo "2. Add public key to K8s server (via Tailscale):"
echo "   cat $KEY_NAME.pub | ssh root@<k8s-tailscale-ip> 'tee -a /home/github-actions/.ssh/authorized_keys'"
echo "   # Or run: ./setup-k8s-ssh-access.sh < $KEY_NAME.pub"
echo ""
echo "3. Add private key to GitHub Secrets:"
echo "   - Go to GitHub repository settings"
echo "   - Navigate to Secrets and variables > Actions"
echo "   - Add secret: SSH_PRIVATE_KEY"
echo "   - Value: Contents of $KEY_NAME"
echo "   cat $KEY_NAME"
echo ""
echo "4. (Optional) If using different keys for jump server and K8s:"
echo "   - Add K8s server key to GitHub Secrets: K8S_SSH_KEY"
echo ""
echo "5. Test SSH connection:"
echo "   ssh -i $KEY_NAME github-actions@github.fkstrading.xyz"
echo ""
echo "🔒 Security Notes:"
echo "   - Keep the private key ($KEY_NAME) secure"
echo "   - Do not commit the private key to git"
echo "   - The private key should only be stored in GitHub Secrets"
echo "   - Consider using a passphrase for additional security"
echo "   - Rotate keys periodically"
echo ""

