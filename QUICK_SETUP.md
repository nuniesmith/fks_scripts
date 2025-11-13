# Quick Setup Guide: GitHub Actions SSH Deployment

## Overview

This guide shows you how to quickly set up SSH access for GitHub Actions to deploy to Kubernetes via a jump server.

## Architecture

```
GitHub Actions → SSH (github-actions@github.fkstrading.xyz) → SSH (github-actions@k8s-tailscale-ip) → kubectl
```

## Quick Setup (5 Steps)

### Step 1: Generate SSH Keys

```bash
cd repo/scripts
./generate-github-actions-keys.sh
```

This creates:
- `github-actions-key` (private key) - Add to GitHub Secrets
- `github-actions-key.pub` (public key) - Add to servers

### Step 2: Setup Jump Server

On `github.fkstrading.xyz`:

```bash
# Copy setup script
scp setup-github-actions-user.sh root@github.fkstrading.xyz:/tmp/

# SSH into jump server
ssh root@github.fkstrading.xyz

# Run setup script
bash /tmp/setup-github-actions-user.sh

# When prompted, paste the public key from github-actions-key.pub
```

### Step 3: Setup K8s Server

On the K8s server (via Tailscale):

```bash
# From jump server, copy setup script
scp setup-k8s-ssh-access.sh root@<k8s-tailscale-ip>:/tmp/

# SSH into K8s server (via jump server)
ssh -o ProxyJump=github-actions@github.fkstrading.xyz root@<k8s-tailscale-ip>

# Run setup script with public key
cat github-actions-key.pub | ssh root@<k8s-tailscale-ip> 'bash /tmp/setup-k8s-ssh-access.sh'
```

### Step 4: Add Secrets to GitHub

For each service repository:

1. Go to **Settings** > **Secrets and variables** > **Actions**
2. Add these secrets:

   **Required:**
   - `SSH_PRIVATE_KEY` - Contents of `github-actions-key` (private key)
   
   **Optional:**
   - `K8S_SSH_KEY` - Same as SSH_PRIVATE_KEY (if using same key) or different key
   - `K8S_HOST` - K8s server Tailscale IP (e.g., `100.x.x.x`)

### Step 5: Test Deployment

```bash
# Test SSH connection
ssh -i github-actions-key github-actions@github.fkstrading.xyz

# Test K8s access
ssh -i github-actions-key -o ProxyJump=github-actions@github.fkstrading.xyz github-actions@<k8s-ip> 'kubectl get nodes'

# Test deployment (push to trigger workflow)
git push
```

## Two Keys vs One Key

### Option 1: One Key (Simpler)

Use the same SSH key for both jump server and K8s server:

1. Generate one key pair
2. Add public key to both servers
3. Add private key to GitHub Secrets as `SSH_PRIVATE_KEY`
4. Leave `K8S_SSH_KEY` empty or use same value

### Option 2: Two Keys (More Secure)

Use different SSH keys for jump server and K8s server:

1. Generate two key pairs:
   - `github-actions-jump-key` (for jump server)
   - `github-actions-k8s-key` (for K8s server)

2. Add jump server public key to jump server
3. Add K8s server public key to K8s server
4. Add both private keys to GitHub Secrets:
   - `SSH_PRIVATE_KEY` - Jump server private key
   - `K8S_SSH_KEY` - K8s server private key

## GitHub Secrets Summary

For each service repository, add:

| Secret | Required | Description |
|--------|----------|-------------|
| `SSH_PRIVATE_KEY` | Yes | SSH private key for jump server |
| `K8S_SSH_KEY` | No | SSH private key for K8s server (uses SSH_PRIVATE_KEY if not set) |
| `K8S_HOST` | No | K8s server Tailscale IP (if kubectl is on K8s server) |
| `DOCKER_TOKEN` | Yes | DockerHub access token |

## Workflow Status

The following services have deployment workflows:

- ✅ `nginx` - Updated with deployment step
- ✅ `tailscale` - Updated with deployment step (uses StatefulSet)
- ⏳ Other services - Can be updated using `add-deployment-step.sh`

## Next Steps

1. ✅ Generate SSH keys
2. ✅ Setup jump server user
3. ✅ Setup K8s server user
4. ✅ Add secrets to GitHub
5. ⏳ Test deployment workflow
6. ⏳ Update other service workflows

## Troubleshooting

### SSH Connection Fails

```bash
# Test connection
ssh -v -i github-actions-key github-actions@github.fkstrading.xyz

# Check server logs
ssh root@github.fkstrading.xyz 'tail -f /var/log/auth.log'
```

### Kubectl Not Working

```bash
# Test kubectl access
ssh -i github-actions-key -o ProxyJump=github-actions@github.fkstrading.xyz github-actions@<k8s-ip> 'kubectl get nodes'

# Check kubeconfig
ssh -i github-actions-key -o ProxyJump=github-actions@github.fkstrading.xyz github-actions@<k8s-ip> 'ls -la ~/.kube/config'
```

### Deployment Fails

1. Check deployment exists: `kubectl get deployments -n fks-trading`
2. Check image exists: `kubectl get deployment fks-api -n fks-trading -o jsonpath='{.spec.template.spec.containers[0].image}'`
3. Check pods: `kubectl get pods -n fks-trading`
4. Check logs: `kubectl logs -n fks-trading deployment/fks-api`

## References

- [Full Setup Guide](GITHUB_ACTIONS_SSH_SETUP.md)
- [Secrets Setup Guide](GITHUB_SECRETS_SETUP.md)
- [GitHub Actions Secrets](https://docs.github.com/en/actions/security-guides/encrypted-secrets)

