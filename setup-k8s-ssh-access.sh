#!/bin/bash
# Setup SSH access from jump server to K8s server
# This script should be run on the K8s server (via Tailscale)
# Usage: ./setup-k8s-ssh-access.sh <github-actions-public-key>

set -e

# Configuration
GITHUB_USER="${GITHUB_USER:-github-actions}"
GITHUB_HOME="/home/$GITHUB_USER"
SSH_DIR="$GITHUB_HOME/.ssh"
AUTHORIZED_KEYS="$SSH_DIR/authorized_keys"
PUBLIC_KEY="${1:-}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "🔐 Setting up SSH access from jump server to K8s server"
echo "========================================================"
echo ""

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}❌ This script must be run as root${NC}"
    exit 1
fi

# Check if public key is provided
if [ -z "$PUBLIC_KEY" ]; then
    echo -e "${YELLOW}⚠️  No public key provided${NC}"
    echo "Usage: $0 <public-key>"
    echo "   Or: $0 < /path/to/public-key.pub"
    echo ""
    read -p "Paste the GitHub Actions SSH public key: " PUBLIC_KEY
    if [ -z "$PUBLIC_KEY" ]; then
        echo -e "${RED}❌ Public key is required${NC}"
        exit 1
    fi
fi

# Create user if it doesn't exist
if id "$GITHUB_USER" &>/dev/null; then
    echo -e "${YELLOW}⚠️  User $GITHUB_USER already exists${NC}"
else
    echo "📋 Creating user: $GITHUB_USER"
    useradd -m -s /bin/bash "$GITHUB_USER"
    echo -e "${GREEN}✅ User created${NC}"
fi

# Create .ssh directory
echo "📋 Setting up SSH directory..."
mkdir -p "$SSH_DIR"
chmod 700 "$SSH_DIR"
chown "$GITHUB_USER:$GITHUB_USER" "$SSH_DIR"
echo -e "${GREEN}✅ SSH directory created${NC}"

# Create authorized_keys file if it doesn't exist
if [ ! -f "$AUTHORIZED_KEYS" ]; then
    touch "$AUTHORIZED_KEYS"
    chmod 600 "$AUTHORIZED_KEYS"
    chown "$GITHUB_USER:$GITHUB_USER" "$AUTHORIZED_KEYS"
    echo -e "${GREEN}✅ authorized_keys file created${NC}"
fi

# Add SSH key
echo "📋 Adding SSH public key..."
if grep -q "$PUBLIC_KEY" "$AUTHORIZED_KEYS" 2>/dev/null; then
    echo -e "${YELLOW}⚠️  SSH key already exists${NC}"
else
    echo "$PUBLIC_KEY" >> "$AUTHORIZED_KEYS"
    chmod 600 "$AUTHORIZED_KEYS"
    chown "$GITHUB_USER:$GITHUB_USER" "$AUTHORIZED_KEYS"
    echo -e "${GREEN}✅ SSH key added${NC}"
fi

# Configure kubectl access
echo ""
echo "📋 Configuring kubectl access..."
if command -v kubectl &> /dev/null; then
    echo -e "${GREEN}✅ kubectl is available${NC}"
    
    # Check if kubeconfig exists
    if [ -f /root/.kube/config ]; then
        echo "📋 Setting up kubeconfig for $GITHUB_USER..."
        mkdir -p "$GITHUB_HOME/.kube"
        cp /root/.kube/config "$GITHUB_HOME/.kube/config"
        chown -R "$GITHUB_USER:$GITHUB_USER" "$GITHUB_HOME/.kube"
        chmod 600 "$GITHUB_HOME/.kube/config"
        echo -e "${GREEN}✅ kubeconfig configured${NC}"
    else
        echo -e "${YELLOW}⚠️  kubeconfig not found in /root/.kube/config${NC}"
        echo "   You may need to configure kubectl manually"
    fi
else
    echo -e "${YELLOW}⚠️  kubectl is not installed${NC}"
    echo "   Install kubectl to enable Kubernetes access"
