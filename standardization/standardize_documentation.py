#!/usr/bin/env python3
"""
Standardize all FKS service documentation to follow the documentation schema.
Updates README.md files to ensure consistency across all services.
"""

import json
import re
from pathlib import Path
from typing import Dict, List, Optional, Tuple
from datetime import datetime

# Get paths
SCRIPT_DIR = Path(__file__).parent
PROJECT_ROOT = SCRIPT_DIR.parent.parent.parent
REPO_ROOT = PROJECT_ROOT.parent  # repo/

# Service metadata
SERVICES = {
    "main": {
        "name": "FKS Main",
        "port": 8010,
        "framework": "Rust + Axum",
        "role": "Kubernetes orchestration and centralized control of all FKS services",
        "description": "Rust-based API service for Kubernetes orchestration and centralized control of all FKS services.",
        "repo_name": "fks_main",
        "docker_image": "nuniesmith/fks:main-latest"
    },
    "api": {
        "name": "FKS API",
        "port": 8001,
        "framework": "Python 3.12 + FastAPI",
        "role": "API Gateway - HTTP/WebSocket endpoints, routing, authentication",
        "description": "Lightweight FastAPI service providing HTTP/WebSocket endpoints for the FKS platform.",
        "repo_name": "fks_api",
        "docker_image": "nuniesmith/fks:api-latest"
    },
    "app": {
        "name": "FKS App",
        "port": 8002,
        "framework": "Python 3.13 + FastAPI",
        "role": "Core trading intelligence - strategies, signals, backtesting, portfolio optimization",
        "description": "Business logic service for trading strategies, signals, and portfolio management.",
        "repo_name": "fks_app",
        "docker_image": "nuniesmith/fks:app-latest"
    },
    "data": {
        "name": "FKS Data",
        "port": 8003,
        "framework": "Python 3.12 + FastAPI",
        "role": "Market data ingestion, validation, storage, and serving",
        "description": "Ingests, validates, stores, and serves market data & derived datasets.",
        "repo_name": "fks_data",
        "docker_image": "nuniesmith/fks:data-latest"
    },
    "execution": {
        "name": "FKS Execution",
        "port": 8004,
        "framework": "Rust + Actix-web/Axum",
        "role": "High-performance order execution - ONLY service that communicates with exchanges/brokers",
        "description": "Rust-based execution engine for high-performance order execution.",
        "repo_name": "fks_execution",
        "docker_image": "nuniesmith/fks:execution-latest"
    },
    "meta": {
        "name": "FKS Meta",
        "port": 8005,
        "framework": "Rust + Actix-web/Axum",
        "role": "MetaTrader 5 execution plugin for fks_execution",
        "description": "MetaTrader 5 integration plugin for execution service.",
        "repo_name": "fks_meta",
        "docker_image": "nuniesmith/fks:meta-latest"
    },
    "monitor": {
        "name": "FKS Monitor",
        "port": 8006,
        "framework": "Python 3.12 + FastAPI",
        "role": "Centralized monitoring - aggregates health checks, metrics, and test results",
        "description": "Centralized monitoring service that aggregates health checks, metrics, and test results from all FKS services.",
        "repo_name": "fks_monitor",
        "docker_image": "nuniesmith/fks:monitor-latest"
    },
    "ai": {
        "name": "FKS AI",
        "port": 8007,
        "framework": "Python 3.13 + FastAPI + PyTorch + CUDA",
        "role": "GPU-accelerated machine learning, regime detection, local LLM inference, RAG system",
        "description": "GPU-accelerated machine learning service with RAG system integration.",
        "repo_name": "fks_ai",
        "docker_image": "nuniesmith/fks:ai-latest"
    },
    "analyze": {
        "name": "FKS Analyze",
        "port": 8008,
        "framework": "Python 3.12 + FastAPI",
        "role": "Repository analysis, code quality, RAG system for project management",
        "description": "Repository analysis and code quality service with RAG system integration.",
        "repo_name": "fks_analyze",
        "docker_image": "nuniesmith/fks:analyze-latest"
    },
    "web": {
        "name": "FKS Web",
        "port": 8000,
        "framework": "Python 3.12 + Django + Gunicorn",
        "role": "Web dashboard and user interface",
        "description": "Django-based web dashboard and user interface for the FKS platform.",
        "repo_name": "fks_web",
        "docker_image": "nuniesmith/fks:web-latest"
    },
    "auth": {
        "name": "FKS Auth",
        "port": 8009,
        "framework": "Rust + Axum",
        "role": "Authentication and authorization service",
        "description": "Lightweight Axum-based authentication service.",
        "repo_name": "fks_auth",
        "docker_image": "nuniesmith/fks:auth-latest"
    },
    "training": {
        "name": "FKS Training",
        "port": 8011,
        "framework": "Python 3.12 + FastAPI",
        "role": "Model training pipelines and GPU resource allocation",
        "description": "Orchestrates model training pipelines and GPU resource allocation.",
        "repo_name": "fks_training",
        "docker_image": "nuniesmith/fks:training-latest"
    },
    "ninja": {
        "name": "FKS Ninja",
        "port": 8012,
        "framework": "C# .NET + NinjaTrader 8",
        "role": "NinjaTrader 8 bridge for prop firm execution",
        "description": "NinjaTrader 8 integration bridge for proprietary trading firm execution.",
        "repo_name": "fks_ninja",
        "docker_image": "nuniesmith/fks:ninja-latest"
    }
}

