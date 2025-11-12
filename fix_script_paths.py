#!/usr/bin/env python3
"""
Fix script paths to use repo/core/main as base instead of fks/ root.
Updates all scripts to use relative paths from repo/core/main.
"""

import re
from pathlib import Path

MAIN_REPO = Path(__file__).parent.parent
SCRIPTS_DIR = MAIN_REPO / "scripts"

# Patterns to fix
PATTERNS = [
    (r'BASE_PATH\s*=\s*Path\(["\']/home/jordan/Documents/code/fks["\']\)', 
     f'BASE_PATH = Path(__file__).parent.parent.parent.parent  # repo/'),
    (r'BASE_PATH\s*=\s*Path\(["\']/home/jordan/Documents/code/fks/repo["\']\)',
     f'BASE_PATH = Path(__file__).parent.parent.parent  # repo/'),
    (r'BASE_PATH\s*=\s*Path\(["\']/home/jordan/Documents/code/fks["\']\)/repo',
     f'BASE_PATH = Path(__file__).parent.parent.parent  # repo/'),
    (r'BASE_PATH\.parent\s*/', 'BASE_PATH /'),
]

def fix_script(script_path: Path):
    """Fix paths in a script file."""
    if not script_path.exists() or not script_path.suffix == '.py':
        return False
    
    content = script_path.read_text()
    original = content
    
    # Fix BASE_PATH definitions
    for pattern, replacement in PATTERNS:
        content = re.sub(pattern, replacement, content)
    
    # Fix hardcoded paths
    content = content.replace(
        'Path(__file__).parent.parent.parent  # repo/',
        'Path(__file__).parent.parent.parent  # repo/'
    )
    content = content.replace(
        'Path(__file__).parent.parent.parent.parent  # repo/',
        'Path(__file__).parent.parent.parent.parent  # repo/'
    )
    
    if content != original:
        script_path.write_text(content)
        return True
    return False

def main():
    """Main entry point."""
    print("🔧 Fixing script paths...\n")
    
    fixed = []
    for script in SCRIPTS_DIR.rglob("*.py"):
        if fix_script(script):
            fixed.append(script.relative_to(MAIN_REPO))
            print(f"✅ Fixed: {script.relative_to(MAIN_REPO)}")
    
    print(f"\n✅ Fixed {len(fixed)} scripts")

if __name__ == "__main__":
    main()

