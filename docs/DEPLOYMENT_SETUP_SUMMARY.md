# GitHub Actions K8s Deployment Setup - Summary

## ✅ What's Been Created

### 1. SSH Setup Scripts

- **`generate-github-actions-keys.sh`** - Generates SSH key pair for GitHub Actions
- **`setup-github-actions-user.sh`** - Sets up `github-actions` user on jump server
- **`setup-k8s-ssh-access.sh`** - Sets up `github-actions` user on K8s server

### 2. Deployment Scripts

- **`deploy-service.sh`** - Manual deployment script (for testing)
- **`add-deployment-step.sh`** - Adds deployment step to existing workflows
- **`update-all-workflows.sh`** - Updates all service workflows at once

### 3. Documentation

- **`GITHUB_ACTIONS_SSH_SETUP.md`** - Full setup guide
- **`GITHUB_SECRETS_SETUP.md`** - GitHub Secrets setup guide
- **`QUICK_SETUP.md`** - Quick setup guide
- **`SETUP_GITHUB_ACTIONS_SSH.md`** - SSH setup guide

### 4. GitHub Actions

- **`.github/actions/deploy-k8s/action.yml`** - Reusable deployment action
- **`.github/workflows/deploy-k8s-template.yml`** - Template workflow
- Updated workflows in `nginx` and `tailscale` repos

## 🚀 Quick Start

### 1. Generate SSH Keys

```bash
cd repo/scripts
./generate-github-actions-keys.sh
```

### 2. Setup Jump Server

On `github.fkstrading.xyz`:

```bash
# Copy setup script
scp setup-github-actions-user.sh root@github.fkstrading.xyz:/tmp/

# SSH into jump server
ssh root@github.fkstrading.xyz

# Run setup script
bash /tmp/setup-github-actions-user.sh

# Paste public key when prompted
```

### 3. Setup K8s Server

On the K8s server (via Tailscale):

```bash
# Copy setup script
scp setup-k8s-ssh-access.sh root@<k8s-tailscale-ip>:/tmp/

# SSH into K8s server
ssh -o ProxyJump=github-actions@github.fkstrading.xyz root@<k8s-tailscale-ip>

# Run setup script with public key
cat github-actions-key.pub | ssh root@<k8s-tailscale-ip> 'bash /tmp/setup-k8s-ssh-access.sh'
```

### 4. Add Secrets to GitHub

For each service repository:

1. Go to **Settings** > **Secrets and variables** > **Actions**
2. Add secrets:
   - `SSH_PRIVATE_KEY` - Contents of `github-actions-key`
   - `K8S_SSH_KEY` - (Optional) Same as SSH_PRIVATE_KEY or different key
   - `K8S_HOST` - (Optional) K8s server Tailscale IP
   - `DOCKER_TOKEN` - DockerHub access token

### 5. Update Workflows

Workflows are already updated for:
- ✅ `nginx` - Uses Deployment
- ✅ `tailscale` - Uses StatefulSet

For other services, use:

```bash
cd repo/<service>
../scripts/add-deployment-step.sh <service-name> [deployment-name] [container-name] [resource-type]
```

## 📋 Architecture

```
GitHub Actions Runner
    ↓ (SSH with github-actions user)
Jump Server (github.fkstrading.xyz)
    ↓ (SSH with github-actions user via Tailscale)
K8s Server (Tailscale IP)
    ↓ (kubectl)
Kubernetes Cluster
```

## 🔐 Security

- **Dedicated user**: `github-actions` user (not root)
- **Key-only authentication**: No password authentication
- **Limited sudo access**: Only kubectl commands
- **Separate keys**: Can use different keys for jump server and K8s server

## 📝 Next Steps

1. ✅ Generate SSH keys
2. ✅ Setup jump server user
3. ✅ Setup K8s server user
4. ✅ Add secrets to GitHub
5. ⏳ Test deployment workflow
6. ⏳ Update other service workflows (if needed)

## 🧪 Testing

### Test SSH Connection

```bash
# Test jump server
ssh -i github-actions-key github-actions@github.fkstrading.xyz

# Test K8s server
ssh -i github-actions-key -o ProxyJump=github-actions@github.fkstrading.xyz github-actions@<k8s-ip>

# Test kubectl
ssh -i github-actions-key -o ProxyJump=github-actions@github.fkstrading.xyz github-actions@<k8s-ip> 'kubectl get nodes'
```

### Test Deployment

```bash
# Manual deployment
cd repo/k8s/scripts
./deploy-service.sh api nuniesmith/fks:api-latest

# Or trigger workflow
git push
```

## 📚 Documentation

- [Full Setup Guide](GITHUB_ACTIONS_SSH_SETUP.md)
- [Secrets Setup Guide](GITHUB_SECRETS_SETUP.md)
- [Quick Setup Guide](QUICK_SETUP.md)
- [SSH Setup Guide](SETUP_GITHUB_ACTIONS_SSH.md)

## 🔧 Troubleshooting

### SSH Connection Fails

1. Check key format: `ssh-keygen -l -f github-actions-key.pub`
2. Check permissions: `ls -la /home/github-actions/.ssh/`
3. Check SSH logs: `tail -f /var/log/auth.log`
4. Test connection: `ssh -v -i github-actions-key github-actions@github.fkstrading.xyz`

### Kubectl Not Working

1. Check kubectl: `ssh github-actions@<k8s-ip> 'which kubectl'`
2. Check kubeconfig: `ssh github-actions@<k8s-ip> 'ls -la ~/.kube/config'`
3. Test kubectl: `ssh github-actions@<k8s-ip> 'kubectl get nodes'`

### Deployment Fails

1. Check deployment: `kubectl get deployments -n fks-trading`
2. Check image: `kubectl get deployment fks-api -n fks-trading -o jsonpath='{.spec.template.spec.containers[0].image}'`
3. Check pods: `kubectl get pods -n fks-trading`
4. Check logs: `kubectl logs -n fks-trading deployment/fks-api`

## 🎯 Success Criteria

- ✅ SSH keys generated
- ✅ Jump server user configured
- ✅ K8s server user configured
- ✅ GitHub Secrets added
- ✅ Workflows updated
- ⏳ Deployment tested
- ⏳ All services deployed

## 📊 Status

- **Setup Scripts**: ✅ Complete
- **Documentation**: ✅ Complete
- **Workflows**: ✅ Updated (nginx, tailscale)
- **SSH Setup**: ⏳ Pending (needs user action)
- **GitHub Secrets**: ⏳ Pending (needs user action)
- **Testing**: ⏳ Pending