# Required sections in order
REQUIRED_SECTIONS = [
    ("header", r"^#\s+.*"),
    ("purpose", r"##\s+🎯\s+Purpose"),
    ("architecture", r"##\s+🏗️\s+Architecture"),
    ("quick_start", r"##\s+🚀\s+Quick Start"),
    ("api_endpoints", r"##\s+📡\s+API Endpoints"),
    ("configuration", r"##\s+🔧\s+Configuration"),
    ("testing", r"##\s+🧪\s+Testing"),
    ("docker", r"##\s+🐳\s+Docker"),
    ("kubernetes", r"##\s+☸️\s+Kubernetes"),
    ("documentation", r"##\s+📚\s+Documentation"),
    ("integration", r"##\s+🔗\s+Integration"),
    ("monitoring", r"##\s+📊\s+Monitoring"),
    ("development", r"##\s+🛠️\s+Development"),
    ("footer", r"^---")
]


def read_existing_readme(service_path: Path) -> Optional[str]:
    """Read existing README.md if it exists."""
    readme_path = service_path / "README.md"
    if readme_path.exists():
        return readme_path.read_text()
    return None


def extract_sections(content: str) -> Dict[str, str]:
    """Extract sections from existing README."""
    sections = {}
    lines = content.split('\n')
    current_section = None
    current_content = []
    
    for line in lines:
        # Check for section headers
        if line.startswith('##'):
            if current_section:
                sections[current_section] = '\n'.join(current_content).strip()
            # Try to match section
            current_section = None
            for name, pattern in REQUIRED_SECTIONS:
                if re.match(pattern, line, re.IGNORECASE):
                    current_section = name
                    break
            if not current_section:
                # Generic section
                current_section = line.strip()
            current_content = [line]
        else:
            if current_section:
                current_content.append(line)
    
    if current_section:
        sections[current_section] = '\n'.join(current_content).strip()
    
    return sections


