#!/bin/bash
# Quick setup script for Tailscale in Kubernetes

set -e

echo "🚀 FKS Trading Platform - Tailscale Setup"
echo "=========================================="
echo ""

# Check if Tailscale auth key is provided
if [ -z "$TAILSCALE_AUTH_KEY" ]; then
    echo "❌ Error: TAILSCALE_AUTH_KEY environment variable not set"
    echo ""
    echo "Get your auth key from: https://login.tailscale.com/admin/settings/keys"
    echo "Then run: export TAILSCALE_AUTH_KEY='tskey-auth-xxxxx'"
    echo ""
    exit 1
fi

# Step 1: Install Tailscale Operator
echo "📦 Step 1/4: Installing Tailscale Kubernetes Operator..."
kubectl apply -f https://github.com/tailscale/tailscale/raw/main/cmd/k8s-operator/deploy/manifests/operator.yaml

echo "⏳ Waiting for operator to be ready..."
kubectl wait --for=condition=ready pod -l app=operator -n tailscale --timeout=120s

# Step 2: Create auth secret
echo ""
echo "🔐 Step 2/4: Creating Tailscale auth secret..."
kubectl create secret generic tailscale-auth \
  --namespace=fks-trading \
  --from-literal=TS_AUTHKEY="$TAILSCALE_AUTH_KEY" \
  --dry-run=client -o yaml | kubectl apply -f -

# Step 3: Update Tailscale operator config with minikube IP
echo ""
echo "🔧 Step 3/4: Configuring Tailscale connector..."
MINIKUBE_IP=$(minikube ip 2>/dev/null || echo "192.168.49.2")
echo "Using cluster IP: $MINIKUBE_IP"

# Update the YAML file with current minikube IP
sed -i.bak "s/value: \"192.168.49.2\"/value: \"$MINIKUBE_IP\"/" k8s/tailscale-operator.yaml

# Step 4: Deploy connector
echo ""
echo "🚀 Step 4/4: Deploying Tailscale connector..."
kubectl apply -f k8s/tailscale-operator.yaml

echo ""
echo "⏳ Waiting for Tailscale connector to start..."
kubectl wait --for=condition=ready pod -l app=tailscale-connector -n fks-trading --timeout=120s || true

# Show status
echo ""
echo "✅ Tailscale setup complete!"
echo ""
echo "📊 Current status:"
kubectl get pods -n fks-trading -l app=tailscale-connector

echo ""
echo "📋 View logs:"
echo "  kubectl logs -n fks-trading -l app=tailscale-connector -f"

echo ""
echo "🔍 Check Tailscale status (from your local machine):"
echo "  tailscale status | grep fks-trading"

echo ""
echo "🌐 Get Tailscale IP:"
echo "  tailscale status --json | jq -r '.Peer[] | select(.HostName==\"fks-trading-k8s\") | .TailscaleIPs[0]'"

echo ""
echo "📚 Next steps: See docs/TAILSCALE_SETUP.md"
