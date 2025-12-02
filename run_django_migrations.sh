#!/bin/bash
# Script to run Django migrations on fks_web_db
# Usage: ./run_django_migrations.sh [service_name]

set -e

SERVICE_NAME="${1:-fks-web}"
CONTAINER_NAME="${2:-fks-web}"

echo "=== Django Migrations Runner ==="
echo "Service: $SERVICE_NAME"
echo "Container: $CONTAINER_NAME"
echo ""

# Check if container is running
if ! docker ps --format "{{.Names}}" | grep -q "^${CONTAINER_NAME}$"; then
    echo "❌ Container '$CONTAINER_NAME' is not running"
    echo "   Start it with: docker compose up -d $SERVICE_NAME"
    exit 1
fi

echo "✅ Container is running"
echo ""

# Check database connection
echo "📊 Checking database connection..."
if docker exec "$CONTAINER_NAME" python manage.py dbshell -c "SELECT 1;" >/dev/null 2>&1; then
    echo "✅ Database connection successful"
else
    echo "⚠️  Database connection check failed (this might be OK if migrations haven't run yet)"
fi
echo ""

# Show current migration status
echo "📋 Current migration status:"
docker exec "$CONTAINER_NAME" python manage.py showmigrations --verbosity 0 || {
    echo "❌ Failed to show migrations"
    exit 1
}
echo ""

# Run migrations
echo "🚀 Running migrations..."
docker exec "$CONTAINER_NAME" python manage.py migrate --verbosity 2 || {
    echo "❌ Migration failed"
    exit 1
}
echo ""

# Show final migration status
echo "📋 Final migration status:"
docker exec "$CONTAINER_NAME" python manage.py showmigrations --verbosity 0
echo ""

# Verify key tables exist
echo "🔍 Verifying key tables..."
TABLES=("user_profiles" "auth_user" "api_keys" "portfolio_accounts" "risk_profiles" "trading_signals")

for table in "${TABLES[@]}"; do
    if docker exec "$CONTAINER_NAME" python manage.py dbshell -c "SELECT 1 FROM app.$table LIMIT 1;" >/dev/null 2>&1; then
        echo "  ✅ $table exists"
    else
        echo "  ⚠️  $table not found (might be in different schema or not created yet)"
    fi
done
echo ""

echo "✅ Migration process complete!"
echo ""
echo "📝 Next steps:"
echo "  1. Verify tables: docker exec $CONTAINER_NAME python manage.py dbshell"
echo "  2. Check UserProfile: docker exec $CONTAINER_NAME python manage.py shell -c \"from authentication.models import UserProfile; print(UserProfile.objects.count())\""
echo "  3. Run data migration if needed: docker exec $CONTAINER_NAME python manage.py migrate authentication 0004"
