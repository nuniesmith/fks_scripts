#!/usr/bin/env python3
"""
Phase 1.2: Codebase Cleanup Analysis
Identifies empty files, redundant files, and cleanup opportunities
"""

import os
import json
from pathlib import Path
from collections import defaultdict
from datetime import datetime
from typing import Dict, List, Tuple

# Exclude directories
EXCLUDE_DIRS = {
    '.git', '__pycache__', '.pytest_cache', 'node_modules', 
    '.venv', 'venv', 'target', 'build', 'dist', '.mypy_cache',
    '.ruff_cache', 'htmlcov', '.coverage', 'fks_backup_*'
}

# Files to always keep even if empty
KEEP_PATTERNS = {
    '__init__.py',  # Python package markers
    '.gitkeep',
    '.gitignore',
    'requirements.txt',
    'README.md',
    'Makefile',
    '.env.example'
}

class CleanupAnalyzer:
    def __init__(self, root_path: Path):
        self.root = Path(root_path)
        self.results = {
            'empty_files': [],
            'small_files': [],
            'redundant_init': [],
            'duplicate_readmes': [],
            'summary': {}
        }
        
    def analyze(self) -> Dict:
        """Run full analysis"""
        print("Analyzing codebase for cleanup opportunities...\n")
        
        self.find_empty_files()
        self.find_small_files()
        self.analyze_init_files()
        self.find_duplicate_readmes()
        self.generate_summary()
        
        return self.results
    
    def find_empty_files(self):
        """Find truly empty files (0 bytes)"""
        print("Scanning for empty files...")
        count = 0
        
        for path in self.root.rglob("*"):
            if self._should_skip(path):
                continue
                
            if path.is_file() and path.stat().st_size == 0:
                # Check if it's a keep pattern
                if path.name in KEEP_PATTERNS:
                    continue
                    
                self.results['empty_files'].append({
                    'path': str(path.relative_to(self.root)),
                    'size': 0,
                    'type': 'empty'
                })
                count += 1
        
        print(f"   Found {count} empty files\n")
    
    def find_small_files(self):
        """Find small files (< 50 bytes, likely stubs)"""
        print("Scanning for small files (< 50 bytes)...")
        count = 0
        
        for path in self.root.rglob("*.py"):
            if self._should_skip(path):
                continue
                
            size = path.stat().st_size
            if 0 < size < 50:
                # Read content to check if it's just a stub
                try:
                    content = path.read_text()
                    lines = [l.strip() for l in content.splitlines() if l.strip()]
                    if len(lines) <= 3:  # Very small files
                        self.results['small_files'].append({
                            'path': str(path.relative_to(self.root)),
                            'size': size,
                            'lines': len(lines),
                            'content_preview': content[:100]
                        })
                        count += 1
                except:
                    pass
        
        print(f"   Found {count} small stub files\n")
    
    def analyze_init_files(self):
        """Analyze __init__.py files for redundancy"""
        print("Analyzing __init__.py files...")
        count = 0
        
        for path in self.root.rglob("__init__.py"):
            if self._should_skip(path):
                continue
                
            size = path.stat().st_size
            if size <= 10:  # Very small or empty
                try:
                    content = path.read_text()
                    # Check if it's just whitespace or a single comment
                    stripped = content.strip()
                    if not stripped or stripped.startswith('#'):
                        self.results['redundant_init'].append({
                            'path': str(path.relative_to(self.root)),
                            'size': size,
                            'content': content
                        })
                        count += 1
                except:
                    pass
        
        print(f"   Found {count} potentially redundant __init__.py files\n")
    
    def find_duplicate_readmes(self):
        """Find duplicate README files"""
        print("Scanning for duplicate README files...")
        readmes = defaultdict(list)
        
        for path in self.root.rglob("README*.md"):
            if self._should_skip(path):
                continue
                
            # Group by similar content (first 200 chars as hash)
            try:
                content = path.read_text()[:200]
                readmes[content].append(str(path.relative_to(self.root)))
            except:
                pass
        
        # Find duplicates
        for content, paths in readmes.items():
            if len(paths) > 1:
                self.results['duplicate_readmes'].append({
                    'paths': paths,
                    'count': len(paths)
                })
        
        print(f"   Found {len(self.results['duplicate_readmes'])} sets of duplicate READMEs\n")
    
    def generate_summary(self):
        """Generate summary statistics"""
        self.results['summary'] = {
            'total_empty': len(self.results['empty_files']),
            'total_small': len(self.results['small_files']),
            'total_redundant_init': len(self.results['redundant_init']),
            'total_duplicate_readmes': sum(
                len(d['paths']) - 1 for d in self.results['duplicate_readmes']
            ),
            'estimated_cleanup': (
                len(self.results['empty_files']) +
                len(self.results['small_files']) +
                len(self.results['redundant_init'])
            ),
            'timestamp': datetime.now().isoformat()
        }
    
    def _should_skip(self, path: Path) -> bool:
        """Check if path should be skipped"""
        parts = path.parts
        return any(ex in parts for ex in EXCLUDE_DIRS)
    
    def save_report(self, output_path: Path):
        """Save analysis report to JSON"""
        output_path.parent.mkdir(parents=True, exist_ok=True)
        with open(output_path, 'w') as f:
            json.dump(self.results, f, indent=2)
        print(f"Report saved to {output_path}")


