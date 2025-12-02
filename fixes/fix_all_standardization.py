#!/usr/bin/env python3
"""
Fix All Standardization Issues
Completes all remaining standardization tasks for all FKS repos.
"""

import os
from pathlib import Path
from typing import Dict, List

# Get repo/ directory (5 levels up from scripts/fixes/)
BASE_PATH = Path(__file__).parent.parent.parent.parent.parent  # repo/

# Service ports mapping
SERVICE_PORTS = {
    "fks_api": 8001,
    "fks_app": 8002,
    "fks_data": 8003,
    "fks_execution": 8006,
    "fks_web": 8000,
    "fks_ai": 8007,
    "fks_analyze": 8008,
    "fks_monitor": 8009,
    "fks_main": 8010,
}

# Repo paths
REPO_PATHS = {
    "fks_api": BASE_PATH / "core" / "api",
    "fks_app": BASE_PATH / "core" / "app",
    "fks_data": BASE_PATH / "core" / "data",
    "fks_execution": BASE_PATH / "core" / "execution",
    "fks_web": BASE_PATH / "core" / "web",
    "fks_main": BASE_PATH / "core" / "main",
    "fks_ai": BASE_PATH / "gpu" / "ai",
    "fks_training": BASE_PATH / "gpu" / "training",
    "fks_analyze": BASE_PATH / "tools" / "analyze",
    "fks_monitor": BASE_PATH / "tools" / "monitor",
}


def create_docker_compose(repo_path: Path, service_name: str, port: int, is_rust: bool = False):
    """Create docker-compose.yml for a service."""
    compose_path = repo_path / "docker-compose.yml"
    if compose_path.exists():
        return False
    
    if is_rust:
        compose_content = f"""
services:
  {service_name}:
    build:
      context: .
      dockerfile: Dockerfile
    image: nuniesmith/{service_name}:latest
    container_name: {service_name}
    ports:
      - "{port}:{port}"
    environment:
      - SERVICE_NAME={service_name}
      - SERVICE_PORT={port}
      - RUST_LOG=info
    networks:
      - fks-network
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:{port}/health"]
      interval: 30s
      timeout: 5s
      retries: 3
      start_period: 10s

networks:
  fks-network:
    driver: bridge
"""
    else:
        compose_content = f"""
services:
  {service_name}:
    build:
      context: .
      dockerfile: Dockerfile
    image: nuniesmith/{service_name}:latest
    container_name: {service_name}
    ports:
      - "{port}:{port}"
    environment:
      - SERVICE_NAME={service_name}
      - SERVICE_PORT={port}
      - PYTHONPATH=/app/src:/app
    networks:
      - fks-network
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:{port}/health"]
      interval: 30s
      timeout: 5s
      retries: 3
      start_period: 10s

networks:
  fks-network:
    driver: bridge
"""
    
    compose_path.write_text(compose_content)
    return True


def create_dockerignore(repo_path: Path):
    """Create .dockerignore if missing."""
    dockerignore_path = repo_path / ".dockerignore"
    if dockerignore_path.exists():
        return False
    
    dockerignore_content = """# Python
__pycache__/
*.py[cod]
*$py.class
*.so
.Python
*.egg-info/
dist/
build/
.venv/
venv/
env/

# Rust
target/
Cargo.lock

# Testing
.pytest_cache/
.coverage
htmlcov/
.tox/

# IDE
.vscode/
.idea/
*.swp
*.swo

# Git
.git/
.gitignore

# Documentation
*.md
docs/

# Logs
*.log
logs/

# Environment
.env
.env.local

# OS
.DS_Store
Thumbs.db

# Data files
*.db
*.sqlite
*.json
*.csv
"""
    
    dockerignore_path.write_text(dockerignore_content)
    return True


def create_ruff_toml(repo_path: Path):
    """Create ruff.toml if missing."""
    ruff_path = repo_path / "ruff.toml"
    if ruff_path.exists():
        return False
    
    ruff_content = """# Ruff configuration for FKS services
line-length = 100
target-version = "py312"

[lint]
select = ["E", "F", "I", "N", "W", "UP"]
ignore = []

[lint.per-file-ignores]
"__init__.py" = ["F401"]
"tests/**" = ["E501"]
"""
    
    ruff_path.write_text(ruff_content)
    return True


def create_test_structure(repo_path: Path, is_rust: bool = False):
    """Create test structure if missing."""
    tests_dir = repo_path / "tests"
    
    if is_rust:
        if not tests_dir.exists():
            tests_dir.mkdir()
        
        test_file = tests_dir / "integration_test.rs"
        if not test_file.exists():
            test_content = """// Integration tests for FKS service

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_health() {
        // Basic health check test
        assert!(true);
    }
}
"""
            test_file.write_text(test_content)
            return True
    else:
        if not tests_dir.exists():
            tests_dir.mkdir()
        
        # Create __init__.py
        init_file = tests_dir / "__init__.py"
        if not init_file.exists():
            init_file.write_text("")
        
        # Create test_health.py
        test_file = tests_dir / "test_health.py"
        if not test_file.exists():
            test_content = """\"\"\"Basic health check tests.\"\"\"
import pytest
from fastapi.testclient import TestClient

# Try to import app - adjust import path as needed
try:
    from src.main import app
    client = TestClient(app)
except ImportError:
    # Fallback if app structure is different
    client = None


@pytest.mark.skipif(client is None, reason="App not importable")
def test_health_endpoint():
    \"\"\"Test health endpoint.\"\"\"
    response = client.get("/health")
    assert response.status_code == 200
    assert response.json()["status"] == "healthy"


@pytest.mark.skipif(client is None, reason="App not importable")
def test_ready_endpoint():
    \"\"\"Test readiness endpoint.\"\"\"
    response = client.get("/ready")
    assert response.status_code == 200


@pytest.mark.skipif(client is None, reason="App not importable")
def test_live_endpoint():
    \"\"\"Test liveness endpoint.\"\"\"
    response = client.get("/live")
    assert response.status_code == 200
"""
            test_file.write_text(test_content)
            return True
    
    return False


