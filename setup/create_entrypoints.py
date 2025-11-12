#!/usr/bin/env python3
"""Create entrypoint.sh files for services that need them."""

from pathlib import Path

# Get repo/ directory (5 levels up from scripts/setup/)
BASE_PATH = Path(__file__).parent.parent.parent.parent.parent  # repo/

SERVICES = {
    "fks_app": (BASE_PATH / "core" / "app", 8002),
    "fks_data": (BASE_PATH / "core" / "data", 8003),
    "fks_web": (BASE_PATH / "core" / "web", 8000),
    "fks_ai": (BASE_PATH / "gpu" / "ai", 8007),
}

def create_entrypoint(repo_path: Path, service_name: str, port: int):
    """Create entrypoint.sh for a service."""
    entrypoint_path = repo_path / "entrypoint.sh"
    if entrypoint_path.exists():
        return False
    
    content = f"""#!/bin/bash
# Entrypoint script for {service_name}

set -e

# Default values
SERVICE_NAME=${{SERVICE_NAME:-{service_name}}}
SERVICE_PORT=${{SERVICE_PORT:-{port}}}
HOST=${{HOST:-0.0.0.0}}

echo "Starting ${{SERVICE_NAME}} on ${{HOST}}:${{SERVICE_PORT}}"

# Run the service
exec uvicorn src.main:app \\
    --host "${{HOST}}" \\
    --port "${{SERVICE_PORT}}" \\
    --no-access-log \\
    --log-level info
"""
    
    entrypoint_path.write_text(content)
    entrypoint_path.chmod(0o755)
    return True

def main():
    """Main entry point."""
    print("Creating entrypoint.sh files...\n")
    
    created = []
    for service_name, (repo_path, port) in SERVICES.items():
        if repo_path.exists():
            if create_entrypoint(repo_path, service_name, port):
                created.append(service_name)
                print(f"✅ Created entrypoint.sh for {service_name}")
            else:
                print(f"✓ {service_name} already has entrypoint.sh")
    
    if created:
        print(f"\n✅ Created {len(created)} entrypoint files")
    else:
        print("\n✓ All services already have entrypoint.sh")

if __name__ == "__main__":
    main()