def main():
    # Get repo root (assuming script is in repo/main/scripts/)
    script_dir = Path(__file__).parent
    repo_root = script_dir.parent.parent.parent  # Go up to repo/
    
    analyzer = CleanupAnalyzer(repo_root)
    results = analyzer.analyze()
    
    # Print summary
    print("=" * 60)
    print("CLEANUP ANALYSIS SUMMARY")
    print("=" * 60)
    print(f"Empty files: {results['summary']['total_empty']}")
    print(f"Small stub files: {results['summary']['total_small']}")
    print(f"Redundant __init__.py: {results['summary']['total_redundant_init']}")
    print(f"Duplicate READMEs: {results['summary']['total_duplicate_readmes']}")
    print(f"Estimated files to clean: {results['summary']['estimated_cleanup']}")
    print("=" * 60)
    
    # Save report
    report_path = repo_root / "main" / "docs" / "todo" / "CLEANUP_ANALYSIS.json"
    analyzer.save_report(report_path)
    
    # Save human-readable summary
    summary_path = repo_root / "main" / "docs" / "todo" / "CLEANUP_SUMMARY.md"
    with open(summary_path, 'w') as f:
        f.write("# Codebase Cleanup Analysis Summary\n\n")
        f.write(f"**Date**: {results['summary']['timestamp']}\n\n")
        f.write("## Summary\n\n")
        f.write(f"- **Empty Files**: {results['summary']['total_empty']}\n")
        f.write(f"- **Small Stub Files**: {results['summary']['total_small']}\n")
        f.write(f"- **Redundant __init__.py**: {results['summary']['total_redundant_init']}\n")
        f.write(f"- **Duplicate READMEs**: {results['summary']['total_duplicate_readmes']}\n")
        f.write(f"- **Total Cleanup Candidates**: {results['summary']['estimated_cleanup']}\n\n")
        
        if results['empty_files']:
            f.write("## Empty Files (Top 20)\n\n")
            for item in results['empty_files'][:20]:
                f.write(f"- `{item['path']}`\n")
            f.write("\n")
        
        if results['small_files']:
            f.write("## Small Stub Files (Top 20)\n\n")
            for item in results['small_files'][:20]:
                f.write(f"- `{item['path']}` ({item['size']} bytes, {item['lines']} lines)\n")
            f.write("\n")
    
    print(f"Summary saved to {summary_path}")


if __name__ == "__main__":
    main()

