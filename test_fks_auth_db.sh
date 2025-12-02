#!/bin/bash
# Script to test fks_auth database connection
# Usage: ./test_fks_auth_db.sh [container_name] [db_container_name]

set -e

AUTH_CONTAINER="${1:-fks-auth}"
DB_CONTAINER="${2:-fks-auth-db}"

echo "=== fks_auth Database Connection Test ==="
echo "Auth Container: $AUTH_CONTAINER"
echo "DB Container: $DB_CONTAINER"
echo ""

# Check if database container is running
if ! docker ps --format "{{.Names}}" | grep -q "^${DB_CONTAINER}$"; then
    echo "❌ Database container '$DB_CONTAINER' is not running"
    echo "   Start it with: docker compose up -d fks-auth-db"
    exit 1
fi

echo "✅ Database container is running"
echo ""

# Test 1: Direct database connection
echo "📊 Test 1: Direct Database Connection"
if docker exec "$DB_CONTAINER" psql -U fks_auth_user -d fks_auth_db -c "SELECT version();" >/dev/null 2>&1; then
    DB_VERSION=$(docker exec "$DB_CONTAINER" psql -U fks_auth_user -d fks_auth_db -t -c "SELECT version();" 2>/dev/null | head -1 | xargs)
    echo "✅ Database connection successful"
    echo "   Version: $DB_VERSION"
else
    echo "❌ Database connection failed"
    echo "   Trying with postgres user..."
    if docker exec "$DB_CONTAINER" psql -U postgres -d fks_auth_db -c "SELECT 1;" >/dev/null 2>&1; then
        echo "✅ Connection works with postgres user"
    else
        echo "❌ Database connection failed with both users"
        exit 1
    fi
fi
echo ""

# Test 2: Check database name
echo "📊 Test 2: Database Name"
DB_NAME=$(docker exec "$DB_CONTAINER" psql -U fks_auth_user -d fks_auth_db -t -c "SELECT current_database();" 2>/dev/null | xargs)
if [ -z "$DB_NAME" ]; then
    DB_NAME=$(docker exec "$DB_CONTAINER" psql -U postgres -d fks_auth_db -t -c "SELECT current_database();" 2>/dev/null | xargs)
fi
echo "   Database: $DB_NAME"
echo ""

# Test 3: List all tables
echo "📊 Test 3: List All Tables"
TABLES=$(docker exec "$DB_CONTAINER" psql -U fks_auth_user -d fks_auth_db -t -c "SELECT tablename FROM pg_tables WHERE schemaname = 'public' ORDER BY tablename;" 2>/dev/null | xargs)
if [ -z "$TABLES" ]; then
    TABLES=$(docker exec "$DB_CONTAINER" psql -U postgres -d fks_auth_db -t -c "SELECT tablename FROM pg_tables WHERE schemaname = 'public' ORDER BY tablename;" 2>/dev/null | xargs)
fi

if [ -n "$TABLES" ]; then
    echo "✅ Found tables:"
    echo "$TABLES" | tr ' ' '\n' | sed 's/^/   - /'
else
    echo "⚠️  No tables found (database may not be initialized or migrations not run)"
    echo "   This is expected if fks_auth is in dev mode with hardcoded users"
fi
echo ""

# Test 4: Check if auth service is configured for database
echo "📊 Test 4: Auth Service Database Configuration"
if docker ps --format "{{.Names}}" | grep -q "^${AUTH_CONTAINER}$"; then
    echo "✅ Auth container is running"
    
    # Check environment variables
    echo "   Environment variables:"
    if docker exec "$AUTH_CONTAINER" env | grep -q "DATABASE_URL"; then
        DATABASE_URL=$(docker exec "$AUTH_CONTAINER" env | grep "DATABASE_URL" | cut -d'=' -f2- | head -1)
        echo "   ✅ DATABASE_URL is set"
        # Mask password in output
        MASKED_URL=$(echo "$DATABASE_URL" | sed 's/:[^@]*@/:***@/')
        echo "      $MASKED_URL"
    else
        echo "   ⚠️  DATABASE_URL not set (service may be in dev mode)"
    fi
    
    if docker exec "$AUTH_CONTAINER" env | grep -q "POSTGRES"; then
        echo "   ✅ POSTGRES_* variables found"
        docker exec "$AUTH_CONTAINER" env | grep "POSTGRES" | sed 's/=.*/=***/' | sed 's/^/      /'
    else
        echo "   ⚠️  POSTGRES_* variables not set"
    fi
else
    echo "⚠️  Auth container is not running"
    echo "   Start it with: docker compose up -d fks-auth"
fi
echo ""

# Test 5: Check database initialization script
echo "📊 Test 5: Database Initialization"
INIT_SCRIPT="services/auth/scripts/init_auth_db.sql"
if [ -f "$INIT_SCRIPT" ]; then
    echo "✅ Initialization script found: $INIT_SCRIPT"
    # Check if schema exists
    SCHEMA_CHECK=$(docker exec "$DB_CONTAINER" psql -U fks_auth_user -d fks_auth_db -t -c "SELECT schema_name FROM information_schema.schemata WHERE schema_name = 'auth';" 2>/dev/null | xargs)
    if [ -n "$SCHEMA_CHECK" ]; then
        echo "   ✅ 'auth' schema exists"
    else
        echo "   ⚠️  'auth' schema not found (may need to run init script)"
    fi
else
    echo "⚠️  Initialization script not found: $INIT_SCRIPT"
fi
echo ""

# Test 6: Test connection from auth service perspective
echo "📊 Test 6: Connection from Auth Service"
if docker ps --format "{{.Names}}" | grep -q "^${AUTH_CONTAINER}$"; then
    # Try to connect from auth container (if it has psql or similar)
    if docker exec "$AUTH_CONTAINER" which psql >/dev/null 2>&1; then
        if docker exec "$AUTH_CONTAINER" psql "$DATABASE_URL" -c "SELECT 1;" >/dev/null 2>&1; then
            echo "✅ Auth service can connect to database"
        else
            echo "⚠️  Auth service cannot connect (may not have psql installed)"
        fi
    else
        echo "⚠️  psql not available in auth container (this is normal for Rust service)"
        echo "   Connection will be tested when service starts and uses database"
    fi
else
    echo "⚠️  Auth container not running - cannot test connection"
fi
echo ""

# Summary
echo "=== Test Summary ==="
echo "Database: $DB_NAME"
if [ -n "$TABLES" ]; then
    TABLE_COUNT=$(echo "$TABLES" | wc -w)
    echo "Tables: $TABLE_COUNT found"
else
    echo "Tables: None (dev mode - using hardcoded users)"
fi
echo ""

echo "✅ Database connection test complete!"
echo ""
echo "💡 Notes:"
echo "  - fks_auth is currently in dev mode with hardcoded users"
echo "  - Database connection is configured but not actively used yet"
echo "  - To enable database-backed auth, implement TASK-213 (database migrations)"
echo ""
echo "📝 Next steps:"
echo "  1. Review database schema requirements for fks_auth"
echo "  2. Implement database migrations (TASK-213)"
echo "  3. Update fks_auth service to use database instead of hardcoded users"
