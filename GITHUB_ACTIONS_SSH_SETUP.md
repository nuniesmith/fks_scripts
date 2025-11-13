# GitHub Actions SSH Setup Guide

This guide explains how to set up SSH access for GitHub Actions to deploy to Kubernetes via a jump server.

## Overview

GitHub Actions needs SSH access to:
1. **Jump Server** (`github.fkstrading.xyz`) - Public IP, accessible from internet
2. **K8s Server** (via Tailscale) - Private IP, accessible from jump server

## Architecture

```
GitHub Actions Runner
    ↓ (SSH)
Jump Server (github.fkstrading.xyz)
    ↓ (SSH via Tailscale)
K8s Server (Tailscale IP)
    ↓ (kubectl)
Kubernetes Cluster
```

## Setup Steps

### 1. Generate SSH Key Pair

On your local machine or a secure server:

```bash
cd repo/scripts
./generate-github-actions-keys.sh
```

This will create:
- `github-actions-key` (private key) - Add to GitHub Secrets
- `github-actions-key.pub` (public key) - Add to servers

### 2. Setup Jump Server

On the jump server (`github.fkstrading.xyz`):

```bash
# Copy the setup script to the jump server
scp setup-github-actions-user.sh root@github.fkstrading.xyz:/tmp/

# SSH into the jump server
ssh root@github.fkstrading.xyz

# Run the setup script
bash /tmp/setup-github-actions-user.sh
```

Or manually:

```bash
# Create user
useradd -m -s /bin/bash github-actions

# Create .ssh directory
mkdir -p /home/github-actions/.ssh
chmod 700 /home/github-actions/.ssh
chown github-actions:github-actions /home/github-actions/.ssh

# Add public key
echo "YOUR_PUBLIC_KEY" >> /home/github-actions/.ssh/authorized_keys
chmod 600 /home/github-actions/.ssh/authorized_keys
chown github-actions:github-actions /home/github-actions/.ssh/authorized_keys
```

### 3. Setup K8s Server

On the K8s server (via Tailscale):

```bash
# From jump server, copy the setup script to K8s server
scp setup-k8s-ssh-access.sh root@<k8s-tailscale-ip>:/tmp/

# SSH into K8s server (via jump server)
ssh -o ProxyJump=github-actions@github.fkstrading.xyz root@<k8s-tailscale-ip>

# Run the setup script with public key
cat github-actions-key.pub | ssh root@<k8s-tailscale-ip> 'bash /tmp/setup-k8s-ssh-access.sh'
```

Or manually:

```bash
# Create user
useradd -m -s /bin/bash github-actions

# Create .ssh directory
mkdir -p /home/github-actions/.ssh
chmod 700 /home/github-actions/.ssh
chown github-actions:github-actions /home/github-actions/.ssh

# Add public key
echo "YOUR_PUBLIC_KEY" >> /home/github-actions/.ssh/authorized_keys
chmod 600 /home/github-actions/.ssh/authorized_keys
chown github-actions:github-actions /home/github-actions/.ssh/authorized_keys

# Setup kubectl access
mkdir -p /home/github-actions/.kube
cp /root/.kube/config /home/github-actions/.kube/config
chown -R github-actions:github-actions /home/github-actions/.kube
chmod 600 /home/github-actions/.kube/config

# Configure sudo for kubectl
cat > /etc/sudoers.d/github-actions << EOF
github-actions ALL=(ALL) NOPASSWD: /usr/bin/kubectl
github-actions ALL=(ALL) NOPASSWD: /usr/local/bin/kubectl
github-actions ALL=(ALL) NOPASSWD: /snap/bin/kubectl
EOF
chmod 440 /etc/sudoers.d/github-actions
```

### 4. Add Keys to GitHub Secrets

1. Go to your GitHub repository
2. Navigate to **Settings** > **Secrets and variables** > **Actions**
3. Add the following secrets:

   **Required:**
   - `SSH_PRIVATE_KEY` - Contents of `github-actions-key` (private key)
   
   **Optional (if using different keys):**
   - `K8S_SSH_KEY` - SSH private key for K8s server (if different from jump server)
   - `K8S_HOST` - K8s server Tailscale IP or hostname
   - `K8S_USER` - K8s server username (default: `github-actions`)

### 5. Test SSH Connection

Test from your local machine:

```bash
# Test jump server connection
ssh -i github-actions-key github-actions@github.fkstrading.xyz

# Test K8s server connection (via jump server)
ssh -i github-actions-key -o ProxyJump=github-actions@github.fkstrading.xyz github-actions@<k8s-tailscale-ip>

# Test kubectl access
ssh -i github-actions-key -o ProxyJump=github-actions@github.fkstrading.xyz github-actions@<k8s-tailscale-ip> 'kubectl get nodes'
```

## GitHub Actions Workflow

The deployment action is configured to:

