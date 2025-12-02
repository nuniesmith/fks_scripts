# GitHub Actions SSH Setup - Quick Guide

## Overview

This guide explains how to set up SSH access for GitHub Actions to deploy to Kubernetes via a jump server (`github.fkstrading.xyz`).

## Architecture

```
GitHub Actions Runner
    ↓ (SSH with github-actions user)
Jump Server (github.fkstrading.xyz)
    ↓ (SSH with github-actions user via Tailscale)
K8s Server (Tailscale IP)
    ↓ (kubectl)
Kubernetes Cluster
```

## Quick Setup

### 1. Generate SSH Key Pair

```bash
cd repo/scripts
./generate-github-actions-keys.sh
```

This creates:
- `github-actions-key` (private key) - Add to GitHub Secrets
- `github-actions-key.pub` (public key) - Add to servers

### 2. Setup Jump Server

On `github.fkstrading.xyz`:

```bash
# Copy setup script
scp setup-github-actions-user.sh root@github.fkstrading.xyz:/tmp/

# SSH into jump server
ssh root@github.fkstrading.xyz

# Run setup script
bash /tmp/setup-github-actions-user.sh

# Add public key (when prompted, paste the public key from github-actions-key.pub)
```

Or manually:

```bash
# Create user
useradd -m -s /bin/bash github-actions

# Setup SSH
mkdir -p /home/github-actions/.ssh
chmod 700 /home/github-actions/.ssh
chown github-actions:github-actions /home/github-actions/.ssh

# Add public key
cat github-actions-key.pub >> /home/github-actions/.ssh/authorized_keys
chmod 600 /home/github-actions/.ssh/authorized_keys
chown github-actions:github-actions /home/github-actions/.ssh/authorized_keys
```

### 3. Setup K8s Server

On the K8s server (via Tailscale):

```bash
# From jump server, copy setup script
scp setup-k8s-ssh-access.sh root@<k8s-tailscale-ip>:/tmp/

# SSH into K8s server (via jump server)
ssh -o ProxyJump=github-actions@github.fkstrading.xyz root@<k8s-tailscale-ip>

# Run setup script with public key
cat github-actions-key.pub | ssh root@<k8s-tailscale-ip> 'bash /tmp/setup-k8s-ssh-access.sh'
```

Or manually:

```bash
# Create user
useradd -m -s /bin/bash github-actions

# Setup SSH
mkdir -p /home/github-actions/.ssh
chmod 700 /home/github-actions/.ssh
chown github-actions:github-actions /home/github-actions/.ssh

# Add public key
cat github-actions-key.pub >> /home/github-actions/.ssh/authorized_keys
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

For each service repository, add these secrets:

1. Go to repository **Settings** > **Secrets and variables** > **Actions**
2. Add the following secrets:

   **Required:**
   - `SSH_PRIVATE_KEY` - Contents of `github-actions-key` (private key)
   
   **Optional:**
   - `K8S_SSH_KEY` - SSH private key for K8s server (if different from jump server, otherwise use same as SSH_PRIVATE_KEY)
   - `K8S_HOST` - K8s server Tailscale IP or hostname (e.g., `100.x.x.x`)
   - `K8S_USER` - K8s server username (default: `github-actions`)

### 5. Update Workflows

For each service, update the `docker-build-push.yml` workflow to include deployment:

```yaml
- name: Deploy to Kubernetes
  if: success()
  uses: ./.github/workflows/deploy-k8s.yml
  with:
    image: ${{ env.DOCKER_REPO }}:${{ env.SERVICE_NAME }}-latest
  secrets:
    SSH_PRIVATE_KEY: ${{ secrets.SSH_PRIVATE_KEY }}
    K8S_SSH_KEY: ${{ secrets.K8S_SSH_KEY }}
    K8S_HOST: ${{ secrets.K8S_HOST }}
```

Or create the workflow file:

```bash
cd repo/<service>
./scripts/create-deployment-workflow.sh <service-name> [deployment-name] [container-name]
```

## Testing

### Test SSH Connection

```bash
# Test jump server
ssh -i github-actions-key github-actions@github.fkstrading.xyz

# Test K8s server (via jump server)
ssh -i github-actions-key -o ProxyJump=github-actions@github.fkstrading.xyz github-actions@<k8s-tailscale-ip>

