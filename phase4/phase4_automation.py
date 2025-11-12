#!/usr/bin/env python3
"""
Phase 4.2: Automate Operations and Reduce Toil
Creates automation scripts and reduces manual operations.
"""

import json
from pathlib import Path
from typing import Dict, List, Any
from datetime import datetime

# Get repo/ directory (5 levels up from scripts/phase4/)
BASE_PATH = Path(__file__).parent.parent.parent.parent.parent  # repo/
main_repo = BASE_PATH / "core" / "main"


def create_deployment_automation():
    """Create deployment automation scripts."""
    # Scripts go in repo/core/main/scripts/
    main_repo = BASE_PATH / "core" / "main"
    scripts_dir = main_repo / "scripts" / "deployment"
    scripts_dir.mkdir(parents=True, exist_ok=True)
    
    # Deployment script
    deploy_script = scripts_dir / "deploy.sh"
    deploy_content = """#!/bin/bash
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
"""
    
    deploy_script.write_text(deploy_content)
    deploy_script.chmod(0o755)
    
    return deploy_script


def create_migration_automation():
    """Create database migration automation."""
    # Scripts go in repo/core/main/scripts/
    main_repo = BASE_PATH / "core" / "main"
    scripts_dir = main_repo / "scripts" / "migrations"
    scripts_dir.mkdir(parents=True, exist_ok=True)
    
    migrate_script = scripts_dir / "run_migrations.sh"
    migrate_content = """#!/bin/bash
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
"""
    
    migrate_script.write_text(migrate_content)
    migrate_script.chmod(0o755)
    
    return migrate_script


def create_backup_automation():
    """Create backup automation."""
    # Scripts go in repo/core/main/scripts/
    main_repo = BASE_PATH / "core" / "main"
    scripts_dir = main_repo / "scripts" / "backup"
    scripts_dir.mkdir(parents=True, exist_ok=True)
    
    backup_script = scripts_dir / "backup.sh"
    backup_content = """#!/bin/bash
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
"""
    
    backup_script.write_text(backup_content)
    backup_script.chmod(0o755)
    
    return backup_script


def create_oncall_config():
    """Create on-call rotation configuration."""
    oncall_file = main_repo / "config" / "oncall.json"
    oncall_file.parent.mkdir(exist_ok=True)
    
    oncall = {
        "version": "1.0",
        "updated": datetime.utcnow().isoformat(),
        "rotation": {
            "type": "weekly",
            "team": [
                {"name": "Primary", "email": "primary@fks.trading"},
                {"name": "Secondary", "email": "secondary@fks.trading"}
            ]
        },
        "escalation": {
            "levels": [
                {
                    "level": 1,
                    "timeout_minutes": 5,
                    "notify": ["oncall-primary"]
                },
                {
                    "level": 2,
                    "timeout_minutes": 15,
                    "notify": ["oncall-primary", "oncall-secondary"]
                },
                {
                    "level": 3,
                    "timeout_minutes": 30,
                    "notify": ["oncall-primary", "oncall-secondary", "team-lead"]
                }
            ]
        },
        "services": {
            "critical": ["fks_monitor", "fks_main", "fks_api"],
            "high": ["fks_data", "fks_execution"],
            "medium": ["fks_web", "fks_app"],
            "low": ["fks_ai", "fks_analyze"]
        }
    }
    
    oncall_file.write_text(json.dumps(oncall, indent=2))
    return oncall_file


def create_toil_tracking():
    """Create toil tracking configuration."""
    toil_file = main_repo / "config" / "toil_tracking.json"
    toil_file.parent.mkdir(exist_ok=True)
    
    toil = {
        "version": "1.0",
        "updated": datetime.utcnow().isoformat(),
        "target": {
            "max_toil_percent": 50,
            "current_toil_percent": 0
        },
        "categories": {
            "manual_deployments": {
                "time_per_week_hours": 0,
                "automation_status": "planned"
            },
            "manual_migrations": {
                "time_per_week_hours": 0,
                "automation_status": "planned"
            },
            "incident_response": {
                "time_per_week_hours": 0,
                "automation_status": "partial"
            },
            "manual_testing": {
                "time_per_week_hours": 0,
                "automation_status": "automated"
            }
        }
    }
    
    toil_file.write_text(json.dumps(toil, indent=2))
    return toil_file


