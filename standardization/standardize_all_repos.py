#!/usr/bin/env python3
"""
Standardize All FKS Repositories
Ensures all repos follow FKS standards: README, Docker, tests, schema, etc.
"""

import os
import json
import subprocess
from pathlib import Path
from typing import Dict, List, Any, Optional
from datetime import datetime
import yaml

# Base path
# Get repo/ directory (5 levels up from scripts/standardization/)
BASE_PATH = Path(__file__).parent.parent.parent.parent.parent  # repo/

# Standard FKS service structure
FKS_STANDARD_STRUCTURE = {
    "required_files": [
        "README.md",
        "Dockerfile",
        "requirements.txt",  # or Cargo.toml for Rust
        ".dockerignore"
    ],
    "optional_files": [
        "docker-compose.yml",
        "pytest.ini",
        "ruff.toml",
        ".env.example"
    ],
    "required_dirs": [
        "src/",
        "tests/"
    ]
}

# Standard README template
README_TEMPLATE = """# {service_name}

{description}

## 🚀 Quick Start

### Development

```bash
# Install dependencies
{pip_or_cargo} install

# Run service
{run_command}
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

{env_vars}

## 🧪 Testing

```bash
# Run tests
{test_command}
```

## 📚 Documentation

- [API Documentation](docs/API.md)
- [Deployment Guide](docs/DEPLOYMENT.md)

---

**Repository**: [nuniesmith/{repo_name}](https://github.com/nuniesmith/{repo_name})
"""


