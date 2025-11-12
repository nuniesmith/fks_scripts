#!/usr/bin/env python3
"""
Phase 1.2: Execute Codebase Cleanup
Safely removes files identified in cleanup analysis
"""

import json
import shutil
from pathlib import Path
from datetime import datetime
from typing import List, Dict

class CleanupExecutor:
    def __init__(self, root_path: Path, dry_run: bool = True):
        self.root = Path(root_path)
        self.dry_run = dry_run
        self.removed = []
        self.skipped = []
        
    def load_analysis(self, analysis_path: Path) -> Dict:
        """Load cleanup analysis results"""
        with open(analysis_path) as f:
            return json.load(f)
    
    def execute_cleanup(self, analysis: Dict):
        """Execute cleanup based on analysis"""
        print(f"{'DRY RUN: ' if self.dry_run else ''}Executing cleanup...\n")
        
        # Process small files
        print("Processing small stub files...")
        for item in analysis.get('small_files', []):
            self._remove_file(item['path'], f"Small stub ({item['size']} bytes)")
        
        # Process redundant __init__.py
        print("\nProcessing redundant __init__.py files...")
        for item in analysis.get('redundant_init', []):
            # Be conservative - only remove if truly empty
            if item['size'] == 0:
                self._remove_file(item['path'], "Empty __init__.py")
            else:
                self.skipped.append({
                    'path': item['path'],
                    'reason': 'Has content, keeping for package structure'
                })
        
        # Process duplicate READMEs (keep one, remove others)
        print("\nProcessing duplicate README files...")
        for dup_set in analysis.get('duplicate_readmes', []):
            paths = dup_set['paths']
            # Keep the first one, remove others
            for path in paths[1:]:
                self._remove_file(path, f"Duplicate README (keeping {paths[0]})")
    
    def _remove_file(self, rel_path: str, reason: str):
        """Remove a file (or simulate removal in dry run)"""
        full_path = self.root / rel_path
        
        if not full_path.exists():
            self.skipped.append({
                'path': rel_path,
                'reason': 'File does not exist'
            })
            return
        
        try:
            if self.dry_run:
                print(f"  [DRY RUN] Would remove: {rel_path} ({reason})")
            else:
                full_path.unlink()
                print(f"  Removed: {rel_path} ({reason})")
            
            self.removed.append({
                'path': rel_path,
                'reason': reason,
                'timestamp': datetime.now().isoformat()
            })
        except Exception as e:
            self.skipped.append({
                'path': rel_path,
                'reason': f'Error: {str(e)}'
            })
            print(f"  ERROR: Could not remove {rel_path}: {e}")
    
    def generate_report(self, output_path: Path):
        """Generate cleanup report"""
        report = {
            'dry_run': self.dry_run,
            'timestamp': datetime.now().isoformat(),
            'removed': self.removed,
            'skipped': self.skipped,
            'summary': {
                'total_removed': len(self.removed),
                'total_skipped': len(self.skipped)
            }
        }
        
        output_path.parent.mkdir(parents=True, exist_ok=True)
        with open(output_path, 'w') as f:
            json.dump(report, f, indent=2)
        
        print(f"\nReport saved to {output_path}")
        print(f"Summary: {len(self.removed)} removed, {len(self.skipped)} skipped")


def main():
    import argparse
    
    parser = argparse.ArgumentParser(description='Execute codebase cleanup')
    parser.add_argument('--execute', action='store_true', 
                       help='Actually remove files (default is dry run)')
    parser.add_argument('--analysis', type=str,
                       default='repo/main/docs/todo/CLEANUP_ANALYSIS.json',
                       help='Path to cleanup analysis JSON file')
    
    args = parser.parse_args()
    
    # Get repo root
    script_dir = Path(__file__).parent
    repo_root = script_dir.parent.parent.parent
    
    # Load analysis
    analysis_path = repo_root / args.analysis
    if not analysis_path.exists():
        print(f"Error: Analysis file not found: {analysis_path}")
        return
    
    executor = CleanupExecutor(repo_root, dry_run=not args.execute)
    analysis = executor.load_analysis(analysis_path)
    
    print("=" * 60)
    print("CODEBASE CLEANUP EXECUTION")
    print("=" * 60)
    print(f"Mode: {'DRY RUN' if executor.dry_run else 'EXECUTE'}")
    print(f"Analysis file: {analysis_path}")
    print()
    
    executor.execute_cleanup(analysis)
    
    # Generate report
    report_path = repo_root / "main" / "docs" / "todo" / "CLEANUP_REPORT.json"
    executor.generate_report(report_path)
    
    if executor.dry_run:
        print("\n" + "=" * 60)
        print("This was a DRY RUN. No files were actually removed.")
        print("Run with --execute to actually remove files.")
        print("=" * 60)


if __name__ == "__main__":
    main()

