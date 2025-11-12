#!/bin/bash
# Update K8s manifests to use DockerHub images

set -e

MANIFESTS_DIR="/home/jordan/Documents/code/fks/fks_main/k8s/manifests"
DOCKER_USERNAME="nuniesmith"

echo "================================================"
echo "  K8s Manifest Update - DockerHub Images"
echo "================================================"
echo ""

if [ ! -f "$MANIFESTS_DIR/all-services.yaml" ]; then
    echo "❌ Error: all-services.yaml not found at $MANIFESTS_DIR"
    exit 1
fi

echo "📝 Creating backup of current manifests..."
cp "$MANIFESTS_DIR/all-services.yaml" "$MANIFESTS_DIR/all-services.yaml.backup-$(date +%Y%m%d-%H%M%S)"
echo "✅ Backup created"
echo ""

echo "🔄 Updating image references..."
echo ""

# Service mappings
declare -A SERVICES=(
    ["fks-api"]="fks_api"
    ["fks-app"]="fks_app"
    ["fks-data"]="fks_data"
    ["fks-execution"]="fks_execution"
    ["fks-ai"]="fks_ai"
    ["fks-ninja"]="fks_ninja"
    ["fks-web"]="fks_web"
    ["fks-training"]="fks_training"
    ["fks-auth"]="fks_auth"
)

# Update each service
for k8s_name in "${!SERVICES[@]}"; do
    docker_name="${SERVICES[$k8s_name]}"
    
    echo "📦 $k8s_name → $DOCKER_USERNAME/$docker_name:latest"
    
    # Replace image references (handle various patterns)
    sed -i "s|image: ${docker_name}:.*|image: ${DOCKER_USERNAME}/${docker_name}:latest|g" "$MANIFESTS_DIR/all-services.yaml"
    sed -i "s|image: ${docker_name}$|image: ${DOCKER_USERNAME}/${docker_name}:latest|g" "$MANIFESTS_DIR/all-services.yaml"
    sed -i "s|image: nuniesmith/fks:${docker_name}.*|image: ${DOCKER_USERNAME}/${docker_name}:latest|g" "$MANIFESTS_DIR/all-services.yaml"
done

echo ""
echo "✅ Image references updated!"
echo ""

echo "================================================"
echo "  Apply Changes to Cluster"
echo "================================================"
echo ""
echo "Review the changes:"
echo "  diff $MANIFESTS_DIR/all-services.yaml.backup-* $MANIFESTS_DIR/all-services.yaml"
echo ""
echo "Apply to cluster:"
echo "  kubectl apply -f $MANIFESTS_DIR/all-services.yaml"
echo ""
echo "Watch rollout:"
echo "  kubectl rollout status deployment --all -n fks-trading"
echo ""
echo "Verify pods:"
echo "  kubectl get pods -n fks-trading"
echo ""
echo "Check images:"
echo "  kubectl get pods -n fks-trading -o jsonpath='{range .items[*]}{.metadata.name}{\"\t\"}{.spec.containers[*].image}{\"\n\"}{end}'"
