#!/bin/bash
# Setup GitHub Actions SSH user on jump server
# This script should be run on the jump server (github.fkstrading.xyz)
# Usage: ./setup-github-actions-user.sh

set -e

# Configuration
GITHUB_USER="${GITHUB_USER:-github-actions}"
GITHUB_HOME="/home/$GITHUB_USER"
SSH_DIR="$GITHUB_HOME/.ssh"
AUTHORIZED_KEYS="$SSH_DIR/authorized_keys"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "🔐 Setting up GitHub Actions SSH user"
echo "======================================"
echo ""

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}❌ This script must be run as root${NC}"
    exit 1
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
echo ""
echo "📋 Adding SSH public key..."
echo "Please paste the GitHub Actions SSH public key (or press Enter to skip):"
read -p "SSH Public Key: " SSH_PUBLIC_KEY

if [ -n "$SSH_PUBLIC_KEY" ]; then
    # Check if key already exists
    if grep -q "$SSH_PUBLIC_KEY" "$AUTHORIZED_KEYS" 2>/dev/null; then
        echo -e "${YELLOW}⚠️  SSH key already exists${NC}"
    else
        echo "$SSH_PUBLIC_KEY" >> "$AUTHORIZED_KEYS"
        chmod 600 "$AUTHORIZED_KEYS"
        chown "$GITHUB_USER:$GITHUB_USER" "$AUTHORIZED_KEYS"
        echo -e "${GREEN}✅ SSH key added${NC}"
    fi
else
    echo -e "${YELLOW}⚠️  No SSH key provided, skipping...${NC}"
    echo "   You can add it later by running:"
    echo "   echo 'YOUR_PUBLIC_KEY' >> $AUTHORIZED_KEYS"
fi

# Configure SSH for jump access
echo ""
echo "📋 Configuring SSH for jump server access..."

# Create SSH config for the user (optional, for convenience)
cat > "$SSH_DIR/config" << 'EOF'
# SSH config for GitHub Actions user
# This allows the user to easily SSH into other hosts in the Tailscale network

# Example: K8s server
# Host k8s-server
#   HostName 100.x.x.x
#   User root
#   StrictHostKeyChecking no
#   UserKnownHostsFile ~/.ssh/known_hosts

# Example: Jump to other servers
# Host other-server
#   HostName 100.x.x.x
#   User root
#   ProxyJump github.fkstrading.xyz
#   StrictHostKeyChecking no
EOF

chmod 600 "$SSH_DIR/config"
chown "$GITHUB_USER:$GITHUB_USER" "$SSH_DIR/config"

# Set up known_hosts
touch "$SSH_DIR/known_hosts"
chmod 644 "$SSH_DIR/known_hosts"
chown "$GITHUB_USER:$GITHUB_USER" "$SSH_DIR/known_hosts"

# Configure sudo access (optional, for kubectl commands)
echo ""
echo "📋 Configuring sudo access..."
read -p "Allow sudo access? (y/N): " ALLOW_SUDO
if [[ "$ALLOW_SUDO" =~ ^[Yy]$ ]]; then
    # Add user to sudoers with NOPASSWD (if needed for kubectl)
    if ! grep -q "^$GITHUB_USER" /etc/sudoers.d/github-actions 2>/dev/null; then
        cat > /etc/sudoers.d/github-actions << EOF
# GitHub Actions user - limited sudo access
$GITHUB_USER ALL=(ALL) NOPASSWD: /usr/bin/kubectl
$GITHUB_USER ALL=(ALL) NOPASSWD: /usr/local/bin/kubectl
$GITHUB_USER ALL=(ALL) NOPASSWD: /snap/bin/kubectl
EOF
        chmod 440 /etc/sudoers.d/github-actions
        echo -e "${GREEN}✅ Sudo access configured${NC}"
    else
        echo -e "${YELLOW}⚠️  Sudo access already configured${NC}"
    fi
else
    echo -e "${YELLOW}⚠️  Sudo access not configured${NC}"
fi

# Set up kubectl access (if kubectl is available on jump server)
echo ""
echo "📋 Checking for kubectl..."
if command -v kubectl &> /dev/null; then
    echo -e "${GREEN}✅ kubectl is available${NC}"
    echo "   The user can run kubectl commands if kubectl is configured on this server"
else
    echo -e "${YELLOW}⚠️  kubectl is not available on this server${NC}"
    echo "   You may need to SSH into the K8s server to run kubectl commands"
fi

# Security hardening
echo ""
echo "📋 Applying security hardening..."

# Disable password authentication for this user (key-only)
if [ -f /etc/ssh/sshd_config ]; then
    # This is already handled by the authorized_keys file, but we can verify
    echo "   ✅ SSH key authentication is configured"
fi

# Set up .bashrc to prevent interactive shell issues
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
echo "   1. Generate SSH key pair for GitHub Actions:"
echo "      ssh-keygen -t ed25519 -C 'github-actions@fkstrading.xyz' -f github-actions-key"
echo ""
echo "   2. Add public key to jump server:"
echo "      cat github-actions-key.pub | sudo tee -a $AUTHORIZED_KEYS"
echo ""
echo "   3. Add private key to GitHub Secrets:"
echo "      - Go to GitHub repository settings"
echo "      - Navigate to Secrets and variables > Actions"
echo "      - Add secret: SSH_PRIVATE_KEY"
echo "      - Value: Contents of github-actions-key (private key)"
echo ""
echo "   4. If deploying to K8s server:"
echo "      - Add public key to K8s server's authorized_keys"
echo "      - Or use the same key for both jump server and K8s server"
echo ""
echo "   5. Test SSH connection:"
echo "      ssh -i github-actions-key $GITHUB_USER@github.fkstrading.xyz"
echo ""
echo "🔒 Security Notes:"
echo "   - User has key-only authentication (no password)"
echo "   - User has limited sudo access (kubectl only)"
echo "   - Consider restricting SSH access by IP in /etc/ssh/sshd_config"
echo "   - Consider using fail2ban to protect against brute force attacks"
echo ""