class RepoStandardizer:
    """Standardizes a single repository."""
    
    def __init__(self, repo_path: Path, repo_name: str, repo_type: str = "python"):
        self.repo_path = repo_path
        self.repo_name = repo_name
        self.repo_type = repo_type  # "python" or "rust"
        self.issues = []
        self.fixes_applied = []
    
    def standardize(self) -> Dict[str, Any]:
        """Run all standardization checks and fixes."""
        print(f"Standardizing {self.repo_name}...")
        
        if not self.repo_path.exists():
            return {
                "repo": self.repo_name,
                "exists": False,
                "error": "Repository not found"
            }
        
        # Run all checks
        self._check_readme()
        self._check_dockerfile()
        self._check_docker_compose()
        self._check_dockerignore()
        self._check_tests()
        self._check_health_endpoints()
        self._check_static_analysis()
        self._check_requirements()
        
        return {
            "repo": self.repo_name,
            "path": str(self.repo_path),
            "exists": True,
            "issues": self.issues,
            "fixes_applied": self.fixes_applied
        }
    
    def _check_readme(self):
        """Check and create/update README."""
        readme_path = self.repo_path / "README.md"
        
        if not readme_path.exists():
            self.issues.append({
                "file": "README.md",
                "issue": "Missing README.md",
                "priority": "high",
                "fix": "create"
            })
            # Create README
            self._create_readme()
            self.fixes_applied.append("Created README.md")
        else:
            # Check if README is substantial
            content = readme_path.read_text()
            if len(content) < 200:
                self.issues.append({
                    "file": "README.md",
                    "issue": "README.md is too short",
                    "priority": "medium",
                    "fix": "update"
                })
    
    def _create_readme(self):
        """Create standard README."""
        # Determine service details
        service_name = self.repo_name.replace("fks_", "").replace("_", "-")
        description = f"FKS {service_name.title()} Service"
        
        # Determine commands based on type
        if self.repo_type == "rust":
            pip_or_cargo = "cargo"
            run_command = "cargo run"
            test_command = "cargo test"
        else:
            pip_or_cargo = "pip install -r requirements.txt"
            run_command = "uvicorn src.main:app --reload --host 0.0.0.0 --port 8000"
            test_command = "pytest tests/ -v"
        
        # Get port from service name
        ports = {
            "api": 8001,
            "app": 8002,
            "data": 8003,
            "execution": 8006,
            "web": 8000,
            "ai": 8007,
            "analyze": 8008,
            "monitor": 8009
        }
        port = ports.get(service_name, 8000)
        
        env_vars = f"""```bash
SERVICE_NAME={self.repo_name}
SERVICE_PORT={port}
```"""
        
        readme_content = README_TEMPLATE.format(
            service_name=self.repo_name,
            description=description,
            pip_or_cargo=pip_or_cargo,
            run_command=run_command,
            test_command=test_command,
            env_vars=env_vars,
            repo_name=self.repo_name
        )
        
        readme_path = self.repo_path / "README.md"
        readme_path.write_text(readme_content)
    
    def _check_dockerfile(self):
        """Check Dockerfile."""
        dockerfile = self.repo_path / "Dockerfile"
        if not dockerfile.exists():
            self.issues.append({
                "file": "Dockerfile",
                "issue": "Missing Dockerfile",
                "priority": "high",
                "fix": "create"
            })
            # Create Dockerfile based on type
            self._create_dockerfile()
            self.fixes_applied.append("Created Dockerfile")
    
    def _create_dockerfile(self):
        """Create standard Dockerfile."""
        if self.repo_type == "rust":
            dockerfile_content = """# Multi-stage build for Rust service
FROM rust:1.75-slim as builder

WORKDIR /app

# Install build dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \\
    pkg-config \\
    libssl-dev \\
    ca-certificates \\
    && rm -rf /var/lib/apt/lists/*

# Copy Cargo files
COPY Cargo.toml Cargo.lock ./

# Copy source
COPY src/ ./src/

# Build release
RUN cargo build --release

# Runtime stage
FROM debian:bookworm-slim

WORKDIR /app

# Install runtime dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \\
    ca-certificates \\
    libssl3 \\
    && rm -rf /var/lib/apt/lists/*

# Copy binary from builder
COPY --from=builder /app/target/release/{binary_name} /app/{binary_name}

# Create non-root user
RUN useradd -u 1000 -m appuser && chown -R appuser /app
USER appuser

# Health check
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \\
    CMD curl -f http://localhost:{port}/health || exit 1

# Expose port
EXPOSE {port}

# Run service
CMD ["./{binary_name}"]
"""
        else:
            dockerfile_content = """FROM python:3.12-slim

# Environment variables
ENV PYTHONDONTWRITEBYTECODE=1 \\
    PYTHONUNBUFFERED=1 \\
    PIP_NO_CACHE_DIR=1 \\
    SERVICE_NAME={service_name} \\
    SERVICE_PORT={port} \\
    PYTHONPATH=/app/src:/app

WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \\
    curl \\
    && rm -rf /var/lib/apt/lists/*

# Copy dependency files
COPY requirements.txt ./

# Install Python dependencies
RUN python -m pip install --upgrade pip && \\
    python -m pip install -r requirements.txt

# Copy application source
COPY src/ ./src/
COPY entrypoint.sh ./

# Make entrypoint executable
RUN chmod +x entrypoint.sh

# Health check
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \\
    CMD python -c "import os,urllib.request,sys;port=os.getenv('SERVICE_PORT','{port}');u=f'http://localhost:{{port}}/health';\\
import urllib.error;\\
try: urllib.request.urlopen(u,timeout=3);\\
except Exception: sys.exit(1)" || exit 1

# Expose the service port
EXPOSE {port}

# Create non-root user
RUN useradd -u 1000 -m appuser && chown -R appuser /app
USER appuser

# Use entrypoint script
ENTRYPOINT ["./entrypoint.sh"]
"""
        
        # Get port
        ports = {
            "api": 8001, "app": 8002, "data": 8003, "execution": 8006,
            "web": 8000, "ai": 8007, "analyze": 8008, "monitor": 8009
        }
        service_short = self.repo_name.replace("fks_", "")
        port = ports.get(service_short, 8000)
        
        if self.repo_type == "rust":
            binary_name = self.repo_name.replace("_", "-")
            dockerfile_content = dockerfile_content.format(
                binary_name=binary_name,
                port=port
            )
        else:
            dockerfile_content = dockerfile_content.format(
                service_name=self.repo_name,
                port=port
            )
        
        dockerfile_path = self.repo_path / "Dockerfile"
        dockerfile_path.write_text(dockerfile_content)
    
    def _check_docker_compose(self):
        """Check docker-compose.yml."""
        compose = self.repo_path / "docker-compose.yml"
        if not compose.exists():
            self.issues.append({
                "file": "docker-compose.yml",
                "issue": "Missing docker-compose.yml",
                "priority": "medium",
                "fix": "create"
            })
            # Optionally create docker-compose.yml
            # self._create_docker_compose()
    
    def _check_dockerignore(self):
        """Check .dockerignore."""
        dockerignore = self.repo_path / ".dockerignore"
        if not dockerignore.exists():
            self.issues.append({
                "file": ".dockerignore",
                "issue": "Missing .dockerignore",
                "priority": "low",
                "fix": "create"
            })
            self._create_dockerignore()
            self.fixes_applied.append("Created .dockerignore")
    
    def _create_dockerignore(self):
        """Create standard .dockerignore."""
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
"""
        dockerignore_path = self.repo_path / ".dockerignore"
        dockerignore_path.write_text(dockerignore_content)
    
    def _check_tests(self):
        """Check for test files."""
        test_dirs = ["tests", "test", "__tests__"]
        test_files = list(self.repo_path.rglob("test_*.py")) + \
                     list(self.repo_path.rglob("*_test.py"))
        
        if not any((self.repo_path / d).exists() for d in test_dirs) and not test_files:
            self.issues.append({
                "file": "tests/",
                "issue": "No test files found",
                "priority": "high",
                "fix": "create"
            })
            # Create basic test structure
            self._create_test_structure()
            self.fixes_applied.append("Created test structure")
    
    def _create_test_structure(self):
        """Create basic test structure."""
        tests_dir = self.repo_path / "tests"
        tests_dir.mkdir(exist_ok=True)
        
        # Create __init__.py
        (tests_dir / "__init__.py").write_text("")
        
        # Create basic test file
        test_file = tests_dir / "test_health.py"
        test_content = """\"\"\"Basic health check tests.\"\"\"
