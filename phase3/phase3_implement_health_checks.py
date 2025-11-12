#!/usr/bin/env python3
"""
Phase 3.1: Implement Health Checks and Pinging
Adds standardized health check endpoints to all FKS services.
"""

import os
import json
from pathlib import Path
from typing import Dict, List, Any
from datetime import datetime

# Get repo/ directory (5 levels up from scripts/phase3/)
BASE_PATH = Path(__file__).parent.parent.parent.parent.parent  # repo/

# Service configurations
SERVICES = {
    "fks_api": {
        "path": BASE_PATH / "core" / "api",
        "type": "python",
        "port": 8001,
        "framework": "fastapi"
    },
    "fks_app": {
        "path": BASE_PATH / "core" / "app",
        "type": "python",
        "port": 8002,
        "framework": "fastapi"
    },
    "fks_data": {
        "path": BASE_PATH / "core" / "data",
        "type": "python",
        "port": 8003,
        "framework": "fastapi"
    },
    "fks_web": {
        "path": BASE_PATH / "core" / "web",
        "type": "python",
        "port": 8000,
        "framework": "fastapi"
    },
    "fks_ai": {
        "path": BASE_PATH / "gpu" / "ai",
        "type": "python",
        "port": 8007,
        "framework": "fastapi"
    },
    "fks_analyze": {
        "path": BASE_PATH / "tools" / "analyze",
        "type": "python",
        "port": 8008,
        "framework": "fastapi"
    },
    "fks_monitor": {
        "path": BASE_PATH / "tools" / "monitor",
        "type": "python",
        "port": 8009,
        "framework": "fastapi"
    },
    "fks_execution": {
        "path": BASE_PATH / "core" / "execution",
        "type": "rust",
        "port": 8006,
        "framework": "axum"
    },
    "fks_main": {
        "path": BASE_PATH / "core" / "main",
        "type": "rust",
        "port": 8010,
        "framework": "axum"
    }
}


def create_python_health_module(service_path: Path, service_name: str):
    """Create health check module for Python/FastAPI services."""
    health_module = service_path / "src" / "api" / "routes" / "health.py"
    
    # Create directory if needed
    health_module.parent.mkdir(parents=True, exist_ok=True)
    
    if health_module.exists():
        # Check if it already has the standard endpoints
        content = health_module.read_text()
        if "/health" in content and "/ready" in content and "/live" in content:
            return False
    
    health_template = '''"""
Standardized health check endpoints for FKS services.
Implements liveness, readiness, and health probes.
"""

from fastapi import APIRouter, HTTPException, Depends
from typing import Dict, Any, Optional
from datetime import datetime
import logging

logger = logging.getLogger(__name__)

router = APIRouter()


@router.get("/health")
async def health_check() -> Dict[str, Any]:
    """
    Health check endpoint - liveness probe.
    Returns basic service health status.
    """
    return {{
        "status": "healthy",
        "service": "{service_name}",
        "timestamp": datetime.utcnow().isoformat(),
        "version": "1.0.0"
    }}


@router.get("/ready")
async def readiness_check() -> Dict[str, Any]:
    """
    Readiness check endpoint.
    Verifies service is ready to accept traffic.
    Checks critical dependencies.
    """
    # TODO: Add dependency checks (database, external services, etc.)
    dependencies_ready = True
    dependency_status = {{}}
    
    # Example: Check database connection
    # try:
    #     await check_database()
    #     dependency_status["database"] = "ready"
    # except Exception as e:
    #     dependencies_ready = False
    #     dependency_status["database"] = f"error: {{str(e)}}"
    
    if not dependencies_ready:
        raise HTTPException(status_code=503, detail="Service not ready")
    
    return {{
        "status": "ready",
        "service": "{service_name}",
        "timestamp": datetime.utcnow().isoformat(),
        "dependencies": dependency_status
    }}


@router.get("/live")
async def liveness_check() -> Dict[str, Any]:
    """
    Liveness probe endpoint.
    Simple check to verify process is alive.
    """
    return {{
        "status": "alive",
        "service": "{service_name}",
        "timestamp": datetime.utcnow().isoformat()
    }}
'''
    health_content = health_template.format(service_name=service_name)
    
    health_module.write_text(health_content)
    return True


