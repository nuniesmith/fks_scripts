#!/usr/bin/env python3
"""
Phase 3.2: Optimize Service Communication and Discovery
Standardizes APIs and improves inter-service communication.
"""

import json
from pathlib import Path
from typing import Dict, List, Any
from datetime import datetime

# Get repo/ directory (5 levels up from scripts/phase3/)
BASE_PATH = Path(__file__).parent.parent.parent.parent.parent  # repo/
main_repo = BASE_PATH / "core" / "main"

# Service communication patterns
SERVICES = {
    "fks_api": {"port": 8001, "dependencies": ["fks_data", "fks_auth"]},
    "fks_app": {"port": 8002, "dependencies": ["fks_api", "fks_data"]},
    "fks_data": {"port": 8003, "dependencies": []},
    "fks_execution": {"port": 8006, "dependencies": ["fks_api", "fks_data"]},
    "fks_web": {"port": 8000, "dependencies": ["fks_api"]},
    "fks_ai": {"port": 8007, "dependencies": ["fks_data"]},
    "fks_analyze": {"port": 8008, "dependencies": ["fks_data", "fks_ai"]},
    "fks_monitor": {"port": 8009, "dependencies": ["all"]},
    "fks_main": {"port": 8010, "dependencies": ["fks_monitor"]},
}


def create_service_registry():
    """Create centralized service registry."""
    registry_file = main_repo / "config" / "service_registry.json"
    registry_file.parent.mkdir(exist_ok=True)
    
    registry = {
        "version": "1.0",
        "updated": datetime.utcnow().isoformat(),
        "services": {}
    }
    
    for service_name, config in SERVICES.items():
        registry["services"][service_name] = {
            "name": service_name,
            "port": config["port"],
            "base_url": f"http://{service_name}:{config['port']}",
            "health_url": f"http://{service_name}:{config['port']}/health",
            "dependencies": config["dependencies"]
        }
    
    registry_file.write_text(json.dumps(registry, indent=2))
    return registry_file


def create_api_gateway_config():
    """Create API gateway configuration."""
    gateway_file = main_repo / "k8s" / "api-gateway" / "config.yaml"
    gateway_file.parent.mkdir(parents=True, exist_ok=True)
    
    gateway_config = """# API Gateway Configuration for FKS Services
# Routes all external traffic through a single entry point

routes:
"""
    
    for service_name, config in SERVICES.items():
        if service_name in ["fks_web", "fks_main"]:
            # These might be external-facing
            continue
        
        gateway_config += f"""
  - name: {service_name}
    path: /api/{service_name.replace('fks_', '')}
    service: {service_name}
    port: {config['port']}
    health_check:
      path: /health
      interval: 30s
"""
    
    gateway_file.write_text(gateway_config)
    return gateway_file


def create_circuit_breaker_config():
    """Create circuit breaker configuration."""
    cb_file = main_repo / "config" / "circuit_breakers.json"
    cb_file.parent.mkdir(exist_ok=True)
    
    circuit_breakers = {
        "version": "1.0",
        "updated": datetime.utcnow().isoformat(),
        "defaults": {
            "failure_threshold": 5,
            "success_threshold": 2,
            "timeout_seconds": 60,
            "half_open_max_calls": 3
        },
        "services": {}
    }
    
    for service_name, config in SERVICES.items():
        circuit_breakers["services"][service_name] = {
            "enabled": True,
            "failure_threshold": 5,
            "success_threshold": 2,
            "timeout_seconds": 60,
            "fallback": {
                "enabled": True,
                "default_response": {
                    "status": "service_unavailable",
                    "message": f"{service_name} is temporarily unavailable"
                }
            }
        }
    
    cb_file.write_text(json.dumps(circuit_breakers, indent=2))
    return cb_file


