#!/bin/bash
# Automated backup script

set -e

BACKUP_DIR="/backups"
DATE=$(date +%Y%m%d_%H%M%S)

echo "💾 Starting backup..."

# Backup databases
for db in fks_api fks_data; do
    echo "Backing up $db..."
    # Add your backup command here
    # Example: pg_dump $db > $BACKUP_DIR/${db}_${DATE}.sql
done

# Backup configurations
echo "Backing up configurations..."
tar -czf $BACKUP_DIR/config_${DATE}.tar.gz config/

# Cleanup old backups (keep last 7 days)
find $BACKUP_DIR -type f -mtime +7 -delete

echo "✅ Backup complete!"