fi

# Configure sudo access for kubectl
echo ""
echo "📋 Configuring sudo access..."
if ! grep -q "^$GITHUB_USER" /etc/sudoers.d/github-actions 2>/dev/null; then
    cat > /etc/sudoers.d/github-actions << EOF
# GitHub Actions user - kubectl access only
$GITHUB_USER ALL=(ALL) NOPASSWD: /usr/bin/kubectl
$GITHUB_USER ALL=(ALL) NOPASSWD: /usr/local/bin/kubectl
$GITHUB_USER ALL=(ALL) NOPASSWD: /snap/bin/kubectl
EOF
    chmod 440 /etc/sudoers.d/github-actions
    echo -e "${GREEN}✅ Sudo access configured${NC}"
else
    echo -e "${YELLOW}⚠️  Sudo access already configured${NC}"
fi

# Set up known_hosts for jump server
echo ""
echo "📋 Setting up known_hosts..."
touch "$SSH_DIR/known_hosts"
chmod 644 "$SSH_DIR/known_hosts"
chown "$GITHUB_USER:$GITHUB_USER" "$SSH_DIR/known_hosts"

# Add jump server to known_hosts
JUMP_SERVER="github.fkstrading.xyz"
if ! grep -q "$JUMP_SERVER" "$SSH_DIR/known_hosts" 2>/dev/null; then
    ssh-keyscan -H "$JUMP_SERVER" >> "$SSH_DIR/known_hosts" 2>/dev/null || true
    echo -e "${GREEN}✅ Jump server added to known_hosts${NC}"
fi

# Security hardening
echo ""
echo "📋 Applying security hardening..."

# Set up .bashrc
cat > "$GITHUB_HOME/.bashrc" << 'EOF'
# GitHub Actions user bashrc
# Non-interactive shell configuration

# If not running interactively, don't do anything
[ -z "$PS1" ] && return

# Basic aliases
alias ll='ls -alF'
alias la='ls -A'
alias l='ls -CF'

# Set PATH
export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"

# Kubectl aliases (if available)
if command -v kubectl &> /dev/null; then
    alias k='kubectl'
    alias kgp='kubectl get pods'
    alias kgd='kubectl get deployments'
    alias kgs='kubectl get services'
fi

# Prevent history from being saved in CI environments
if [ -n "$CI" ] || [ -n "$GITHUB_ACTIONS" ]; then
    unset HISTFILE
fi
EOF

chown "$GITHUB_USER:$GITHUB_USER" "$GITHUB_HOME/.bashrc"
echo -e "${GREEN}✅ Security hardening applied${NC}"

# Summary
echo ""
echo "═══════════════════════════════════════════════════════"
echo "✅ Setup Complete!"
echo "═══════════════════════════════════════════════════════"
echo ""
echo "📋 User Information:"
echo "   Username: $GITHUB_USER"
echo "   Home: $GITHUB_HOME"
echo "   SSH Directory: $SSH_DIR"
echo "   Authorized Keys: $AUTHORIZED_KEYS"
echo ""
echo "📋 Next Steps:"
echo "   1. Test SSH connection from jump server:"
echo "      ssh $GITHUB_USER@$(hostname -I | awk '{print $1}')"
echo "      # Or via Tailscale IP"
echo ""
echo "   2. Test kubectl access:"
echo "      ssh $GITHUB_USER@<k8s-ip> 'kubectl get nodes'"
echo ""
echo "   3. Verify kubectl works:"
echo "      ssh $GITHUB_USER@<k8s-ip> 'kubectl get deployments -n fks-trading'"
echo ""
echo "🔒 Security Notes:"
echo "   - User has key-only authentication (no password)"
echo "   - User has limited sudo access (kubectl only)"
echo "   - Consider restricting SSH access by IP in /etc/ssh/sshd_config"
echo "   - Consider using fail2ban to protect against brute force attacks"
echo ""

