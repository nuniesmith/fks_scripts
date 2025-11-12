#!/usr/bin/env python3
"""
Phase 1.3: Dependency Audit
Analyzes all dependency files and identifies conflicts
"""

import re
import json
from pathlib import Path
from collections import defaultdict
from datetime import datetime
from typing import Dict, List, Tuple, Set

class DependencyAuditor:
    def __init__(self, root_path: Path):
        self.root = Path(root_path)
        self.dependencies = defaultdict(list)  # package -> [(service, version_spec)]
        self.conflicts = []
        self.services = {}
        
    def analyze(self) -> Dict:
        """Run full dependency analysis"""
        print("Analyzing dependencies across all services...\n")
        
        # Find all dependency files
        requirements_files = list(self.root.rglob("requirements.txt"))
        pyproject_files = list(self.root.rglob("pyproject.toml"))
        cargo_files = list(self.root.rglob("Cargo.toml"))
        
        print(f"Found {len(requirements_files)} requirements.txt files")
        print(f"Found {len(pyproject_files)} pyproject.toml files")
        print(f"Found {len(cargo_files)} Cargo.toml files\n")
        
        # Analyze Python dependencies
        for req_file in requirements_files:
            self._analyze_requirements(req_file)
        
        for pyproject_file in pyproject_files:
            self._analyze_pyproject(pyproject_file)
        
        # Analyze Rust dependencies
        for cargo_file in cargo_files:
            self._analyze_cargo(cargo_file)
        
        # Find conflicts
        self._find_conflicts()
        
        return {
            'dependencies': dict(self.dependencies),
            'conflicts': self.conflicts,
            'services': self.services,
            'summary': self._generate_summary()
        }
    
    def _analyze_requirements(self, file_path: Path):
        """Parse requirements.txt file"""
        service_name = self._get_service_name(file_path)
        if not service_name:
            return
        
        print(f"Analyzing {service_name} requirements.txt...")
        
        try:
            with open(file_path, 'r', encoding='utf-8') as f:
                for line in f:
                    line = line.strip()
                    if not line or line.startswith('#'):
                        continue
                    
                    # Parse package and version
                    match = re.match(r'^([a-zA-Z0-9_-]+[a-zA-Z0-9_.-]*)(.*)$', line.split('#')[0].strip())
                    if match:
                        package = match.group(1).lower()
                        version_spec = match.group(2).strip() or 'any'
                        
                        self.dependencies[package].append({
                            'service': service_name,
                            'file': str(file_path.relative_to(self.root)),
                            'version': version_spec
                        })
        except Exception as e:
            print(f"  Error reading {file_path}: {e}")
    
    def _analyze_pyproject(self, file_path: Path):
        """Parse pyproject.toml file"""
        service_name = self._get_service_name(file_path)
        if not service_name:
            return
        
        print(f"Analyzing {service_name} pyproject.toml...")
        
        try:
            import tomli  # Python 3.11+ has tomllib, but tomli is more compatible
            try:
                with open(file_path, 'rb') as f:
                    data = tomli.load(f)
            except ImportError:
                # Fallback to manual parsing for basic cases
                with open(file_path, 'r', encoding='utf-8') as f:
                    content = f.read()
                    # Simple regex-based parsing
                    deps_section = re.search(r'dependencies\s*=\s*\[(.*?)\]', content, re.DOTALL)
                    if deps_section:
                        deps_text = deps_section.group(1)
                        for dep in re.findall(r'"([^"]+)"', deps_text):
                            package, version = self._parse_dependency_string(dep)
                            self.dependencies[package].append({
                                'service': service_name,
                                'file': str(file_path.relative_to(self.root)),
                                'version': version
                            })
        except Exception as e:
            print(f"  Error reading {file_path}: {e}")
    
    def _analyze_cargo(self, file_path: Path):
        """Parse Cargo.toml file (basic parsing)"""
        service_name = self._get_service_name(file_path)
        if not service_name:
            return
        
        print(f"Analyzing {service_name} Cargo.toml...")
        
        try:
            with open(file_path, 'r', encoding='utf-8') as f:
                content = f.read()
                # Look for dependencies section
                deps_match = re.search(r'\[dependencies\](.*?)(?=\[|$)', content, re.DOTALL)
                if deps_match:
                    deps_text = deps_match.group(1)
                    for line in deps_text.split('\n'):
                        line = line.strip()
                        if not line or line.startswith('#'):
                            continue
                        # Parse: package = "version" or package = { ... }
                        match = re.match(r'([a-zA-Z0-9_-]+)\s*=\s*"([^"]+)"', line)
                        if match:
                            package = match.group(1)
                            version = match.group(2)
                            self.dependencies[f"rust:{package}"].append({
                                'service': service_name,
                                'file': str(file_path.relative_to(self.root)),
                                'version': version
                            })
        except Exception as e:
            print(f"  Error reading {file_path}: {e}")
    
    def _parse_dependency_string(self, dep_str: str) -> Tuple[str, str]:
        """Parse dependency string like 'package>=1.0.0'"""
        match = re.match(r'^([a-zA-Z0-9_-]+[a-zA-Z0-9_.-]*)(.*)$', dep_str)
        if match:
            return match.group(1).lower(), match.group(2).strip() or 'any'
        return dep_str, 'any'
    
    def _get_service_name(self, file_path: Path) -> str:
        """Extract service name from file path"""
        parts = file_path.parts
        if 'repo' in parts:
            idx = parts.index('repo')
            if idx + 1 < len(parts):
                service = parts[idx + 1]
                if service not in self.services:
                    self.services[service] = {
                        'name': service,
                        'files': []
                    }
                self.services[service]['files'].append(str(file_path.relative_to(self.root)))
                return service
        return None
    
    def _find_conflicts(self):
        """Identify version conflicts"""
        print("\nIdentifying version conflicts...\n")
        
        for package, usages in self.dependencies.items():
            if len(usages) < 2:
                continue  # Only one usage, no conflict possible
            
            versions = [u['version'] for u in usages]
            services = [u['service'] for u in usages]
            
            # Check if versions are compatible
            if not self._versions_compatible(versions):
                self.conflicts.append({
                    'package': package,
                    'services': list(set(services)),
                    'versions': versions,
                    'usages': usages,
                    'severity': self._assess_severity(package, versions)
                })
    
    def _versions_compatible(self, versions: List[str]) -> bool:
        """Check if version specs are compatible"""
        # Simple check: if all are 'any' or same version, compatible
        if len(set(versions)) <= 1:
            return True
        
        # If versions have ranges, check overlap (simplified)
        # This is a basic check - full version resolution would need packaging library
        return False  # Conservative: assume conflict if different
    
    def _assess_severity(self, package: str, versions: List[str]) -> str:
        """Assess conflict severity"""
        # Critical packages that must match
        critical = ['fastapi', 'django', 'pandas', 'numpy', 'torch', 'redis', 'celery']
        
        if any(crit in package.lower() for crit in critical):
            return 'high'
        elif 'rust:' in package:
            return 'medium'  # Rust deps less likely to conflict
        else:
            return 'low'
    
    def _generate_summary(self) -> Dict:
        """Generate summary statistics"""
        total_packages = len(self.dependencies)
        conflicting_packages = len(self.conflicts)
        high_severity = len([c for c in self.conflicts if c['severity'] == 'high'])
        
        return {
            'total_packages': total_packages,
            'conflicting_packages': conflicting_packages,
            'high_severity_conflicts': high_severity,
            'services_analyzed': len(self.services),
            'timestamp': datetime.now().isoformat()
        }
    
    def save_report(self, output_path: Path, results: Dict):
        """Save analysis report"""
        output_path.parent.mkdir(parents=True, exist_ok=True)
        with open(output_path, 'w') as f:
            json.dump(results, f, indent=2)
        print(f"\nReport saved to {output_path}")