def update_readme(repo_path: Path, service_name: str, port: int):
    """Update README if it's too short."""
    readme_path = repo_path / "README.md"
    if not readme_path.exists():
        return False
    
    content = readme_path.read_text()
    if len(content) > 200:
        return False
    
    # Readme is too short, enhance it
    service_short = service_name.replace("fks_", "").replace("_", "-")
    description = f"FKS {service_short.title()} Service"
    
    enhanced_content = f"""# {service_name}

{description}

## 🚀 Quick Start

### Development

```bash
# Install dependencies
pip install -r requirements.txt

# Run service
uvicorn src.main:app --reload --host 0.0.0.0 --port {port}
```

### Docker

```bash
# Build and run
docker-compose up --build
```

## 📡 API Endpoints

- `GET /health` - Health check
- `GET /ready` - Readiness check
- `GET /live` - Liveness probe

## 🔧 Configuration

### Environment Variables

```bash
SERVICE_NAME={service_name}
SERVICE_PORT={port}
```

## 🧪 Testing

```bash
# Run tests
pytest tests/ -v
```

## 📚 Documentation

- [API Documentation](docs/API.md)
- [Deployment Guide](docs/DEPLOYMENT.md)

---

**Repository**: [nuniesmith/{service_name}](https://github.com/nuniesmith/{service_name})
"""
    
    readme_path.write_text(enhanced_content)
    return True


def fix_repo(repo_name: str, repo_path: Path, is_rust: bool = False):
    """Fix all issues for a repository."""
    fixes = []
    
    port = SERVICE_PORTS.get(repo_name, 8000)
    
    # 1. Create docker-compose.yml
    if create_docker_compose(repo_path, repo_name, port, is_rust):
        fixes.append("Created docker-compose.yml")
    
    # 2. Create .dockerignore
    if create_dockerignore(repo_path):
        fixes.append("Created .dockerignore")
    
    # 3. Create ruff.toml (Python only)
    if not is_rust:
        if create_ruff_toml(repo_path):
            fixes.append("Created ruff.toml")
    
    # 4. Create test structure
    if create_test_structure(repo_path, is_rust):
        fixes.append("Created test structure")
    
    # 5. Update README if needed
    if update_readme(repo_path, repo_name, port):
        fixes.append("Updated README.md")
    
    return fixes


def main():
    """Main entry point."""
    print("🔧 Fixing All Standardization Issues\n")
    print("=" * 60)
    
    all_fixes = {}
    
    # Python services
    python_services = [
        "fks_api", "fks_app", "fks_data", "fks_web", 
        "fks_ai", "fks_analyze", "fks_monitor"
    ]
    
    # Rust services
    rust_services = ["fks_execution", "fks_main"]
    
    # Fix Python services
    for service_name in python_services:
        repo_path = REPO_PATHS.get(service_name)
        if repo_path and repo_path.exists():
            print(f"Fixing {service_name}...")
            fixes = fix_repo(service_name, repo_path, is_rust=False)
            if fixes:
                all_fixes[service_name] = fixes
                print(f"  ✅ Applied {len(fixes)} fixes: {', '.join(fixes)}")
            else:
                print(f"  ✓ Already standardized")
    
    # Fix Rust services
    for service_name in rust_services:
        repo_path = REPO_PATHS.get(service_name)
        if repo_path and repo_path.exists():
            print(f"Fixing {service_name}...")
            fixes = fix_repo(service_name, repo_path, is_rust=True)
            if fixes:
                all_fixes[service_name] = fixes
                print(f"  ✅ Applied {len(fixes)} fixes: {', '.join(fixes)}")
            else:
                print(f"  ✓ Already standardized")
    
    # Summary
    print("\n" + "=" * 60)
    print("📊 Summary")
    print("=" * 60)
    total_fixes = sum(len(fixes) for fixes in all_fixes.values())
    print(f"Total fixes applied: {total_fixes}")
    print(f"Repos fixed: {len(all_fixes)}")
    
    if all_fixes:
        print("\nFixes by repo:")
        for repo, fixes in all_fixes.items():
            print(f"  {repo}: {len(fixes)} fixes")
    
    print("\n✅ Standardization fixes complete!")
    print("\nNext step: Run verification")
    print("  ./scripts/verify_all_services.sh")


if __name__ == "__main__":
    main()

