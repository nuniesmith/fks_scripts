#!/bin/bash
# Automated database migration script

set -e

SERVICE_NAME=${1:-}
MIGRATION_DIR=${2:-migrations}

if [ -z "$SERVICE_NAME" ]; then
    echo "Usage: $0 <service_name> [migration_dir]"
    exit 1
fi

echo "🔄 Running migrations for $SERVICE_NAME..."

# Run migrations
if [ -d "$MIGRATION_DIR" ]; then
    for migration in $MIGRATION_DIR/*.sql; do
        echo "Running: $migration"
        # Add your migration runner here
        # Example: psql -f "$migration"
    done
else
    echo "⚠️  No migrations directory found"
fi

echo "✅ Migrations complete!"
