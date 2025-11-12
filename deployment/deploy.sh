#!/bin/bash
# Automated deployment script for FKS services

set -e

SERVICE_NAME=${1:-}
ENVIRONMENT=${2:-staging}
NAMESPACE="fks-trading"

if [ -z "$SERVICE_NAME" ]; then
    echo "Usage: $0 <service_name> [environment]"
    exit 1
fi

echo "🚀 Deploying $SERVICE_NAME to $ENVIRONMENT..."

# Build image
echo "📦 Building Docker image..."
docker build -t nuniesmith/$SERVICE_NAME:latest .

# Push to registry
echo "📤 Pushing to Docker Hub..."
docker push nuniesmith/$SERVICE_NAME:latest

# Deploy to K8s
echo "☸️  Deploying to Kubernetes..."
kubectl set image deployment/$SERVICE_NAME $SERVICE_NAME=nuniesmith/$SERVICE_NAME:latest -n $NAMESPACE

# Wait for rollout
echo "⏳ Waiting for rollout..."
kubectl rollout status deployment/$SERVICE_NAME -n $NAMESPACE

# Verify health
echo "🏥 Verifying health..."
sleep 10
kubectl exec -n $NAMESPACE deployment/$SERVICE_NAME -- curl -f http://localhost:PORT/health || echo "⚠️  Health check failed"

echo "✅ Deployment complete!"
