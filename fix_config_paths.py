#!/usr/bin/env python3
"""
Fix config file paths in scripts to use repo/core/main/config/ instead of repo/config/
"""

import re
from pathlib import Path

MAIN_REPO = Path(__file__).parent.parent
SCRIPTS_DIR = MAIN_REPO / "scripts"

def fix_config_paths(script_path: Path):
    """Fix config paths in a script."""
    if not script_path.exists() or not script_path.suffix == '.py':
        return False
    
    content = script_path.read_text()
    original = content
    
    # Fix BASE_PATH / "config" to use main_repo / "config"
    # Pattern: BASE_PATH / "config" -> main_repo = BASE_PATH / "core" / "main"; main_repo / "config"
    content = re.sub(
        r'(\w+_file\s*=\s*)BASE_PATH\s*/\s*["\']config["\']',
        r'\1main_repo / "config"',
        content
    )
    
    # Add main_repo definition if config is used
    if 'main_repo / "config"' in content and 'main_repo = BASE_PATH / "core" / "main"' not in content:
        # Find where BASE_PATH is defined and add main_repo after it
        content = re.sub(
            r'(BASE_PATH\s*=\s*[^\n]+\n)',
            r'\1    main_repo = BASE_PATH / "core" / "main"\n',
            content,
            count=1
        )
    
    # Fix BASE_PATH / "docs" to use main_repo / "docs"
    content = re.sub(
        r'(\w+_file\s*=\s*)BASE_PATH\s*/\s*["\']docs["\']',
        r'\1main_repo / "docs"',
        content
    )
    
    # Fix BASE_PATH / "k8s" to use main_repo / "k8s"
    content = re.sub(
        r'(\w+_file\s*=\s*)BASE_PATH\s*/\s*["\']k8s["\']',
        r'\1main_repo / "k8s"',
        content
    )
    
    if content != original:
        script_path.write_text(content)
        return True
    return False

def main():
    """Main entry point."""
    print("🔧 Fixing config paths in scripts...\n")
    
    fixed = []
    for script in SCRIPTS_DIR.rglob("*.py"):
        if fix_config_paths(script):
            fixed.append(script.relative_to(MAIN_REPO))
            print(f"✅ Fixed: {script.relative_to(MAIN_REPO)}")
    
    print(f"\n✅ Fixed {len(fixed)} scripts")

if __name__ == "__main__":
    main()

