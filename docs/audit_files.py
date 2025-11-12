#!/usr/bin/env python3
"""
FKS Documentation Audit Script
Analyzes docs directory to identify files for cleanup, merging, or deletion.

Usage:
    python scripts/docs/audit_files.py --docs-dir repo/main/docs --output audit-report.json
"""

import os
import json
import hashlib
from pathlib import Path
from collections import defaultdict
from datetime import datetime
from typing import Dict, List, Tuple
import argparse


class DocsAuditor:
    """Audits documentation files for cleanup opportunities."""
    
    def __init__(self, docs_dir: str):
        self.docs_dir = Path(docs_dir)
        self.results = {
            'timestamp': datetime.now().isoformat(),
            'total_files': 0,
            'by_category': defaultdict(list),
            'small_files': [],
            'empty_files': [],
            'potential_duplicates': [],
            'redundant_status': [],
            'todo_files': [],
            'recommendations': []
        }
    
    def analyze_file(self, filepath: Path) -> Dict:
        """Analyze a single file and return metadata."""
        try:
            stat = filepath.stat()
            size = stat.st_size
            
            # Read content
            try:
                with open(filepath, 'r', encoding='utf-8') as f:
                    content = f.read()
            except UnicodeDecodeError:
                content = ""
            
            # Calculate hash for duplicate detection
            file_hash = hashlib.md5(content.encode()).hexdigest()
            
            # Categorize by filename patterns
            category = self._categorize_file(filepath.name)
            
            return {
                'path': str(filepath.relative_to(self.docs_dir)),
                'size': size,
                'lines': len(content.splitlines()),
                'hash': file_hash,
                'category': category,
                'is_small': size < 100,
                'is_empty': size == 0 or len(content.strip()) == 0,
                'is_status': 'STATUS' in filepath.name.upper() or 'SUMMARY' in filepath.name.upper(),
                'is_todo': 'todo' in str(filepath).lower() or 'TASK' in filepath.name.upper(),
                'is_redundant': self._is_redundant(filepath.name)
            }
        except Exception as e:
            return {
                'path': str(filepath.relative_to(self.docs_dir)),
                'error': str(e)
            }
    
    def _categorize_file(self, filename: str) -> str:
        """Categorize file by name patterns."""
        filename_upper = filename.upper()
        
        if 'ARCHITECTURE' in filename_upper or 'DESIGN' in filename_upper:
            return 'architecture'
        elif 'DEPLOY' in filename_upper or 'K8S' in filename_upper or 'OPERATION' in filename_upper:
            return 'operations'
        elif 'GUIDE' in filename_upper or 'QUICK' in filename_upper:
            return 'guides'
        elif 'PHASE' in filename_upper or 'IMPLEMENTATION' in filename_upper:
            return 'implementation'
        elif 'STATUS' in filename_upper or 'SUMMARY' in filename_upper or 'REPORT' in filename_upper:
            return 'status'
        elif 'TODO' in filename_upper or 'TASK' in filename_upper or 'ACTION' in filename_upper:
            return 'tasks'
        elif 'TEMPLATE' in filename_upper:
            return 'templates'
        elif 'TEST' in filename_upper:
            return 'testing'
        else:
            return 'other'
    
    def _is_redundant(self, filename: str) -> bool:
        """Check if filename suggests redundancy."""
        redundant_patterns = [
            'FINAL-STATUS',
            'COMPLETE-SUMMARY',
            'EXECUTIVE-SUMMARY',
            'COMPREHENSIVE-SUMMARY',
            'CURRENT-STATUS',
            'LATEST-STATUS'
        ]
        filename_upper = filename.upper()
        return any(pattern in filename_upper for pattern in redundant_patterns)
    
    def find_duplicates(self, files: List[Dict]) -> List[List[str]]:
        """Find files with identical content (same hash)."""
        hash_to_files = defaultdict(list)
        for file_info in files:
            if 'hash' in file_info:
                hash_to_files[file_info['hash']].append(file_info['path'])
        
        # Return groups with more than one file
        return [group for group in hash_to_files.values() if len(group) > 1]
    
    def audit(self) -> Dict:
        """Run full audit of documentation directory."""
        print(f"Auditing documentation in: {self.docs_dir}")
        
        all_files = []
        
        # Walk through all files
        for root, dirs, files in os.walk(self.docs_dir):
            # Skip hidden directories
            dirs[:] = [d for d in dirs if not d.startswith('.')]
            
            for filename in files:
                if filename.startswith('.'):
                    continue
                
                filepath = Path(root) / filename
                file_info = self.analyze_file(filepath)
                all_files.append(file_info)
                self.results['total_files'] += 1
                
                # Categorize
                category = file_info.get('category', 'other')
                self.results['by_category'][category].append(file_info['path'])
                
                # Flag issues
                if file_info.get('is_empty'):
                    self.results['empty_files'].append(file_info['path'])
                elif file_info.get('is_small'):
                    self.results['small_files'].append(file_info['path'])
                
                if file_info.get('is_status'):
                    self.results['redundant_status'].append(file_info['path'])
                
                if file_info.get('is_todo'):
                    self.results['todo_files'].append(file_info['path'])
        
        # Find duplicates
        duplicates = self.find_duplicates(all_files)
        self.results['potential_duplicates'] = duplicates
        
        # Generate recommendations
        self._generate_recommendations()
        
        return self.results
    
    def _generate_recommendations(self):
        """Generate cleanup recommendations."""
        recommendations = []
        
        # Small/empty files
        small_count = len(self.results['small_files'])
        if small_count > 0:
            recommendations.append({
                'action': 'delete',
                'files': small_count,
                'description': f'Delete {small_count} small/empty files',
                'files_list': self.results['small_files'][:20]  # First 20
            })
        
        # Redundant status files
        status_count = len(self.results['redundant_status'])
        if status_count > 5:
            recommendations.append({
                'action': 'merge',
                'files': status_count,
                'description': f'Merge {status_count} redundant status files into PROJECT-STATUS.md',
                'files_list': self.results['redundant_status']
            })
        
        # Duplicates
        dup_count = sum(len(group) - 1 for group in self.results['potential_duplicates'])
        if dup_count > 0:
            recommendations.append({
                'action': 'delete',
                'files': dup_count,
                'description': f'Delete {dup_count} duplicate files',
                'files_list': self.results['potential_duplicates']
            })
        
        # Todo files
        todo_count = len(self.results['todo_files'])
        if todo_count > 0:
            recommendations.append({
                'action': 'migrate',
                'files': todo_count,
                'description': f'Migrate {todo_count} todo files to GitHub Issues',
                'files_list': self.results['todo_files']
            })
        
        self.results['recommendations'] = recommendations
    
    def save_report(self, output_path: str):
        """Save audit results to JSON file."""
        with open(output_path, 'w', encoding='utf-8') as f:
            json.dump(self.results, f, indent=2, ensure_ascii=False)
        print(f"Audit report saved to: {output_path}")
    
    def print_summary(self):
        """Print human-readable summary."""
        print("\n" + "="*60)
        print("DOCUMENTATION AUDIT SUMMARY")
        print("="*60)
        print(f"Total Files: {self.results['total_files']}")
        print(f"\nBy Category:")
        for category, files in sorted(self.results['by_category'].items()):
            print(f"  {category}: {len(files)} files")
        
        print(f"\nIssues Found:")
        print(f"  Empty files: {len(self.results['empty_files'])}")
        print(f"  Small files: {len(self.results['small_files'])}")
        print(f"  Status files: {len(self.results['redundant_status'])}")
        print(f"  Todo files: {len(self.results['todo_files'])}")
        print(f"  Duplicate groups: {len(self.results['potential_duplicates'])}")
        
        print(f"\nRecommendations:")
        for i, rec in enumerate(self.results['recommendations'], 1):
            print(f"  {i}. {rec['description']}")
            if rec['files_list']:
                print(f"     Sample files: {', '.join(rec['files_list'][:3])}")
        
        print("="*60 + "\n")


def main():
    parser = argparse.ArgumentParser(description='Audit FKS documentation files')
    parser.add_argument('--docs-dir', default='repo/main/docs', help='Documentation directory')
    parser.add_argument('--output', default='docs-audit-report.json', help='Output JSON file')
    parser.add_argument('--summary', action='store_true', help='Print summary to console')
    
    args = parser.parse_args()
    
    auditor = DocsAuditor(args.docs_dir)
    results = auditor.audit()
    
    auditor.save_report(args.output)
    
    if args.summary:
        auditor.print_summary()
    
    return 0


if __name__ == '__main__':
    exit(main())

