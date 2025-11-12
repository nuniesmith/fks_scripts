#!/bin/bash
# Setup Local Kubernetes Environment for FKS
# Creates self-signed certificates for fkstrading.xyz domain

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
K8S_DIR="$PROJECT_ROOT/k8s"
CERTS_DIR="$K8S_DIR/certs"

echo "🚀 Setting Up Local Kubernetes Environment for FKS"
echo "=================================================="
echo ""

# Check prerequisites
echo "📋 Checking prerequisites..."

if ! command -v kubectl &> /dev/null; then
    echo "❌ kubectl not found. Please install kubectl."
    exit 1
fi

if ! command -v minikube &> /dev/null && ! kubectl cluster-info &> /dev/null; then
    echo "⚠️  No Kubernetes cluster detected. Using minikube..."
    if ! command -v minikube &> /dev/null; then
        echo "❌ minikube not found. Please install minikube or configure kubectl."
        exit 1
    fi
    echo "Starting minikube..."
    minikube start
fi

echo "✅ Kubernetes cluster ready"
echo ""

# Create certs directory
mkdir -p "$CERTS_DIR"

# Generate self-signed certificate for *.fkstrading.xyz
echo "🔐 Generating self-signed certificate for *.fkstrading.xyz..."

openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -keyout "$CERTS_DIR/tls.key" \
    -out "$CERTS_DIR/tls.crt" \
    -subj "/C=US/ST=State/L=City/O=FKS/CN=*.fkstrading.xyz" \
    -addext "subjectAltName=DNS:*.fkstrading.xyz,DNS:fkstrading.xyz"

echo "✅ Certificate generated"
echo "   Certificate: $CERTS_DIR/tls.crt"
echo "   Key: $CERTS_DIR/tls.key"
echo ""

# Create K8s secret for TLS
echo "📦 Creating Kubernetes TLS secret..."

kubectl create namespace fks-trading --dry-run=client -o yaml | kubectl apply -f -

kubectl create secret tls fks-tls \
    --cert="$CERTS_DIR/tls.crt" \
    --key="$CERTS_DIR/tls.key" \
    -n fks-trading \
    --dry-run=client -o yaml | kubectl apply -f -

echo "✅ TLS secret created in fks-trading namespace"
echo ""

# Update /etc/hosts for local domain
echo "🌐 Updating /etc/hosts for fkstrading.xyz..."

# Get cluster IP (minikube or load balancer)
if command -v minikube &> /dev/null; then
    CLUSTER_IP=$(minikube ip)
else
    CLUSTER_IP="127.0.0.1"
fi

# Check if entries already exist
if ! grep -q "fkstrading.xyz" /etc/hosts; then
    echo "Adding fkstrading.xyz entries to /etc/hosts (requires sudo)..."
    sudo bash -c "cat >> /etc/hosts << EOF

# FKS Trading Platform - Local K8s
$CLUSTER_IP fkstrading.xyz
$CLUSTER_IP api.fkstrading.xyz
$CLUSTER_IP grafana.fkstrading.xyz
$CLUSTER_IP prometheus.fkstrading.xyz
$CLUSTER_IP monitor.fkstrading.xyz
EOF"
    echo "✅ /etc/hosts updated"
else
    echo "⚠️  fkstrading.xyz entries already exist in /etc/hosts"
fi

echo ""
echo "✅ Local K8s environment setup complete!"
echo ""
echo "📋 Next Steps:"
echo "  1. Deploy services: kubectl apply -f $K8S_DIR/manifests/"
echo "  2. Access services:"
echo "     - API: https://api.fkstrading.xyz"
echo "     - Grafana: https://grafana.fkstrading.xyz"
echo "     - Prometheus: https://prometheus.fkstrading.xyz"
echo ""
echo "⚠️  Note: You'll need to accept the self-signed certificate in your browser"

