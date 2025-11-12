#!/usr/bin/env python3
"""
FKS Documentation Merge Script
Merges redundant status/summary files into consolidated documents.

Usage:
    python scripts/docs/merge_redundants.py --audit-report audit-report.json --dry-run
"""

import json
import argparse
from pathlib import Path
from datetime import datetime
from typing import List, Dict
import re


class DocsMerger:
    """Merges redundant documentation files."""
    
    def __init__(self, docs_dir: str, dry_run: bool = True):
        self.docs_dir = Path(docs_dir)
        self.dry_run = dry_run
        self.merged_files = []
        self.deleted_files = []
    
    def merge_status_files(self, status_files: List[str], target: str = "PROJECT-STATUS.md"):
        """Merge multiple status files into a single PROJECT-STATUS.md."""
        target_path = self.docs_dir / target
        
        sections = []
        metadata = {
            'merged_from': [],
            'merged_date': datetime.now().isoformat()
        }
        
        # Read all status files
        for filepath in status_files:
            full_path = self.docs_dir / filepath
            if not full_path.exists():
                continue
            
            try:
                with open(full_path, 'r', encoding='utf-8') as f:
                    content = f.read()
                
                # Extract key sections
                sections.append({
                    'source': filepath,
                    'content': self._extract_key_sections(content),
                    'date': self._extract_date(content)
                })
                metadata['merged_from'].append(filepath)
            except Exception as e:
                print(f"Error reading {filepath}: {e}")
        
        # Generate merged content
        merged_content = self._generate_merged_content(sections, metadata)
        
        # Write merged file
        if not self.dry_run:
            with open(target_path, 'w', encoding='utf-8') as f:
                f.write(merged_content)
            print(f"Created merged file: {target_path}")
        else:
            print(f"[DRY RUN] Would create: {target_path}")
            print(f"[DRY RUN] Merged content preview:\n{merged_content[:500]}...")
        
        # Delete source files
        for filepath in status_files:
            full_path = self.docs_dir / filepath
            if full_path.exists() and full_path != target_path:
                if not self.dry_run:
                    full_path.unlink()
                    print(f"Deleted: {filepath}")
                else:
                    print(f"[DRY RUN] Would delete: {filepath}")
                self.deleted_files.append(filepath)
        
        self.merged_files.append(target)
    
    def _extract_key_sections(self, content: str) -> Dict[str, str]:
        """Extract key sections from markdown content."""
        sections = {}
        
        # Find all headings and their content
        lines = content.split('\n')
        current_heading = None
        current_content = []
        
        for line in lines:
            if line.startswith('#'):
                if current_heading:
                    sections[current_heading] = '\n'.join(current_content).strip()
                current_heading = line.strip()
                current_content = []
            else:
                current_content.append(line)
        
        if current_heading:
            sections[current_heading] = '\n'.join(current_content).strip()
        
        return sections
    
    def _extract_date(self, content: str) -> str:
        """Extract date from content."""
        # Look for date patterns
        date_patterns = [
            r'(\d{4}-\d{2}-\d{2})',
            r'Date[:\s]+(\d{4}-\d{2}-\d{2})',
            r'Updated[:\s]+(\d{4}-\d{2}-\d{2})'
        ]
        
        for pattern in date_patterns:
            match = re.search(pattern, content)
            if match:
                return match.group(1)
        
        return datetime.now().strftime('%Y-%m-%d')
    
    def _generate_merged_content(self, sections: List[Dict], metadata: Dict) -> str:
        """Generate merged markdown content."""
        content = f"""# FKS Project Status

**Last Updated**: {metadata['merged_date']}  
**Merged From**: {', '.join(metadata['merged_from'])}

---

## Overview

This document consolidates status information from multiple sources to provide a single source of truth for project status.

---

"""
        
        # Add sections from each source
        for section_data in sections:
            content += f"## From {section_data['source']}\n\n"
            content += f"**Date**: {section_data['date']}\n\n"
            
            for heading, text in section_data['content'].items():
                if text.strip():
                    content += f"{heading}\n\n{text}\n\n"
            
            content += "---\n\n"
        
        # Add metadata footer
        content += f"""
## Merge Metadata

- **Merged Date**: {metadata['merged_date']}
- **Source Files**: {len(metadata['merged_from'])}
- **Files Merged**: {', '.join(metadata['merged_from'])}
"""
        
        return content
    
    def process_audit_report(self, audit_file: str):
        """Process audit report and merge redundant files."""
        with open(audit_file, 'r', encoding='utf-8') as f:
            audit = json.load(f)
        
        # Merge status files
        status_files = audit.get('redundant_status', [])
        if status_files:
            print(f"\nMerging {len(status_files)} status files...")
            self.merge_status_files(status_files)
        
        # Process other recommendations
        for rec in audit.get('recommendations', []):
            if rec['action'] == 'merge':
                print(f"\nProcessing merge recommendation: {rec['description']}")
                # Additional merge logic here


def main():
    parser = argparse.ArgumentParser(description='Merge redundant documentation files')
    parser.add_argument('--audit-report', required=True, help='Audit report JSON file')
    parser.add_argument('--docs-dir', default='repo/main/docs', help='Documentation directory')
    parser.add_argument('--dry-run', action='store_true', help='Dry run mode (no changes)')
    
    args = parser.parse_args()
    
    merger = DocsMerger(args.docs_dir, dry_run=args.dry_run)
    merger.process_audit_report(args.audit_report)
    
    print(f"\nSummary:")
    print(f"  Files merged: {len(merger.merged_files)}")
    print(f"  Files deleted: {len(merger.deleted_files)}")
    
    return 0


if __name__ == '__main__':
    exit(main())