1. SSH into jump server using `SSH_PRIVATE_KEY`
2. From jump server, SSH into K8s server (if `K8S_HOST` is provided)
3. Run `kubectl` commands to update deployments

### Example Workflow

```yaml
- name: Deploy to Kubernetes
  uses: ./.github/actions/deploy-k8s
  with:
    service-name: api
    image: nuniesmith/fks:api-latest
    namespace: fks-trading
    jump-server: github.fkstrading.xyz
    jump-user: github-actions
    k8s-host: 100.x.x.x  # Tailscale IP (optional)
    k8s-user: github-actions
  secrets:
    SSH_PRIVATE_KEY: ${{ secrets.SSH_PRIVATE_KEY }}
    K8S_SSH_KEY: ${{ secrets.K8S_SSH_KEY }}
```

## Security Best Practices

1. **Use dedicated user**: Create a separate `github-actions` user (not root)
2. **Key-only authentication**: Disable password authentication for the user
3. **Limited sudo access**: Only allow sudo for kubectl commands
4. **SSH key rotation**: Rotate keys periodically
5. **IP restrictions**: Consider restricting SSH access by IP in `/etc/ssh/sshd_config`
6. **Fail2ban**: Install fail2ban to protect against brute force attacks
7. **Audit logging**: Enable SSH audit logging
8. **Key passphrase**: Consider using a passphrase for the SSH key (requires key management)

## Troubleshooting

### SSH Connection Fails

1. **Check SSH key format**:
   ```bash
   ssh-keygen -l -f github-actions-key.pub
   ```

2. **Check permissions**:
   ```bash
   # On server
   ls -la /home/github-actions/.ssh/
   # Should be: 700 for .ssh, 600 for authorized_keys
   ```

3. **Check SSH logs**:
   ```bash
   # On server
   tail -f /var/log/auth.log
   # Or
   journalctl -u ssh -f
   ```

4. **Test SSH connection**:
   ```bash
   ssh -v -i github-actions-key github-actions@github.fkstrading.xyz
   ```

### Kubectl Not Working

1. **Check kubectl is installed**:
   ```bash
   ssh github-actions@<k8s-ip> 'which kubectl'
   ```

2. **Check kubeconfig**:
   ```bash
   ssh github-actions@<k8s-ip> 'ls -la ~/.kube/config'
   ```

3. **Test kubectl access**:
   ```bash
   ssh github-actions@<k8s-ip> 'kubectl get nodes'
   ```

4. **Check sudo access**:
   ```bash
   ssh github-actions@<k8s-ip> 'sudo kubectl get nodes'
   ```

### Deployment Fails

1. **Check deployment exists**:
   ```bash
   ssh github-actions@<k8s-ip> 'kubectl get deployments -n fks-trading'
   ```

2. **Check image exists**:
   ```bash
   # On K8s server
   kubectl get deployment fks-api -n fks-trading -o jsonpath='{.spec.template.spec.containers[0].image}'
   ```

3. **Check pod status**:
   ```bash
   ssh github-actions@<k8s-ip> 'kubectl get pods -n fks-trading'
   ```

4. **Check logs**:
   ```bash
   ssh github-actions@<k8s-ip> 'kubectl logs -n fks-trading deployment/fks-api'
   ```

## Alternative: Same Key for Both Servers

If you want to use the same SSH key for both jump server and K8s server:

1. Generate one key pair
2. Add the same public key to both servers
3. Use the same private key in GitHub Secrets for both `SSH_PRIVATE_KEY` and `K8S_SSH_KEY`

## Alternative: kubectl on Jump Server

If kubectl is available on the jump server (not on K8s server):

1. Configure kubectl on jump server to connect to K8s cluster
2. In GitHub Actions, only SSH into jump server
3. Run kubectl commands directly on jump server

Update the workflow to not use `k8s-host`:

```yaml
- name: Deploy to Kubernetes
  uses: ./.github/actions/deploy-k8s
  with:
    service-name: api
    image: nuniesmith/fks:api-latest
    namespace: fks-trading
    jump-server: github.fkstrading.xyz
    jump-user: github-actions
    # Don't set k8s-host if kubectl is on jump server
  secrets:
    SSH_PRIVATE_KEY: ${{ secrets.SSH_PRIVATE_KEY }}
```

## Next Steps

1. ✅ Generate SSH key pair
2. ✅ Setup jump server user
3. ✅ Setup K8s server user
4. ✅ Add keys to GitHub Secrets
5. ✅ Test SSH connection
6. ✅ Update GitHub Actions workflows
7. ✅ Test deployment workflow

## References

- [GitHub Actions Secrets](https://docs.github.com/en/actions/security-guides/encrypted-secrets)
- [SSH Key Management](https://docs.github.com/en/authentication/connecting-to-github-with-ssh)
- [Kubernetes kubectl](https://kubernetes.io/docs/reference/kubectl/)

