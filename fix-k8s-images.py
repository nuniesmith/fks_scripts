#!/usr/bin/env python3
"""Fix K8s image repositories to use nuniesmith/fks with correct service tags."""

import re
from pathlib import Path

# Service mapping: old -> new
services = {
    'fks/main': ('nuniesmith/fks', 'main-latest'),
    'fks/api': ('nuniesmith/fks', 'api-latest'),
    'fks/app': ('nuniesmith/fks', 'app-latest'),
    'fks/ai': ('nuniesmith/fks', 'ai-latest'),
    'fks/data': ('nuniesmith/fks', 'data-latest'),
    'fks/execution': ('nuniesmith/fks', 'execution-latest'),
    'fks/ninja': ('nuniesmith/fks', 'ninja-latest'),
    'fks/mt5': ('nuniesmith/fks', 'mt5-latest'),
    'fks/web': ('nuniesmith/fks', 'web-latest'),
}

def fix_values_file(filepath):
    """Fix image repositories in values.yaml."""
    with open(filepath, 'r') as f:
        content = f.read()
    
    for old_repo, (new_repo, new_tag) in services.items():
        # Replace repository line
        content = re.sub(
            rf'repository: {re.escape(old_repo)}',
            f'repository: {new_repo}',
            content
        )
        
        # Update tag line that follows (if tag: latest exists)
        content = re.sub(
            rf'(repository: {re.escape(new_repo)}\n\s+)tag: latest',
            rf'\1tag: {new_tag}',
            content
        )
    
    with open(filepath, 'w') as f:
        f.write(content)
    
    print(f"✅ Fixed {filepath}")

if __name__ == '__main__':
    base_path = Path(__file__).parent.parent / 'k8s' / 'charts' / 'fks-platform'
    
    # Fix all values files
    for values_file in ['values.yaml', 'values-dev.yaml', 'values-prod.yaml']:
        filepath = base_path / values_file
        if filepath.exists():
            fix_values_file(filepath)
        else:
            print(f"⚠️  {filepath} not found")
    
    print("\n✅ All values files updated!")
    print("Next steps:")
    print("  1. helm upgrade fks-platform k8s/charts/fks-platform -n fks-trading")
    print("  2. kubectl rollout restart deployment -n fks-trading")