def main():
    # Get repo root
    script_dir = Path(__file__).parent
    repo_root = script_dir.parent.parent.parent
    
    auditor = DependencyAuditor(repo_root)
    results = auditor.analyze()
    
    # Print summary
    print("=" * 60)
    print("DEPENDENCY AUDIT SUMMARY")
    print("=" * 60)
    summary = results['summary']
    print(f"Total packages: {summary['total_packages']}")
    print(f"Conflicting packages: {summary['conflicting_packages']}")
    print(f"High severity conflicts: {summary['high_severity_conflicts']}")
    print(f"Services analyzed: {summary['services_analyzed']}")
    print("=" * 60)
    
    # Print conflicts
    if results['conflicts']:
        print("\nCONFLICTS FOUND:\n")
        for conflict in sorted(results['conflicts'], key=lambda x: x['severity'], reverse=True):
            print(f"[{conflict['severity'].upper()}] {conflict['package']}")
            print(f"  Services: {', '.join(conflict['services'])}")
            print(f"  Versions: {', '.join(set(conflict['versions']))}")
            print()
    
    # Save report
    report_path = repo_root / "main" / "docs" / "todo" / "DEPENDENCY_AUDIT.json"
    auditor.save_report(report_path, results)
    
    # Save human-readable summary
    summary_path = repo_root / "main" / "docs" / "todo" / "DEPENDENCY_AUDIT_SUMMARY.md"
    with open(summary_path, 'w') as f:
        f.write("# Dependency Audit Summary\n\n")
        f.write(f"**Date**: {summary['timestamp']}\n\n")
        f.write("## Summary\n\n")
        f.write(f"- **Total Packages**: {summary['total_packages']}\n")
        f.write(f"- **Conflicting Packages**: {summary['conflicting_packages']}\n")
        f.write(f"- **High Severity Conflicts**: {summary['high_severity_conflicts']}\n")
        f.write(f"- **Services Analyzed**: {summary['services_analyzed']}\n\n")
        
        if results['conflicts']:
            f.write("## Conflicts\n\n")
            for conflict in sorted(results['conflicts'], key=lambda x: x['severity'], reverse=True):
                f.write(f"### {conflict['package']} [{conflict['severity'].upper()}]\n\n")
                f.write(f"- **Services**: {', '.join(conflict['services'])}\n")
                f.write(f"- **Versions**: {', '.join(set(conflict['versions']))}\n\n")
    
    print(f"Summary saved to {summary_path}")


if __name__ == "__main__":
    main()

