#!/bin/bash
# Deploy Web Services with New Celery-Enabled Images
# Run this script after GitHub Actions completes building nuniesmith/fks:web-latest

set -e

NAMESPACE="fks-trading"
IMAGE="nuniesmith/fks:web-latest"

echo "================================================"
echo "FKS Web Services Deployment"
echo "================================================"
echo ""

# Step 1: Check if new image exists on DockerHub
echo "🔍 Checking if new image is available on DockerHub..."
if docker pull $IMAGE 2>/dev/null; then
    echo "✅ Image $IMAGE found on DockerHub"
else
    echo "❌ Image not found. Please wait for GitHub Actions to complete."
    echo "   Monitor at: https://github.com/nuniesmith/fks/actions"
    exit 1
fi

# Step 2: Update Kubernetes deployments to use new image
echo ""
echo "📦 Updating Kubernetes deployments..."
kubectl set image deployment/fks-web web=$IMAGE -n $NAMESPACE
kubectl set image deployment/celery-worker worker=$IMAGE -n $NAMESPACE
kubectl set image deployment/celery-beat beat=$IMAGE -n $NAMESPACE
kubectl set image deployment/flower flower=$IMAGE -n $NAMESPACE

echo "✅ Image updated in all deployments"

# Step 3: Wait for rollout to complete
echo ""
echo "⏳ Waiting for deployments to roll out..."
kubectl rollout status deployment/fks-web -n $NAMESPACE --timeout=5m
kubectl rollout status deployment/celery-worker -n $NAMESPACE --timeout=5m
kubectl rollout status deployment/celery-beat -n $NAMESPACE --timeout=5m
kubectl rollout status deployment/flower -n $NAMESPACE --timeout=5m

echo "✅ All deployments rolled out successfully"

# Step 4: Scale up services
echo ""
echo "📈 Scaling up services..."
kubectl scale deployment fks-web --replicas=2 -n $NAMESPACE
kubectl scale deployment celery-worker --replicas=2 -n $NAMESPACE
kubectl scale deployment celery-beat --replicas=1 -n $NAMESPACE
kubectl scale deployment flower --replicas=1 -n $NAMESPACE

echo "✅ Services scaled up"

# Step 5: Wait for pods to be ready
echo ""
echo "⏳ Waiting for pods to be ready..."
kubectl wait --for=condition=ready pod -l app=fks-web -n $NAMESPACE --timeout=3m
kubectl wait --for=condition=ready pod -l app=celery-worker -n $NAMESPACE --timeout=3m
kubectl wait --for=condition=ready pod -l app=celery-beat -n $NAMESPACE --timeout=3m
kubectl wait --for=condition=ready pod -l app=flower -n $NAMESPACE --timeout=3m

echo "✅ All pods are ready"

# Step 6: Run Django migrations
echo ""
echo "🗄️  Running Django migrations..."
DJANGO_POD=$(kubectl get pods -n $NAMESPACE -l app=fks-web -o jsonpath='{.items[0].metadata.name}')
kubectl exec -n $NAMESPACE $DJANGO_POD -- python src/manage.py migrate

echo "✅ Migrations complete"

# Step 7: Verify all services
echo ""
echo "🔍 Verifying all services..."
kubectl get pods -n $NAMESPACE

TOTAL_PODS=$(kubectl get pods -n $NAMESPACE --no-headers | wc -l)
RUNNING_PODS=$(kubectl get pods -n $NAMESPACE --field-selector=status.phase=Running --no-headers | wc -l)

echo ""
echo "================================================"
echo "📊 DEPLOYMENT SUMMARY"
echo "================================================"
echo "Total Pods: $TOTAL_PODS"
echo "Running Pods: $RUNNING_PODS"
echo ""

if [ "$TOTAL_PODS" -eq "$RUNNING_PODS" ]; then
    echo "✅ SUCCESS! All services are healthy!"
    echo ""
    echo "🎯 Access your services:"
    echo "   Landing Page: https://fkstrading.xyz"
    echo "   Django Admin: https://fkstrading.xyz/admin"
    echo "   API Health:   https://api.fkstrading.xyz/health"
    echo "   Grafana:      https://grafana.fkstrading.xyz"
    echo "   Flower:       https://flower.fkstrading.xyz"
    echo ""
    echo "🎉 Congratulations! You've reached 100% operational status!"
    echo "   14/14 services running (100%)"
else
    echo "⚠️  Some pods are not running. Checking logs..."
    echo ""
    kubectl get pods -n $NAMESPACE | grep -v "Running" || echo "All pods are running"
fi

echo "================================================"