import pytest
from fastapi.testclient import TestClient

from src.main import app

client = TestClient(app)


def test_health_endpoint():
    \"\"\"Test health endpoint.\"\"\"
    response = client.get("/health")
    assert response.status_code == 200
    assert response.json()["status"] == "healthy"


def test_ready_endpoint():
    \"\"\"Test readiness endpoint.\"\"\"
    response = client.get("/ready")
    assert response.status_code == 200


def test_live_endpoint():
    \"\"\"Test liveness endpoint.\"\"\"
    response = client.get("/live")
    assert response.status_code == 200
"""
        test_file.write_text(test_content)
    
    def _check_health_endpoints(self):
        """Check for health endpoints in code."""
        # This is already checked by phase1_health_check.py
        pass
    
    def _check_static_analysis(self):
        """Check for static analysis config."""
        if self.repo_type == "python":
            ruff_config = self.repo_path / "ruff.toml"
            if not ruff_config.exists():
                self.issues.append({
                    "file": "ruff.toml",
                    "issue": "Missing ruff.toml",
                    "priority": "medium",
                    "fix": "create"
                })
                self._create_ruff_config()
                self.fixes_applied.append("Created ruff.toml")
    
    def _create_ruff_config(self):
        """Create standard ruff.toml."""
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
        ruff_path = self.repo_path / "ruff.toml"
        ruff_path.write_text(ruff_content)
    
    def _check_requirements(self):
        """Check requirements.txt or Cargo.toml."""
        if self.repo_type == "python":
            requirements = self.repo_path / "requirements.txt"
            if not requirements.exists():
                self.issues.append({
                    "file": "requirements.txt",
                    "issue": "Missing requirements.txt",
                    "priority": "high",
                    "fix": "create"
                })
                # Create basic requirements.txt
                self._create_requirements()
                self.fixes_applied.append("Created requirements.txt")
    
    def _create_requirements(self):
        """Create basic requirements.txt."""
        requirements_content = """# FKS {service_name} Service Dependencies

# FastAPI and web server
fastapi>=0.104.0
uvicorn[standard]>=0.24.0
pydantic>=2.5.0
pydantic-settings>=2.1.0

# HTTP client
httpx>=0.25.0

# Testing
pytest>=7.4.0
pytest-asyncio>=0.21.0
pytest-cov>=4.1.0

