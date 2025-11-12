#!/usr/bin/env python3
"""
FKS Source Code Structure Analysis
Identifies dead code, redundancy, and optimization opportunities for microservices
Enhanced with JSON output including file metadata (size, last_modified)
"""

import os
import ast
from pathlib import Path
from collections import defaultdict
import json
from datetime import datetime

class SourceAnalyzer:
    def __init__(self, root_path):
        self.root = Path(root_path)
        self.services = {}
        self.shared_code = defaultdict(list)
        self.imports = defaultdict(set)
        self.unused_files = []
        self.duplicates = defaultdict(list)
        self.all_files = []  # Track all files with metadata
        
    def analyze(self):
        """Run full analysis"""
        print("🔍 Analyzing FKS source code structure...\n")
        
        # Scan all files first
        self.scan_all_files()
        
        # Analyze services
        self.analyze_services()
        
        # Analyze shared code
        self.analyze_shared_code()
        
        # Find imports
        self.analyze_imports()
        
        # Find duplicates
        self.find_duplicates()
        
        # Generate report
        self.generate_report()
    
    def scan_all_files(self):
        """Scan all files and collect metadata"""
        print("📁 Scanning all files in workspace...\n")
        
        workspace_root = self.root.parent  # Go up from src to workspace root
        
        for file_path in workspace_root.rglob("*"):
            if file_path.is_file():
                # Skip common ignore patterns
                skip_patterns = [
                    '__pycache__', '.git', '.pytest_cache', 
                    'node_modules', '.venv', 'venv', '.mypy_cache',
                    '.ruff_cache', 'dist', 'build', '*.pyc'
                ]
                
                if any(pattern in str(file_path) for pattern in skip_patterns):
                    continue
                
                try:
                    stat_info = file_path.stat()
                    rel_path = str(file_path.relative_to(workspace_root))
                    
                    file_info = {
                        'path': rel_path,
                        'absolute_path': str(file_path),
                        'size': stat_info.st_size,
                        'last_modified': datetime.fromtimestamp(stat_info.st_mtime).isoformat(),
                        'extension': file_path.suffix,
                        'is_empty': stat_info.st_size == 0,
                        'is_small': stat_info.st_size < 100,
                        'is_markdown': file_path.suffix == '.md',
                        'is_python': file_path.suffix == '.py'
                    }
                    
                    self.all_files.append(file_info)
                except (PermissionError, OSError):
                    pass
        
        print(f"✅ Found {len(self.all_files)} files\n")
        
    def analyze_services(self):
        """Analyze microservices structure"""
        services_dir = self.root / "services"
        
        for service_dir in services_dir.iterdir():
            if service_dir.is_dir() and not service_dir.name.startswith('.'):
                service_name = service_dir.name
                
                self.services[service_name] = {
                    'path': str(service_dir),
                    'python_files': [],
                    'total_lines': 0,
                    'has_tests': False,
                    'has_dockerfile': False,
                    'has_requirements': False,
                    'structure': {}
                }
                
                # Count Python files
                for py_file in service_dir.rglob("*.py"):
                    if '__pycache__' not in str(py_file) and 'migrations' not in str(py_file):
                        self.services[service_name]['python_files'].append(str(py_file.relative_to(self.root)))
                        try:
                            with open(py_file) as f:
                                lines = len(f.readlines())
                                self.services[service_name]['total_lines'] += lines
                        except:
                            pass
                
                # Check for tests
                if (service_dir / "tests").exists() or (service_dir / "test").exists():
                    self.services[service_name]['has_tests'] = True
                
                # Check for Dockerfile
                dockerfile_path = self.root.parent / "docker" / f"Dockerfile.{service_name}"
                if dockerfile_path.exists():
                    self.services[service_name]['has_dockerfile'] = True
                
                # Check for requirements
                if (service_dir / "requirements.txt").exists():
                    self.services[service_name]['has_requirements'] = True
                    
    def analyze_shared_code(self):
        """Analyze shared code outside services"""
        shared_dirs = ['authentication', 'config', 'core', 'framework', 'monitor']
        
        for shared_dir in shared_dirs:
            dir_path = self.root / shared_dir
            if dir_path.exists():
                files = []
                total_lines = 0
                
                for py_file in dir_path.rglob("*.py"):
                    if '__pycache__' not in str(py_file) and 'migrations' not in str(py_file):
                        rel_path = str(py_file.relative_to(self.root))
                        files.append(rel_path)
                        
                        try:
                            with open(py_file) as f:
                                total_lines += len(f.readlines())
                        except:
                            pass
                
                self.shared_code[shared_dir] = {
                    'files': files,
                    'total_lines': total_lines,
                    'file_count': len(files)
                }
    
    def analyze_imports(self):
        """Analyze import patterns to find cross-dependencies"""
        for py_file in self.root.rglob("*.py"):
            if '__pycache__' in str(py_file) or 'migrations' in str(py_file):
                continue
                
            try:
                with open(py_file) as f:
                    tree = ast.parse(f.read(), filename=str(py_file))
                    
                for node in ast.walk(tree):
                    if isinstance(node, ast.Import):
                        for alias in node.names:
                            self.imports[str(py_file.relative_to(self.root))].add(alias.name.split('.')[0])
                    elif isinstance(node, ast.ImportFrom):
                        if node.module:
                            self.imports[str(py_file.relative_to(self.root))].add(node.module.split('.')[0])
            except:
                pass
    
    def find_duplicates(self):
        """Find duplicate or similar code patterns"""
        # Simple duplicate detection by file size and name patterns
        file_info = {}
        
        for py_file in self.root.rglob("*.py"):
            if '__pycache__' in str(py_file) or 'migrations' in str(py_file):
                continue
            
            try:
                size = py_file.stat().st_size
                name = py_file.name
                
                key = f"{name}_{size}"
                if key not in file_info:
                    file_info[key] = []
                file_info[key].append(str(py_file.relative_to(self.root)))
            except:
                pass
        
        # Find duplicates
        for key, files in file_info.items():
            if len(files) > 1:
                self.duplicates[key] = files
    
    def generate_report(self):
        """Generate comprehensive report"""
        print("=" * 80)
        print("📊 FKS SOURCE CODE ANALYSIS REPORT")
        print("=" * 80)
        print()
        
        # Services Overview
        print("🏗️  MICROSERVICES OVERVIEW")
        print("-" * 80)
        print(f"{'Service':<20} {'Files':<10} {'Lines':<10} {'Tests':<8} {'Docker':<8}")
        print("-" * 80)
        
        total_service_files = 0
        total_service_lines = 0
        
        for service, info in sorted(self.services.items()):
            files = len(info['python_files'])
            lines = info['total_lines']
            tests = "✅" if info['has_tests'] else "❌"
            docker = "✅" if info['has_dockerfile'] else "❌"
            
            print(f"{service:<20} {files:<10} {lines:<10} {tests:<8} {docker:<8}")
            total_service_files += files
            total_service_lines += lines
        
        print("-" * 80)
        print(f"{'TOTAL':<20} {total_service_files:<10} {total_service_lines:<10}")
        print()
        
        # Shared Code Overview
        print("📦 SHARED CODE OVERVIEW")
        print("-" * 80)
        print(f"{'Module':<20} {'Files':<10} {'Lines':<10}")
        print("-" * 80)
        
        total_shared_files = 0
        total_shared_lines = 0
        
        for module, info in sorted(self.shared_code.items()):
            files = info['file_count']
            lines = info['total_lines']
            
            print(f"{module:<20} {files:<10} {lines:<10}")
            total_shared_files += files
            total_shared_lines += lines
        
        print("-" * 80)
        print(f"{'TOTAL':<20} {total_shared_files:<10} {total_shared_lines:<10}")
        print()
        
        # Summary
        print("📈 SUMMARY")
        print("-" * 80)
        print(f"Total Python files:     {total_service_files + total_shared_files}")
        print(f"Total lines of code:    {total_service_lines + total_shared_lines:,}")
        print(f"Microservices:          {len(self.services)}")
        print(f"Shared modules:         {len(self.shared_code)}")
        print()
        
        # Potential Issues
        print("⚠️  POTENTIAL ISSUES")
        print("-" * 80)
        
        issues = []
        
        # Services without tests
        no_tests = [s for s, info in self.services.items() if not info['has_tests']]
        if no_tests:
            issues.append(f"Services without tests: {', '.join(no_tests)}")
        
        # Services without Dockerfile
        no_docker = [s for s, info in self.services.items() if not info['has_dockerfile']]
        if no_docker:
            issues.append(f"Services without Dockerfile: {', '.join(no_docker)}")
        
        # Duplicate files
        if self.duplicates:
            issues.append(f"Potential duplicate files: {len(self.duplicates)}")
        
        if issues:
            for issue in issues:
                print(f"• {issue}")
        else:
            print("✅ No major issues found!")
        
        print()
        
        # Recommendations
        print("💡 OPTIMIZATION RECOMMENDATIONS")
        print("-" * 80)
        
        recommendations = []
        
        # Check for oversized shared modules
        for module, info in self.shared_code.items():
            if info['total_lines'] > 2000:
                recommendations.append(
                    f"• Consider splitting '{module}' module ({info['total_lines']} lines) "
                    f"into smaller, more focused modules"
                )
        
        # Check for small services that could be merged
        small_services = [(s, info) for s, info in self.services.items() 
                         if info['total_lines'] < 500]
        if len(small_services) > 1:
            service_names = [s[0] for s in small_services]
            recommendations.append(
                f"• Consider merging small services ({', '.join(service_names)}) "
                f"if they share similar functionality"
            )
        
        # Cross-service imports (anti-pattern for microservices)
        cross_imports = self.find_cross_service_imports()
        if cross_imports:
            recommendations.append(
                f"• Found {len(cross_imports)} cross-service imports (anti-pattern). "
                f"Services should communicate via APIs, not direct imports"
            )
        
        # Shared code that could be in a service
        large_shared = [(m, info) for m, info in self.shared_code.items() 
                       if info['total_lines'] > 1000]
        if large_shared:
            for module, info in large_shared:
                recommendations.append(
                    f"• '{module}' has {info['total_lines']} lines. "
                    f"Consider if it should be a separate service"
                )
        
        if recommendations:
            for rec in recommendations:
                print(rec)
        else:
            print("✅ Code structure looks well-optimized!")
        
        print()
        print("=" * 80)
        
        # Save detailed report
        self.save_detailed_report()
    
    def find_cross_service_imports(self):
        """Find imports between services (anti-pattern)"""
        cross_imports = []
        
        for file_path, imports in self.imports.items():
            # Check if file is in a service
            if 'services/' in file_path:
                service_name = file_path.split('services/')[1].split('/')[0]
                
                # Check if it imports from another service
                for imp in imports:
                    if imp == 'services':
                        # Direct services import - need to check deeper
                        cross_imports.append({
                            'from': file_path,
                            'service': service_name,
                            'imports': imp
                        })
        
        return cross_imports
    
    def save_detailed_report(self):
        """Save detailed JSON report"""
        report_path = self.root.parent / "docs" / "SRC_STRUCTURE_ANALYSIS.json"
        
        # Categorize files
        empty_files = [f for f in self.all_files if f['is_empty']]
        small_files = [f for f in self.all_files if f['is_small'] and not f['is_empty']]
        md_files = [f for f in self.all_files if f['is_markdown']]
        py_files = [f for f in self.all_files if f['is_python']]
        
        report = {
            'generated_at': datetime.now().isoformat(),
            'services': self.services,
            'shared_code': dict(self.shared_code),
            'duplicates': dict(self.duplicates),
            'cross_imports': self.find_cross_service_imports(),
            'file_inventory': {
                'all_files': self.all_files,
                'total_count': len(self.all_files),
                'empty_files': empty_files,
                'small_files': small_files,
                'markdown_files': md_files,
                'python_files': py_files,
                'counts': {
                    'empty': len(empty_files),
                    'small': len(small_files),
                    'markdown': len(md_files),
                    'python': len(py_files)
                }
            },
            'summary': {
                'total_services': len(self.services),
                'total_shared_modules': len(self.shared_code),
                'total_python_files': sum(len(s['python_files']) for s in self.services.values()) + 
                              sum(info['file_count'] for info in self.shared_code.values()),
                'total_lines': sum(s['total_lines'] for s in self.services.values()) + 
                              sum(info['total_lines'] for info in self.shared_code.values())
            }
        }
        
        with open(report_path, 'w') as f:
            json.dump(report, f, indent=2)
        
        print(f"📄 Detailed report saved to: {report_path}")
        print(f"📊 File Statistics:")
        print(f"   - Total files: {len(self.all_files)}")
        print(f"   - Empty files: {len(empty_files)}")
        print(f"   - Small files (<100 bytes): {len(small_files)}")
        print(f"   - Markdown files: {len(md_files)}")
        print(f"   - Python files: {len(py_files)}")


if __name__ == "__main__":
    analyzer = SourceAnalyzer("/home/jordan/Documents/fks/src")
    analyzer.analyze()