def create_rust_health_module(service_path: Path, service_name: str):
    """Create health check routes for Rust/Axum services."""
    # For Rust, we'll add routes to main.rs or create a health module
    main_rs = service_path / "src" / "main.rs"
    
    if not main_rs.exists():
        return False
    
    content = main_rs.read_text()
    
    # Check if health routes already exist
    if "/health" in content and "/ready" in content:
        return False
    
    # Create health module
    health_module = service_path / "src" / "health.rs"
    health_template = '''/// Health check endpoints for FKS services
use axum::{{response::Json, routing::get, Router}};
use serde_json::{{json, Value}};
use std::time::{{SystemTime, UNIX_EPOCH}};

pub fn health_routes() -> Router {{
    Router::new()
        .route("/health", get(health_check))
        .route("/ready", get(readiness_check))
        .route("/live", get(liveness_check))
}}

async fn health_check() -> Json<Value> {{
    Json(json!({{
        "status": "healthy",
        "service": "{service_name}",
        "timestamp": SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .unwrap()
            .as_secs()
    }}))
}}

async fn readiness_check() -> Json<Value> {{
    // TODO: Add dependency checks
    Json(json!({{
        "status": "ready",
        "service": "{service_name}",
        "timestamp": SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .unwrap()
            .as_secs(),
        "dependencies": {{}}
    }}))
}}

async fn liveness_check() -> Json<Value> {{
    Json(json!({{
        "status": "alive",
        "service": "{service_name}",
        "timestamp": SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .unwrap()
            .as_secs()
    }}))
}}
'''
    health_content = health_template.format(service_name=service_name)
    
    health_module.write_text(health_content)
    
    # Update main.rs to include health module
    if "mod health;" not in content:
        # Find a good place to add the mod declaration
        lines = content.split('\n')
        insert_idx = 0
        for i, line in enumerate(lines):
            if line.startswith("mod ") or line.startswith("use "):
                insert_idx = i + 1
        
        lines.insert(insert_idx, "mod health;")
        content = '\n'.join(lines)
    
    # Update router to include health routes
    if "health_routes()" not in content:
        # Find router definition and add health routes
        if "Router::new()" in content:
            content = content.replace(
                "Router::new()",
                "Router::new().merge(health::health_routes())"
            )
    
    main_rs.write_text(content)
    return True


def update_dockerfile_healthcheck(service_path: Path, port: int):
    """Update Dockerfile with health check."""
    dockerfile = service_path / "Dockerfile"
    if not dockerfile.exists():
        return False
    
    content = dockerfile.read_text()
    
    # Check if healthcheck already exists
    if "HEALTHCHECK" in content:
        return False
    
    # Add healthcheck before CMD/ENTRYPOINT
    healthcheck = f'''
# Health check
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \\
    CMD curl -f http://localhost:{port}/health || exit 1
'''
    
    # Insert before CMD or ENTRYPOINT
    if "CMD [" in content:
        content = content.replace("CMD [", healthcheck + "\nCMD [")
    elif "ENTRYPOINT [" in content:
        content = content.replace("ENTRYPOINT [", healthcheck + "\nENTRYPOINT [")
    else:
        # Append at end
        content += healthcheck
    
    dockerfile.write_text(content)
    return True