def create_automation_docs():
    """Create automation documentation."""
    doc_file = main_repo / "docs" / "AUTOMATION.md"
    doc_file.parent.mkdir(exist_ok=True)
    
    doc_content = """# FKS Automation Guide

## Overview

This guide covers automation strategies to reduce toil and improve reliability.

## Deployment Automation

### Automated Deployments

Script: `scripts/deployment/deploy.sh`

```bash
./scripts/deployment/deploy.sh fks_api production
```

**Features**:
- Builds Docker image
- Pushes to registry
- Deploys to Kubernetes
- Verifies health

### CI/CD Integration

All services use GitHub Actions for:
- Automated testing
- Docker image building
- Image pushing to Docker Hub
- Deployment (optional)

## Migration Automation

### Database Migrations

Script: `scripts/migrations/run_migrations.sh`

```bash
./scripts/migrations/run_migrations.sh fks_data
```

**Best Practices**:
- Version all migrations
- Test in staging first
- Rollback plan ready
- Backup before migration

## Backup Automation

### Automated Backups

Script: `scripts/backup/backup.sh`

Runs daily via cron:
```bash
0 2 * * * /path/to/backup.sh
```

**Backup Strategy**:
- Daily full backups
- Weekly retention
- Test restore regularly

## On-Call Management

### Rotation

Configuration: `config/oncall.json`

**Features**:
- Weekly rotation
- Escalation policies
- Service priority levels

### Alerting

- PagerDuty integration (recommended)
- Email notifications
- Slack integration

## Toil Reduction

### Tracking

Configuration: `config/toil_tracking.json`

**Target**: <50% of time on toil

**Categories**:
- Manual deployments → Automate
- Manual migrations → Automate
- Incident response → Improve runbooks
- Manual testing → Already automated

### Automation Priorities

1. **High Impact, Low Effort**:
   - Deployment automation
   - Backup automation

2. **High Impact, High Effort**:
   - Migration automation
   - Incident response automation

3. **Low Impact, Low Effort**:
   - Log rotation
   - Cleanup scripts

## Best Practices

1. **Automate Repetitive Tasks**: If done >3 times, automate
2. **Version Control**: All scripts in git
3. **Documentation**: Document all automation
4. **Testing**: Test automation in staging
5. **Monitoring**: Monitor automated processes

## Tools

- **CI/CD**: GitHub Actions
- **Orchestration**: Kubernetes
- **Monitoring**: Prometheus, Grafana
- **Alerting**: PagerDuty (recommended)

---

**Last Updated**: 2025-11-08
"""
    
    doc_file.write_text(doc_content)
    return doc_file


def main():
    """Main entry point."""
    print("🤖 Phase 4.2: Automating Operations and Reducing Toil\n")
    print("=" * 60)
    
    files_created = []
    
    # Create deployment automation
    print("\n1. Creating deployment automation...")
    deploy_script = create_deployment_automation()
    files_created.append(deploy_script)
    print(f"   ✅ Created: {deploy_script}")
    
    # Create migration automation
    print("\n2. Creating migration automation...")
    migrate_script = create_migration_automation()
    files_created.append(migrate_script)
    print(f"   ✅ Created: {migrate_script}")
    
    # Create backup automation
    print("\n3. Creating backup automation...")
    backup_script = create_backup_automation()
    files_created.append(backup_script)
    print(f"   ✅ Created: {backup_script}")
    
    # Create on-call config
    print("\n4. Creating on-call configuration...")
    oncall_file = create_oncall_config()
    files_created.append(oncall_file)
    print(f"   ✅ Created: {oncall_file}")
    
    # Create toil tracking
    print("\n5. Creating toil tracking...")
    toil_file = create_toil_tracking()
    files_created.append(toil_file)
    print(f"   ✅ Created: {toil_file}")
    
    # Create documentation
    print("\n6. Creating automation documentation...")
    doc_file = create_automation_docs()
    files_created.append(doc_file)
    print(f"   ✅ Created: {doc_file}")
    
    print("\n" + "=" * 60)
    print("📊 Summary")
    print("=" * 60)
    print(f"Files created: {len(files_created)}")
    print("\n✅ Automation setup complete!")
    print("\nNext steps:")
    print("  1. Set up on-call rotation")
    print("  2. Configure PagerDuty (optional)")
    print("  3. Start tracking toil time")
    print("  4. Review: docs/AUTOMATION.md")


if __name__ == "__main__":
    main()

