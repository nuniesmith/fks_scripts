#!/bin/bash
# Script to test fks_web database connection and verify migrations
# Usage: ./test_fks_web_db.sh [container_name]

set -e

CONTAINER_NAME="${1:-fks-web}"

echo "=== fks_web Database Connection Test ==="
echo "Container: $CONTAINER_NAME"
echo ""

# Check if container is running
if ! docker ps --format "{{.Names}}" | grep -q "^${CONTAINER_NAME}$"; then
    echo "❌ Container '$CONTAINER_NAME' is not running"
    echo "   Start it with: docker compose up -d fks-web"
    exit 1
fi

echo "✅ Container is running"
echo ""

# Test 1: Basic database connection
echo "📊 Test 1: Basic Database Connection"
if docker exec "$CONTAINER_NAME" python manage.py dbshell -c "SELECT version();" >/dev/null 2>&1; then
    DB_VERSION=$(docker exec "$CONTAINER_NAME" python manage.py dbshell -c "SELECT version();" 2>/dev/null | head -1)
    echo "✅ Database connection successful"
    echo "   Version: $DB_VERSION"
else
    echo "❌ Database connection failed"
    exit 1
fi
echo ""

# Test 2: Check database name
echo "📊 Test 2: Database Name"
DB_NAME=$(docker exec "$CONTAINER_NAME" python manage.py dbshell -c "SELECT current_database();" 2>/dev/null | head -1 | xargs)
echo "   Database: $DB_NAME"
echo ""

# Test 3: Check schema
echo "📊 Test 3: Schema Check"
SCHEMA=$(docker exec "$CONTAINER_NAME" python manage.py dbshell -c "SELECT current_schema();" 2>/dev/null | head -1 | xargs)
echo "   Schema: $SCHEMA"
echo ""

# Test 4: List all tables
echo "📊 Test 4: List All Tables"
TABLES=$(docker exec "$CONTAINER_NAME" python manage.py dbshell -c "SELECT tablename FROM pg_tables WHERE schemaname = 'app' ORDER BY tablename;" 2>/dev/null | grep -v "tablename" | grep -v "^-" | grep -v "^(" | xargs)
if [ -n "$TABLES" ]; then
    echo "✅ Found tables in 'app' schema:"
    echo "$TABLES" | tr ' ' '\n' | sed 's/^/   - /'
else
    echo "⚠️  No tables found in 'app' schema (migrations may not have run)"
fi
echo ""

# Test 5: Check User model
echo "📊 Test 5: User Model Access"
if docker exec "$CONTAINER_NAME" python manage.py shell -c "from django.contrib.auth import get_user_model; User = get_user_model(); print(f'User model: {User.__name__}'); print(f'User count: {User.objects.count()}')" 2>/dev/null; then
    echo "✅ User model accessible"
else
    echo "❌ User model not accessible"
fi
echo ""

# Test 6: Check UserProfile model
echo "📊 Test 6: UserProfile Model Access"
if docker exec "$CONTAINER_NAME" python manage.py shell -c "from authentication.models import UserProfile; print(f'UserProfile count: {UserProfile.objects.count()}')" 2>/dev/null; then
    echo "✅ UserProfile model accessible"
else
    echo "⚠️  UserProfile model not accessible (migration may not have run)"
fi
echo ""

# Test 7: Check migration status
echo "📊 Test 7: Migration Status"
UNAPPLIED=$(docker exec "$CONTAINER_NAME" python manage.py showmigrations --verbosity 0 2>/dev/null | grep "\[ \]" | wc -l)
if [ "$UNAPPLIED" -eq 0 ]; then
    echo "✅ All migrations applied"
else
    echo "⚠️  $UNAPPLIED unapplied migrations found"
    echo "   Run: docker exec $CONTAINER_NAME python manage.py migrate"
fi
echo ""

# Test 8: Test query on key tables
echo "📊 Test 8: Key Table Queries"
KEY_TABLES=("user_profiles" "auth_user" "api_keys")

for table in "${KEY_TABLES[@]}"; do
    if docker exec "$CONTAINER_NAME" python manage.py dbshell -c "SELECT COUNT(*) FROM app.$table;" >/dev/null 2>&1; then
        COUNT=$(docker exec "$CONTAINER_NAME" python manage.py dbshell -c "SELECT COUNT(*) FROM app.$table;" 2>/dev/null | grep -E "^[0-9]+" | head -1 | xargs)
        echo "   ✅ $table: $COUNT rows"
    else
        echo "   ⚠️  $table: Not accessible (may not exist or wrong schema)"
    fi
done
echo ""

echo "✅ Database connection test complete!"
echo ""
echo "📝 Summary:"
echo "  - Database: $DB_NAME"
echo "  - Schema: $SCHEMA"
echo "  - Unapplied migrations: $UNAPPLIED"
echo ""
echo "💡 Next steps:"
if [ "$UNAPPLIED" -gt 0 ]; then
    echo "  1. Run migrations: ./infrastructure/scripts/run_django_migrations.sh"
fi
echo "  2. Test authentication: ./infrastructure/scripts/test_authentication_flow.py"
echo "  3. Check service health: curl http://localhost:8000/health"