def create_tracing_config():
    """Create distributed tracing configuration."""
    tracing_file = main_repo / "config" / "tracing.yaml"
    tracing_file.parent.mkdir(exist_ok=True)
    
    tracing_config = """# Distributed Tracing Configuration
# Uses OpenTelemetry/Jaeger for request tracing

tracing:
  enabled: true
  provider: jaeger
  endpoint: http://jaeger:14268/api/traces
  service_name: fks-service
  sampling_rate: 0.1  # 10% of requests
  
# Headers to propagate
headers:
  - traceparent
  - tracestate
  - x-request-id
  
# Services to trace
services:
"""
    
    for service_name in SERVICES.keys():
        tracing_config += f"  - {service_name}\n"
    
    tracing_file.write_text(tracing_config)
    return tracing_file


def create_service_discovery_docs():
    """Create service discovery documentation."""
    doc_file = main_repo / "docs" / "SERVICE_DISCOVERY.md"
    doc_file.parent.mkdir(exist_ok=True)
    
    doc_content = """# FKS Service Discovery and Communication

## Overview

This document describes how FKS services discover and communicate with each other.

## Service Registry

All services are registered in `config/service_registry.json`. This provides:
- Service locations (hosts and ports)
- Health check endpoints
- Dependency mapping

## Communication Patterns

### Direct HTTP Calls

Services communicate via HTTP REST APIs:
```
fks_api -> fks_data: http://fks-data:8003/api/v1/data
```

### Service Discovery

Services can discover each other via:
1. **Environment Variables**: Pre-configured service URLs
2. **Service Registry**: Centralized registry (future)
3. **Kubernetes DNS**: Automatic DNS resolution in K8s

## Circuit Breakers

Circuit breakers prevent cascading failures:
- **Failure Threshold**: 5 consecutive failures
- **Timeout**: 60 seconds
- **Fallback**: Returns default response when open

Configuration: `config/circuit_breakers.json`

## API Gateway

External traffic routes through API gateway:
- Path: `/api/{service}`
- Load balancing
- Rate limiting
- Authentication

## Distributed Tracing

All requests are traced using Jaeger:
- Trace IDs propagated via headers
- 10% sampling rate
- Full request flow visibility

## Best Practices

1. **Always use service names** (not IPs)
2. **Implement circuit breakers** for external calls
3. **Add request timeouts** (default: 5s)
4. **Log trace IDs** for debugging
5. **Use health checks** before making calls

## Service Dependencies

"""
    
    for service_name, config in SERVICES.items():
        deps = config.get("dependencies", [])
        if deps:
            doc_content += f"\n### {service_name}\n"
            doc_content += f"Depends on: {', '.join(deps)}\n"
    
    doc_file.write_text(doc_content)
    return doc_file


def main():
    """Main entry point."""
    print("🔗 Phase 3.2: Optimizing Service Communication\n")
    print("=" * 60)
    
    files_created = []
    
    # Create service registry
    print("\n1. Creating service registry...")
    registry_file = create_service_registry()
    files_created.append(registry_file)
    print(f"   ✅ Created: {registry_file}")
    
    # Create API gateway config
    print("\n2. Creating API gateway configuration...")
    gateway_file = create_api_gateway_config()
    files_created.append(gateway_file)
    print(f"   ✅ Created: {gateway_file}")
    
    # Create circuit breaker config
    print("\n3. Creating circuit breaker configuration...")
    cb_file = create_circuit_breaker_config()
    files_created.append(cb_file)
    print(f"   ✅ Created: {cb_file}")
    
    # Create tracing config
    print("\n4. Creating distributed tracing configuration...")
    tracing_file = create_tracing_config()
    files_created.append(tracing_file)
    print(f"   ✅ Created: {tracing_file}")
    
    # Create documentation
    print("\n5. Creating service discovery documentation...")
    doc_file = create_service_discovery_docs()
    files_created.append(doc_file)
    print(f"   ✅ Created: {doc_file}")
    
    print("\n" + "=" * 60)
    print("📊 Summary")
    print("=" * 60)
    print(f"Services configured: {len(SERVICES)}")
    print(f"Files created: {len(files_created)}")
    print("\n✅ Service communication optimization complete!")
    print("\nNext steps:")
    print("  1. Implement circuit breakers in services")
    print("  2. Deploy API gateway")
    print("  3. Set up Jaeger for tracing")
    print("  4. Review: docs/SERVICE_DISCOVERY.md")


if __name__ == "__main__":
    main()

