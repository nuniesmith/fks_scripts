# GitHub Secrets Setup Guide

## Required Secrets

For each service repository, you need to add the following secrets:

### 1. SSH_PRIVATE_KEY (Required)

SSH private key for accessing the jump server (`github.fkstrading.xyz`).

**How to add:**
1. Go to repository **Settings** > **Secrets and variables** > **Actions**
2. Click **New repository secret**
3. Name: `SSH_PRIVATE_KEY`
4. Value: Contents of `github-actions-key` (private key)
5. Click **Add secret**

**Example:**
```
-----BEGIN OPENSSH PRIVATE KEY-----
b3BlbnNzaC1rZXktdjEAAAAABG5vbmUAAAAEbm9uZQAAAAAAAAABAAAAMwAAAAtzc2gtZW...
-----END OPENSSH PRIVATE KEY-----
```

### 2. K8S_SSH_KEY (Optional)

SSH private key for accessing the K8s server. If not provided, uses `SSH_PRIVATE_KEY`.

**When to use:**
- If you're using different SSH keys for jump server and K8s server
- If you want to use the same key, leave this empty

**How to add:**
1. Go to repository **Settings** > **Secrets and variables** > **Actions**
2. Click **New repository secret**
3. Name: `K8S_SSH_KEY`
4. Value: Contents of K8s server private key (or same as SSH_PRIVATE_KEY)
5. Click **Add secret**

### 3. K8S_HOST (Optional)

Tailscale IP or hostname of the K8s server. If not provided, kubectl runs on the jump server.

**When to use:**
- If kubectl is on the K8s server (not on jump server)
- If you want to SSH into the K8s server to run kubectl

**How to add:**
1. Go to repository **Settings** > **Secrets and variables** > **Actions**
2. Click **New repository secret**
3. Name: `K8S_HOST`
4. Value: Tailscale IP (e.g., `100.x.x.x`) or hostname
5. Click **Add secret**

### 4. DOCKER_TOKEN (Required for build)

DockerHub authentication token for pushing images.

**How to add:**
1. Go to repository **Settings** > **Secrets and variables** > **Actions**
2. Click **New repository secret**
3. Name: `DOCKER_TOKEN`
4. Value: DockerHub access token
5. Click **Add secret**

## Setup Process

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
# Run setup script
./setup-github-actions-user.sh

# Or manually add public key
cat github-actions-key.pub | ssh root@github.fkstrading.xyz 'tee -a /home/github-actions/.ssh/authorized_keys'
```

### Step 3: Setup K8s Server

On the K8s server (via Tailscale):

```bash
# Run setup script
cat github-actions-key.pub | ssh root@<k8s-tailscale-ip> 'bash /tmp/setup-k8s-ssh-access.sh'

# Or manually add public key
cat github-actions-key.pub | ssh root@<k8s-tailscale-ip> 'tee -a /home/github-actions/.ssh/authorized_keys'
```

### Step 4: Add Secrets to GitHub

For each service repository:

1. Go to repository **Settings** > **Secrets and variables** > **Actions**
2. Add the following secrets:

   **Required:**
   - `SSH_PRIVATE_KEY` - Contents of `github-actions-key`
   - `DOCKER_TOKEN` - DockerHub access token
   
   **Optional:**
   - `K8S_SSH_KEY` - K8s server SSH key (if different from jump server)
   - `K8S_HOST` - K8s server Tailscale IP (if kubectl is on K8s server)

### Step 5: Test Deployment

```bash
# Test SSH connection
ssh -i github-actions-key github-actions@github.fkstrading.xyz

# Test K8s access
ssh -i github-actions-key -o ProxyJump=github-actions@github.fkstrading.xyz github-actions@<k8s-ip> 'kubectl get nodes'

# Test deployment
cd repo/<service>
# Push to trigger workflow
git push
```

## Two Keys Setup (Recommended)

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

## Single Key Setup (Simpler)

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

## Repository-Specific Secrets

Each service repository needs its own secrets:

- `fks_nginx` - nginx service
- `fks_tailscale` - tailscale service
- `fks_api` - api service
- `fks_web` - web service
- etc.

**Note:** You can use GitHub Organization secrets if all repositories are in the same organization.

## Security Best Practices

1. **Use dedicated user**: `github-actions` user (not root)
2. **Key-only authentication**: Disable password authentication
3. **Limited sudo access**: Only allow sudo for kubectl commands
4. **Key rotation**: Rotate keys periodically (every 90 days recommended)
5. **IP restrictions**: Consider restricting SSH access by IP
6. **Fail2ban**: Install fail2ban to protect against brute force
7. **Audit logging**: Enable SSH audit logging
8. **Key passphrase**: Consider using a passphrase for the SSH key

## Troubleshooting

### Secret Not Found

If GitHub Actions can't find a secret:
1. Check secret name (case-sensitive)
2. Check repository settings
3. Check if secret is in the correct repository
4. Check if secret is in Organization secrets (if using)

### SSH Connection Fails

1. Check secret format (should be valid SSH private key)
2. Check key permissions on server
3. Check SSH logs on server
4. Test SSH connection manually

### Deployment Fails

1. Check K8s host is accessible from jump server
2. Check kubectl is installed on K8s server
3. Check kubeconfig is configured
4. Check deployment exists in namespace
5. Check image exists in DockerHub

## References

- [GitHub Actions Secrets](https://docs.github.com/en/actions/security-guides/encrypted-secrets)
- [SSH Key Management](https://docs.github.com/en/authentication/connecting-to-github-with-ssh)
- [Setup Guide](GITHUB_ACTIONS_SSH_SETUP.md)