# Test kubectl
ssh -i github-actions-key -o ProxyJump=github-actions@github.fkstrading.xyz github-actions@<k8s-tailscale-ip> 'kubectl get nodes'
```

### Test Deployment

```bash
# Test deployment script
cd repo/k8s/scripts
./deploy-service.sh api nuniesmith/fks:api-latest
```

## Two Keys Approach (Recommended)

If you want to use separate keys for jump server and K8s server:

1. **Generate two key pairs**:
   ```bash
   # Jump server key
   ssh-keygen -t ed25519 -C "github-actions-jump@fkstrading.xyz" -f github-actions-jump-key
   
   # K8s server key
   ssh-keygen -t ed25519 -C "github-actions-k8s@fkstrading.xyz" -f github-actions-k8s-key
   ```

2. **Add jump server public key to jump server**:
   ```bash
   cat github-actions-jump-key.pub | ssh root@github.fkstrading.xyz 'tee -a /home/github-actions/.ssh/authorized_keys'
   ```

3. **Add K8s server public key to K8s server**:
   ```bash
   cat github-actions-k8s-key.pub | ssh root@<k8s-ip> 'tee -a /home/github-actions/.ssh/authorized_keys'
   ```

4. **Add both private keys to GitHub Secrets**:
   - `SSH_PRIVATE_KEY` - Jump server private key
   - `K8S_SSH_KEY` - K8s server private key

## Single Key Approach (Simpler)

If you want to use the same key for both servers:

1. **Generate one key pair**:
   ```bash
   ssh-keygen -t ed25519 -C "github-actions@fkstrading.xyz" -f github-actions-key
   ```

2. **Add public key to both servers**:
   ```bash
   # Jump server
   cat github-actions-key.pub | ssh root@github.fkstrading.xyz 'tee -a /home/github-actions/.ssh/authorized_keys'
   
   # K8s server
   cat github-actions-key.pub | ssh root@<k8s-ip> 'tee -a /home/github-actions/.ssh/authorized_keys'
   ```

3. **Add private key to GitHub Secrets**:
   - `SSH_PRIVATE_KEY` - Private key (used for both servers)
   - `K8S_SSH_KEY` - Leave empty or use same as SSH_PRIVATE_KEY

## Security Best Practices

1. **Use dedicated user**: `github-actions` user (not root)
2. **Key-only authentication**: Disable password authentication
3. **Limited sudo access**: Only allow sudo for kubectl commands
4. **Key rotation**: Rotate keys periodically
5. **IP restrictions**: Consider restricting SSH access by IP
6. **Fail2ban**: Install fail2ban to protect against brute force
7. **Audit logging**: Enable SSH audit logging

## Troubleshooting

### SSH Connection Fails

1. Check key format: `ssh-keygen -l -f github-actions-key.pub`
2. Check permissions: `ls -la /home/github-actions/.ssh/`
3. Check SSH logs: `tail -f /var/log/auth.log`
4. Test connection: `ssh -v -i github-actions-key github-actions@github.fkstrading.xyz`

### Kubectl Not Working

1. Check kubectl: `ssh github-actions@<k8s-ip> 'which kubectl'`
2. Check kubeconfig: `ssh github-actions@<k8s-ip> 'ls -la ~/.kube/config'`
3. Test kubectl: `ssh github-actions@<k8s-ip> 'kubectl get nodes'`
4. Check sudo: `ssh github-actions@<k8s-ip> 'sudo kubectl get nodes'`

### Deployment Fails

1. Check deployment exists: `kubectl get deployments -n fks-trading`
2. Check image: `kubectl get deployment fks-api -n fks-trading -o jsonpath='{.spec.template.spec.containers[0].image}'`
3. Check pods: `kubectl get pods -n fks-trading`
4. Check logs: `kubectl logs -n fks-trading deployment/fks-api`

## Next Steps

1. ✅ Generate SSH key pair
2. ✅ Setup jump server user
3. ✅ Setup K8s server user
4. ✅ Add keys to GitHub Secrets
5. ✅ Test SSH connection
6. ✅ Update GitHub Actions workflows
7. ✅ Test deployment workflow

## References

- [Full Setup Guide](GITHUB_ACTIONS_SSH_SETUP.md)
- [GitHub Actions Secrets](https://docs.github.com/en/actions/security-guides/encrypted-secrets)
- [SSH Key Management](https://docs.github.com/en/authentication/connecting-to-github-with-ssh)