def generate_readme_template(service_name: str, service_info: Dict) -> str:
    """Generate standardized README template."""
    template = f"""# {service_info['name']}

{service_info['description']}

**Port**: {service_info['port']}  
**Framework**: {service_info['framework']}  
**Role**: {service_info['role']}

## 🎯 Purpose

{service_info['description']}

## 🏗️ Architecture

[Describe how this service fits into the FKS architecture]

## 🚀 Quick Start

### Development

```bash
# Install dependencies
{"pip install -r requirements.txt" if "Python" in service_info['framework'] else "cargo build"}

# Run service
{"uvicorn src.main:app --reload --host 0.0.0.0 --port " + str(service_info['port']) if "Python" in service_info['framework'] else "cargo run"}
```

### Docker

```bash
# Build and run
docker-compose up --build
```

### Kubernetes

```bash
# Deploy to Kubernetes
kubectl apply -f k8s/
```

## 📡 API Endpoints

### Health Checks

- `GET /health` - Health check
- `GET /ready` - Readiness check
- `GET /live` - Liveness probe

### Service-Specific Endpoints

[Document service-specific endpoints here]

## 🔧 Configuration

### Environment Variables

```bash
SERVICE_NAME={service_info['repo_name']}
SERVICE_PORT={service_info['port']}
```

[Add other environment variables]

## 🧪 Testing

```bash
# Run tests
{"pytest tests/ -v" if "Python" in service_info['framework'] else "cargo test"}
```

## 🐳 Docker

### Build

```bash
docker build -t {service_info['docker_image']} .
```

### Run

```bash
docker run -p {service_info['port']}:{service_info['port']} {service_info['docker_image']}
```

## ☸️ Kubernetes

[Kubernetes deployment instructions]

## 📚 Documentation

- [API Documentation](docs/API.md)
- [Deployment Guide](docs/DEPLOYMENT.md)
- [Architecture Details](docs/ARCHITECTURE.md)

## 🔗 Integration

### Dependencies

- Services this depends on
- External services/APIs

### Consumers

- Services that depend on this

## 📊 Monitoring

- Health check endpoints
- Metrics exposed
- Logging configuration

## 🛠️ Development

### Setup

[Development setup instructions]

### Code Structure

[Directory structure]

### Contributing

[Contributing guidelines]

---

**Repository**: [nuniesmith/{service_info['repo_name']}](https://github.com/nuniesmith/{service_info['repo_name']})  
**Docker Image**: `{service_info['docker_image']}`  
**Status**: Active
"""
    return template


def standardize_readme(service_name: str, dry_run: bool = False) -> Tuple[bool, str]:
    """Standardize a service's README.md."""
    service_path = REPO_ROOT / service_name
    
    if not service_path.exists():
        return False, f"Service directory not found: {service_path}"
    
    if service_name not in SERVICES:
        return False, f"Service not in metadata: {service_name}"
    
    service_info = SERVICES[service_name]
    readme_path = service_path / "README.md"
    
    # Read existing README
    existing_content = read_existing_readme(service_path)
    
    if existing_content:
        # Extract existing sections
        sections = extract_sections(existing_content)
        print(f"\n📋 {service_name}: Found {len(sections)} sections")
        
        # Generate new template
        new_template = generate_readme_template(service_name, service_info)
        
        # Merge existing content into template where possible
        # (This is a simplified version - full implementation would be more sophisticated)
        
        if not dry_run:
            readme_path.write_text(new_template)
            return True, f"Updated {readme_path}"
        else:
            return True, f"Would update {readme_path}"
    else:
        # Create new README
        new_content = generate_readme_template(service_name, service_info)
        
        if not dry_run:
            readme_path.write_text(new_content)
            return True, f"Created {readme_path}"
        else:
            return True, f"Would create {readme_path}"


def main():
    """Main function."""
    import argparse
    
    parser = argparse.ArgumentParser(description="Standardize FKS service documentation")
    parser.add_argument("--service", help="Standardize specific service only")
    parser.add_argument("--dry-run", action="store_true", help="Show what would be changed")
    parser.add_argument("--list", action="store_true", help="List all services")
    
    args = parser.parse_args()
    
    if args.list:
        print("Available services:")
        for name, info in SERVICES.items():
            print(f"  {name}: {info['name']} (port {info['port']})")
        return
    
    services_to_process = [args.service] if args.service else list(SERVICES.keys())
    
    print(f"🔧 Standardizing documentation for {len(services_to_process)} service(s)")
    if args.dry_run:
        print("🔍 DRY RUN MODE - No files will be modified")
    
    results = []
    for service_name in services_to_process:
        success, message = standardize_readme(service_name, dry_run=args.dry_run)
        results.append((service_name, success, message))
        status = "✅" if success else "❌"
        print(f"{status} {message}")
    
    print(f"\n📊 Summary: {sum(1 for _, s, _ in results if s)}/{len(results)} successful")
    
    if args.dry_run:
        print("\n💡 Run without --dry-run to apply changes")


if __name__ == "__main__":
    main()