# Code quality
ruff>=0.1.0
mypy>=1.7.0
""".format(service_name=self.repo_name)
        
        requirements_path = self.repo_path / "requirements.txt"
        requirements_path.write_text(requirements_content)


def standardize_all_repos() -> Dict[str, Any]:
    """Standardize all FKS repositories."""
    results = {
        "timestamp": datetime.utcnow().isoformat(),
        "repos": {},
        "summary": {
            "total_repos": 0,
            "repos_standardized": 0,
            "total_issues": 0,
            "total_fixes": 0
        }
    }
    
    # Repo configurations
    repos_to_check = [
        ("core/api", "fks_api", "python"),
        ("core/app", "fks_app", "python"),
        ("core/data", "fks_data", "python"),
        ("core/execution", "fks_execution", "rust"),
        ("core/web", "fks_web", "python"),
        ("core/main", "fks_main", "rust"),
        ("gpu/ai", "fks_ai", "python"),
        ("gpu/training", "fks_training", "python"),
        ("tools/analyze", "fks_analyze", "python"),
        ("tools/monitor", "fks_monitor", "python"),
    ]
    
    for repo_path_str, repo_name, repo_type in repos_to_check:
        repo_path = BASE_PATH / repo_path_str
        standardizer = RepoStandardizer(repo_path, repo_name, repo_type)
        result = standardizer.standardize()
        
        results["repos"][repo_name] = result
        results["summary"]["total_repos"] += 1
        
        if result.get("exists"):
            results["summary"]["repos_standardized"] += 1
            results["summary"]["total_issues"] += len(result.get("issues", []))
            results["summary"]["total_fixes"] += len(result.get("fixes_applied", []))
    
    return results


def generate_report(results: Dict[str, Any], output_file: str = "standardization_report.json"):
    """Generate standardization report."""
    output_path = Path(output_file)
    
    # Save JSON
    with open(output_path, "w") as f:
        json.dump(results, f, indent=2)
    
    # Generate markdown report
    md_path = output_path.with_suffix(".md")
    with open(md_path, "w") as f:
        f.write("# FKS Repository Standardization Report\n\n")
        f.write(f"**Generated**: {results['timestamp']}\n\n")
        
        # Summary
        f.write("## Summary\n\n")
        summary = results["summary"]
        f.write(f"- **Total Repos**: {summary['total_repos']}\n")
        f.write(f"- **Repos Standardized**: {summary['repos_standardized']}\n")
        f.write(f"- **Total Issues Found**: {summary['total_issues']}\n")
        f.write(f"- **Fixes Applied**: {summary['total_fixes']}\n\n")
        
        # Detailed findings
        f.write("## Detailed Findings\n\n")
        for repo_name, repo_data in results["repos"].items():
            if not repo_data.get("exists"):
                continue
            
            f.write(f"### {repo_name}\n\n")
            f.write(f"**Path**: {repo_data['path']}\n\n")
            
            # Fixes applied
            fixes = repo_data.get("fixes_applied", [])
            if fixes:
                f.write("**Fixes Applied**:\n")
                for fix in fixes:
                    f.write(f"- ✅ {fix}\n")
                f.write("\n")
            
            # Remaining issues
            issues = repo_data.get("issues", [])
            if issues:
                f.write("**Remaining Issues**:\n")
                for issue in issues:
                    priority_emoji = "🔴" if issue["priority"] == "high" else "🟡" if issue["priority"] == "medium" else "🟢"
                    f.write(f"- {priority_emoji} **{issue['priority']}**: {issue['issue']} ({issue['file']})\n")
                f.write("\n")
            
            f.write("---\n\n")
    
    print(f"\n✅ Standardization complete!")
    print(f"📄 JSON report: {output_path}")
    print(f"📄 Markdown report: {md_path}")


def main():
    """Main entry point."""
    print("🔧 Standardizing All FKS Repositories\n")
    print("=" * 60)
    
    results = standardize_all_repos()
    generate_report(results)
    
    # Print summary
    print("\n" + "=" * 60)
    print("📊 Standardization Summary")
    print("=" * 60)
    summary = results["summary"]
    print(f"Total Repos: {summary['total_repos']}")
    print(f"Repos Standardized: {summary['repos_standardized']}")
    print(f"Total Issues Found: {summary['total_issues']}")
    print(f"Fixes Applied: {summary['total_fixes']}")


if __name__ == "__main__":
    main()