def create_health_check_config(service_path: Path, service_name: str, port: int):
    """Create Kubernetes health check configuration."""
    k8s_dir = service_path / "k8s"
    k8s_dir.mkdir(exist_ok=True)
    
    health_config = k8s_dir / "health-checks.yaml"
    
    config_content = f'''# Health check configuration for {service_name}
# Use this in your Deployment spec

apiVersion: v1
kind: ConfigMap
metadata:
  name: {service_name}-health-config
  namespace: fks-trading
data:
  liveness_probe: |
    httpGet:
      path: /health
      port: {port}
    initialDelaySeconds: 10
    periodSeconds: 30
    timeoutSeconds: 5
    failureThreshold: 3
  
  readiness_probe: |
    httpGet:
      path: /ready
      port: {port}
    initialDelaySeconds: 5
    periodSeconds: 10
    timeoutSeconds: 3
    failureThreshold: 3

---
# Example Deployment with health checks
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {service_name}
  namespace: fks-trading
spec:
  replicas: 2
  selector:
    matchLabels:
      app: {service_name}
  template:
    metadata:
      labels:
        app: {service_name}
    spec:
      containers:
      - name: {service_name}
        image: nuniesmith/{service_name}:latest
        ports:
        - containerPort: {port}
        livenessProbe:
          httpGet:
            path: /health
            port: {port}
          initialDelaySeconds: 10
          periodSeconds: 30
          timeoutSeconds: 5
          failureThreshold: 3
        readinessProbe:
          httpGet:
            path: /ready
            port: {port}
          initialDelaySeconds: 5
          periodSeconds: 10
          timeoutSeconds: 3
          failureThreshold: 3
'''
    
    health_config.write_text(config_content)
    return True


def main():
    """Main entry point."""
    print("🏥 Phase 3.1: Implementing Health Checks and Pinging\n")
    print("=" * 60)
    
    results = {
        "timestamp": datetime.utcnow().isoformat(),
        "services": {},
        "summary": {
            "total": 0,
            "health_modules_created": 0,
            "dockerfiles_updated": 0,
            "k8s_configs_created": 0
        }
    }
    
    for service_name, config in SERVICES.items():
        service_path = config["path"]
        service_type = config["type"]
        port = config["port"]
        
        if not service_path.exists():
            print(f"⚠️  {service_name}: Repository not found")
            continue
        
        print(f"\n📦 {service_name} ({service_type})...")
        service_results = {
            "health_module": False,
            "dockerfile": False,
            "k8s_config": False
        }
        
        # Create health check module
        if service_type == "python":
            if create_python_health_module(service_path, service_name):
                service_results["health_module"] = True
                results["summary"]["health_modules_created"] += 1
                print(f"  ✅ Created health check module")
            else:
                print(f"  ✓ Health module already exists or updated")
        elif service_type == "rust":
            if create_rust_health_module(service_path, service_name):
                service_results["health_module"] = True
                results["summary"]["health_modules_created"] += 1
                print(f"  ✅ Created health check routes")
            else:
                print(f"  ✓ Health routes already exist")
        
        # Update Dockerfile
        if update_dockerfile_healthcheck(service_path, port):
            service_results["dockerfile"] = True
            results["summary"]["dockerfiles_updated"] += 1
            print(f"  ✅ Updated Dockerfile with healthcheck")
        else:
            print(f"  ✓ Dockerfile already has healthcheck")
        
        # Create K8s config
        if create_health_check_config(service_path, service_name, port):
            service_results["k8s_config"] = True
            results["summary"]["k8s_configs_created"] += 1
            print(f"  ✅ Created K8s health check config")
        
        results["services"][service_name] = service_results
        results["summary"]["total"] += 1
    
    # Save results
    results_file = Path("phase3_health_checks_results.json")
    results_file.write_text(json.dumps(results, indent=2))
    
    print("\n" + "=" * 60)
    print("📊 Summary")
    print("=" * 60)
    print(f"Services processed: {results['summary']['total']}")
    print(f"Health modules created: {results['summary']['health_modules_created']}")
    print(f"Dockerfiles updated: {results['summary']['dockerfiles_updated']}")
    print(f"K8s configs created: {results['summary']['k8s_configs_created']}")
    print("\n✅ Health checks implementation complete!")
    print("\nNext steps:")
    print("  1. Update main.py/main.rs to include health routes")
    print("  2. Test health endpoints: curl http://localhost:PORT/health")
    print("  3. Verify Docker healthchecks work")


if __name__ == "__main__":
    main()

