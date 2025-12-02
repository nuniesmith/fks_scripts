#!/usr/bin/env python3
"""
FKS File Cleanup Script
Safely identifies and removes empty files and small stub files
"""

import os
import json
from pathlib import Path
import argparse
from datetime import datetime

class FileCleanup:
    def __init__(self, workspace_root, dry_run=True):
        self.root = Path(workspace_root)
        self.dry_run = dry_run
        self.to_delete = []
        self.deleted = []
        
    def find_files_to_clean(self):
        """Find empty and small files that should be cleaned"""
        print("🔍 Scanning for files to clean...\n")
        
        # Load the analysis report for context
        report_path = self.root / "docs" / "SRC_STRUCTURE_ANALYSIS.json"
        if report_path.exists():
            with open(report_path) as f:
                analysis = json.load(f)
                empty_files = analysis['file_inventory']['empty_files']
                small_files = analysis['file_inventory']['small_files']
                
                print(f"📊 Found from analysis:")
                print(f"   - {len(empty_files)} empty files")
                print(f"   - {len(small_files)} small files (<100 bytes)\n")
                
                # Process empty files
                for file_info in empty_files:
                    file_path = self.root / file_info['path']
                    if file_path.exists() and self.should_delete(file_path):
                        self.to_delete.append({
                            'path': file_path,
                            'reason': 'Empty file (0 bytes)',
                            'info': file_info
                        })
                
                # Process small files - be selective
                for file_info in small_files:
                    file_path = self.root / file_info['path']
                    if file_path.exists() and self.should_delete_small(file_path):
                        self.to_delete.append({
                            'path': file_path,
                            'reason': f'Small stub file ({file_info["size"]} bytes)',
                            'info': file_info
                        })
        
        return self.to_delete
    
    def should_delete(self, file_path):
        """Determine if an empty file should be deleted"""
        # Always keep certain files even if empty
        keep_patterns = [
            '__init__.py',  # Keep for now, will evaluate individually
            '.gitkeep',
            '.gitignore',
            'requirements.txt',
            'README.md',
            'Makefile'
        ]
        
        # Skip certain directories
        skip_dirs = [
            '.git',
            '__pycache__',
            '.pytest_cache',
            'node_modules',
            '.venv',
            'venv'
        ]
        
        if any(skip in str(file_path) for skip in skip_dirs):
            return False
        
        # For now, only delete truly empty non-Python files
        # We'll handle __init__.py separately
        if file_path.suffix == '.py':
            return False  # Be conservative with Python files
        
        return True
    
    def should_delete_small(self, file_path):
        """Determine if a small file should be deleted"""
        # Only delete small __init__.py files that are truly stubs
        if file_path.name == '__init__.py':
            # Read the file to check if it's just whitespace/comments
            try:
                content = file_path.read_text().strip()
                # If it's empty, only comments, or only whitespace, consider deleting
                if not content or all(line.strip().startswith('#') or not line.strip() 
                                     for line in content.split('\n')):
                    return True
            except:
                pass
        
        return False
    
    def clean_files(self):
        """Delete files that were identified for cleanup"""
        if not self.to_delete:
            print("✅ No files to clean!")
            return
        
        print(f"\n📋 Files to {'DELETE' if not self.dry_run else 'REVIEW'}:")
        print("=" * 80)
        
        for item in self.to_delete:
            rel_path = item['path'].relative_to(self.root)
            print(f"   {rel_path}")
            print(f"   └─ {item['reason']}")
        
        print("=" * 80)
        print(f"\nTotal: {len(self.to_delete)} files\n")
        
        if self.dry_run:
            print("⚠️  DRY RUN MODE - No files were deleted")
            print("   Run with --execute to actually delete files")
            return
        
        # Confirm deletion
        response = input("⚠️  Are you sure you want to delete these files? (yes/no): ")
        if response.lower() != 'yes':
            print("❌ Cleanup cancelled")
            return
        
        # Delete files
        for item in self.to_delete:
            try:
                item['path'].unlink()
                self.deleted.append(item)
                print(f"✅ Deleted: {item['path'].relative_to(self.root)}")
            except Exception as e:
                print(f"❌ Failed to delete {item['path']}: {e}")
        
        print(f"\n✅ Cleanup complete! Deleted {len(self.deleted)} files")
        
        # Save cleanup log
        self.save_cleanup_log()
    
    def save_cleanup_log(self):
        """Save a log of what was deleted"""
        log_path = self.root / "docs" / "CLEANUP_LOG.json"
        
        log = {
            'timestamp': datetime.now().isoformat(),
            'deleted_files': [
                {
                    'path': str(item['path'].relative_to(self.root)),
                    'reason': item['reason'],
                    'size': item['info']['size'],
                    'last_modified': item['info']['last_modified']
                }
                for item in self.deleted
            ],
            'total_deleted': len(self.deleted)
        }
        
        with open(log_path, 'w') as f:
            json.dump(log, f, indent=2)
        
        print(f"\n📄 Cleanup log saved to: {log_path}")


def main():
    parser = argparse.ArgumentParser(description='Clean up empty and small files in FKS workspace')
    parser.add_argument('--execute', action='store_true', help='Actually delete files (default is dry run)')
    parser.add_argument('--workspace', default='/home/jordan/Documents/fks', help='Workspace root path')
    
    args = parser.parse_args()
    
    print("🧹 FKS File Cleanup Tool")
    print("=" * 80)
    print(f"Workspace: {args.workspace}")
    print(f"Mode: {'EXECUTE' if args.execute else 'DRY RUN'}")
    print("=" * 80)
    print()
    
    cleaner = FileCleanup(args.workspace, dry_run=not args.execute)
    cleaner.find_files_to_clean()
    cleaner.clean_files()


if __name__ == "__main__":
    main()
