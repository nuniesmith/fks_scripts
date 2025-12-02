#!/usr/bin/env python3
"""
Phase 1: Repo Audit Script
Conducts comprehensive audit of all FKS repositories for gaps in testing, Docker, health checks, etc.
"""

import os
import json
import subprocess
from pathlib import Path
from typing import Dict, List, Any
from datetime import datetime
from collections import defaultdict

# Base path to FKS repos
# Get repo/ directory (5 levels up from scripts/phase1/)
BASE_PATH = Path(__file__).parent.parent.parent.parent.parent  # repo/

# Repo categories and their expected repos
REPO_CATEGORIES = {
    "core": ["api", "app", "auth", "data", "execution", "main", "monitor", "web"],
    "gpu": ["ai", "training"],
    "plugin": ["ninja", "meta"],
    "tools": ["analyze", "monitor"]
}

# Priority levels
PRIORITY_HIGH = "High"
PRIORITY_MEDIUM = "Medium"
PRIORITY_LOW = "Low"


class RepoAuditor:
    """Audits individual repositories for gaps and issues."""
    
    def __init__(self, repo_path: Path):
        self.repo_path = repo_path
        self.repo_name = repo_path.name
        self.issues = []
        self.metrics = {}
    
    def audit(self) -> Dict[str, Any]:
        """Run complete audit on repository."""
        print(f"Auditing {self.repo_name}...")
        
        # Check if repo exists
        if not self.repo_path.exists():
            return {
                "repo": self.repo_name,
                "path": str(self.repo_path),
                "exists": False,
                "error": "Repository not found"
            }
        
        # Run all checks
        self._check_tests()
        self._check_docker()
        self._check_health_endpoints()
        self._check_dependencies()
        self._check_static_analysis()
        self._check_documentation()
        self._calculate_metrics()
        
        return {
            "repo": self.repo_name,
            "path": str(self.repo_path),
            "exists": True,
            "issues": self.issues,
            "metrics": self.metrics,
            "priority_issues": {
                "high": [i for i in self.issues if i.get("priority") == PRIORITY_HIGH],
                "medium": [i for i in self.issues if i.get("priority") == PRIORITY_MEDIUM],
                "low": [i for i in self.issues if i.get("priority") == PRIORITY_LOW]
            }
        }
    
    def _check_tests(self):
        """Check for test files and test configuration."""
        test_dirs = ["tests", "test", "__tests__", "spec"]
        test_files = list(self.repo_path.rglob("test_*.py")) + \
                     list(self.repo_path.rglob("*_test.py")) + \
                     list(self.repo_path.rglob("*.test.*")) + \
                     list(self.repo_path.rglob("*.spec.*"))
        
        test_dirs_found = [d for d in test_dirs if (self.repo_path / d).exists()]
        
        if not test_files and not test_dirs_found:
            self.issues.append({
                "category": "Testing",
                "type": "No tests found",
                "priority": PRIORITY_HIGH,
                "description": f"No test files or test directories found in {self.repo_name}",
                "recommendation": "Add pytest or appropriate test framework with test files"
            })
        elif len(test_files) < 3:
            self.issues.append({
                "category": "Testing",
                "type": "Limited tests",
                "priority": PRIORITY_MEDIUM,
                "description": f"Only {len(test_files)} test files found",
                "recommendation": "Consider adding more comprehensive test coverage"
            })
        
        # Check for test configuration
        test_configs = ["pytest.ini", "pytest.ini", ".pytestrc", "jest.config.js", "Cargo.toml"]
        has_test_config = any((self.repo_path / config).exists() for config in test_configs)
        if not has_test_config and test_files:
            self.issues.append({
                "category": "Testing",
                "type": "Missing test config",
                "priority": PRIORITY_LOW,
                "description": "Test files found but no test configuration file",
                "recommendation": "Add pytest.ini or appropriate test configuration"
            })
    
    def _check_docker(self):
        """Check for Docker files."""
        dockerfile = self.repo_path / "Dockerfile"
        docker_compose = list(self.repo_path.glob("docker-compose*.yml")) + \
                        list(self.repo_path.glob("docker-compose*.yaml"))
        
        if not dockerfile.exists() and not docker_compose:
            self.issues.append({
                "category": "Docker",
                "type": "Missing Dockerfile",
                "priority": PRIORITY_HIGH,
                "description": f"No Dockerfile or docker-compose.yml found in {self.repo_name}",
                "recommendation": "Add Dockerfile for containerization"
            })
        elif not dockerfile.exists() and docker_compose:
            self.issues.append({
                "category": "Docker",
                "type": "Missing Dockerfile",
                "priority": PRIORITY_MEDIUM,
                "description": "docker-compose.yml found but no Dockerfile",
                "recommendation": "Add Dockerfile for building service image"
            })
        
        # Check for .dockerignore
        dockerignore = self.repo_path / ".dockerignore"
        if dockerfile.exists() and not dockerignore.exists():
            self.issues.append({
                "category": "Docker",
                "type": "Missing .dockerignore",
                "priority": PRIORITY_LOW,
                "description": "Dockerfile exists but no .dockerignore",
                "recommendation": "Add .dockerignore to optimize builds"
            })
    
    def _check_health_endpoints(self):
        """Check for health check endpoints."""
        # Check Python files for health endpoints
        python_files = list(self.repo_path.rglob("*.py"))
        health_patterns = ["/health", "/healthz", "/ping", "health_check", "healthcheck"]
        
        health_found = False
        for py_file in python_files[:50]:  # Limit search for performance
            try:
                content = py_file.read_text()
                if any(pattern in content for pattern in health_patterns):
                    health_found = True
                    break
            except:
                continue
        
        # Check for FastAPI/Flask/Django apps
        app_files = ["main.py", "app.py", "server.py", "wsgi.py", "asgi.py"]
        has_app_file = any((self.repo_path / f).exists() for f in app_files)
        
        if has_app_file and not health_found:
            self.issues.append({
                "category": "Health Checks",
                "type": "Missing health endpoint",
                "priority": PRIORITY_HIGH,
                "description": f"Service appears to be a web service but no health endpoint found",
                "recommendation": "Add /health endpoint with liveness and readiness probes"
            })
        elif not has_app_file and not health_found:
            # Not a web service, lower priority
            self.issues.append({
                "category": "Health Checks",
                "type": "No health endpoint",
                "priority": PRIORITY_LOW,
                "description": "No health endpoint (may not be needed for this service type)",
                "recommendation": "Consider if health checks are needed"
            })
    
    def _check_dependencies(self):
        """Check for dependency files and inter-service dependencies."""
        dep_files = {
            "Python": ["requirements.txt", "pyproject.toml", "setup.py", "Pipfile"],
            "Rust": ["Cargo.toml"],
            "Node": ["package.json"],
            "Go": ["go.mod"]
        }
        
        found_deps = {}
        for lang, files in dep_files.items():
            for file in files:
                if (self.repo_path / file).exists():
                    found_deps[lang] = file
                    break
        
        if not found_deps:
            self.issues.append({
                "category": "Dependencies",
                "type": "Missing dependency file",
                "priority": PRIORITY_HIGH,
                "description": "No dependency management file found",
                "recommendation": "Add requirements.txt, Cargo.toml, or appropriate dependency file"
            })
        
        # Check for inter-service dependencies in config files
        config_files = list(self.repo_path.rglob("*.env*")) + \
                      list(self.repo_path.rglob("*.yaml")) + \
                      list(self.repo_path.rglob("*.yml"))
        
        service_refs = ["fks_api", "fks_data", "fks_app", "fks_ai", "fks_execution", "postgres", "redis"]
        inter_service_deps = []
        for config_file in config_files[:20]:  # Limit for performance
            try:
                content = config_file.read_text()
                for service in service_refs:
                    if service in content:
                        inter_service_deps.append(service)
            except:
                continue
        
        if inter_service_deps:
            self.metrics["inter_service_dependencies"] = list(set(inter_service_deps))
    
    def _check_static_analysis(self):
        """Check for static analysis configuration."""
        analysis_configs = {
            "Python": [".pylintrc", "pylint.ini", "ruff.toml", ".ruff.toml", "mypy.ini", "pyproject.toml"],
            "Rust": [".clippy.toml", "clippy.toml"],
            "JavaScript": [".eslintrc", ".eslintrc.json", ".eslintrc.js"]
        }
        
        has_analysis = False
        for lang, configs in analysis_configs.items():
            if any((self.repo_path / config).exists() for config in configs):
                has_analysis = True
                break
        
        if not has_analysis:
            self.issues.append({
                "category": "Code Quality",
                "type": "Missing static analysis",
                "priority": PRIORITY_MEDIUM,
                "description": "No static analysis configuration found",
                "recommendation": "Add ruff.toml, .pylintrc, or appropriate linter config"
            })
    
    def _check_documentation(self):
        """Check for documentation."""
        readme = self.repo_path / "README.md"
        if not readme.exists():
            self.issues.append({
                "category": "Documentation",
                "type": "Missing README",
                "priority": PRIORITY_MEDIUM,
                "description": "No README.md found",
                "recommendation": "Add README.md with setup and usage instructions"
            })
        else:
            # Check if README is substantial
            try:
                content = readme.read_text()
                if len(content) < 200:
                    self.issues.append({
                        "category": "Documentation",
                        "type": "Minimal README",
                        "priority": PRIORITY_LOW,
                        "description": "README.md exists but is very short",
                        "recommendation": "Expand README with more details"
                    })
            except:
                pass
    
    def _calculate_metrics(self):
        """Calculate repository metrics."""
        # Count files by type
        file_counts = defaultdict(int)
        total_size = 0
        
        for file_path in self.repo_path.rglob("*"):
            if file_path.is_file():
                ext = file_path.suffix or "no_ext"
                file_counts[ext] += 1
                try:
                    total_size += file_path.stat().st_size
                except:
                    pass
        
        self.metrics.update({
            "total_files": sum(file_counts.values()),
            "file_types": dict(file_counts),
            "total_size_bytes": total_size,
            "total_size_mb": round(total_size / (1024 * 1024), 2)
        })


def audit_all_repos() -> Dict[str, Any]:
    """Audit all repositories in the FKS project."""
    results = {
        "timestamp": datetime.utcnow().isoformat(),
        "repos": {},
        "summary": {
            "total_repos": 0,
            "repos_audited": 0,
            "total_issues": 0,
            "high_priority_issues": 0,
            "medium_priority_issues": 0,
            "low_priority_issues": 0
        },
        "issues_by_category": defaultdict(int),
        "issues_by_repo": defaultdict(int)
    }
    
    # Audit each repo category
    for category, repos in REPO_CATEGORIES.items():
        for repo_name in repos:
            repo_path = BASE_PATH / category / repo_name
            if category == "tools" and repo_name == "monitor":
                # tools/monitor might not exist, check core/monitor
                repo_path = BASE_PATH / "core" / "monitor"
            
            auditor = RepoAuditor(repo_path)
            audit_result = auditor.audit()
            
            results["repos"][repo_name] = audit_result
            results["summary"]["total_repos"] += 1
            
            if audit_result.get("exists"):
                results["summary"]["repos_audited"] += 1
                
                # Count issues
                issues = audit_result.get("issues", [])
                results["summary"]["total_issues"] += len(issues)
                
                for issue in issues:
                    priority = issue.get("priority", "Unknown")
                    category = issue.get("category", "Unknown")
                    
                    if priority == PRIORITY_HIGH:
                        results["summary"]["high_priority_issues"] += 1
                    elif priority == PRIORITY_MEDIUM:
                        results["summary"]["medium_priority_issues"] += 1
                    elif priority == PRIORITY_LOW:
                        results["summary"]["low_priority_issues"] += 1
                    
                    results["issues_by_category"][category] += 1
                    results["issues_by_repo"][repo_name] += len(issues)
    
    # Convert defaultdicts to regular dicts for JSON serialization
    results["issues_by_category"] = dict(results["issues_by_category"])
    results["issues_by_repo"] = dict(results["issues_by_repo"])
    
    return results


def generate_report(results: Dict[str, Any], output_file: str = "phase1_audit_report.json"):
    """Generate audit report in JSON and markdown formats."""
    output_path = Path(output_file)
    
    # Save JSON
    with open(output_path, "w") as f:
        json.dump(results, f, indent=2)
    
    # Generate markdown report
    md_path = output_path.with_suffix(".md")
    with open(md_path, "w") as f:
        f.write("# Phase 1: Repository Audit Report\n\n")
        f.write(f"**Generated**: {results['timestamp']}\n\n")
        
        # Summary
        f.write("## Summary\n\n")
        summary = results["summary"]
        f.write(f"- **Total Repos**: {summary['total_repos']}\n")
        f.write(f"- **Repos Audited**: {summary['repos_audited']}\n")
        f.write(f"- **Total Issues**: {summary['total_issues']}\n")
        f.write(f"- **High Priority**: {summary['high_priority_issues']}\n")
        f.write(f"- **Medium Priority**: {summary['medium_priority_issues']}\n")
        f.write(f"- **Low Priority**: {summary['low_priority_issues']}\n\n")
        
        # Issues by category
        f.write("## Issues by Category\n\n")
        for category, count in sorted(results["issues_by_category"].items(), key=lambda x: -x[1]):
            f.write(f"- **{category}**: {count}\n")
        f.write("\n")
        
        # Issues by repo
        f.write("## Issues by Repository\n\n")
        for repo, count in sorted(results["issues_by_repo"].items(), key=lambda x: -x[1]):
            f.write(f"- **{repo}**: {count}\n")
        f.write("\n")
        
        # Detailed repo findings
        f.write("## Detailed Findings\n\n")
        for repo_name, repo_data in results["repos"].items():
            if not repo_data.get("exists"):
                continue
            
            f.write(f"### {repo_name}\n\n")
            f.write(f"**Path**: {repo_data['path']}\n\n")
            
            # Metrics
            if repo_data.get("metrics"):
                metrics = repo_data["metrics"]
                f.write("**Metrics**:\n")
                f.write(f"- Total Files: {metrics.get('total_files', 0)}\n")
                f.write(f"- Total Size: {metrics.get('total_size_mb', 0)} MB\n")
                if "inter_service_dependencies" in metrics:
                    deps = ", ".join(metrics["inter_service_dependencies"])
                    f.write(f"- Inter-Service Dependencies: {deps}\n")
                f.write("\n")
            
            # Issues
            priority_issues = repo_data.get("priority_issues", {})
            if priority_issues.get("high"):
                f.write("#### 🔴 High Priority Issues\n\n")
                for issue in priority_issues["high"]:
                    f.write(f"- **{issue['type']}** ({issue['category']}): {issue['description']}\n")
                    f.write(f"  - Recommendation: {issue['recommendation']}\n")
                f.write("\n")
            
            if priority_issues.get("medium"):
                f.write("#### 🟡 Medium Priority Issues\n\n")
                for issue in priority_issues["medium"]:
                    f.write(f"- **{issue['type']}** ({issue['category']}): {issue['description']}\n")
                    f.write(f"  - Recommendation: {issue['recommendation']}\n")
                f.write("\n")
            
            if priority_issues.get("low"):
                f.write("#### 🟢 Low Priority Issues\n\n")
                for issue in priority_issues["low"]:
                    f.write(f"- **{issue['type']}** ({issue['category']}): {issue['description']}\n")
                    f.write(f"  - Recommendation: {issue['recommendation']}\n")
                f.write("\n")
            
            f.write("---\n\n")
    
    print(f"\n✅ Audit complete!")
    print(f"📄 JSON report: {output_path}")
    print(f"📄 Markdown report: {md_path}")


def main():
    """Main entry point."""
    print("🔍 Starting Phase 1: Repository Audit\n")
    print("=" * 60)
    
    results = audit_all_repos()
    generate_report(results)
    
    # Print summary to console
    print("\n" + "=" * 60)
    print("📊 Audit Summary")
    print("=" * 60)
    summary = results["summary"]
    print(f"Total Repos: {summary['total_repos']}")
    print(f"Repos Audited: {summary['repos_audited']}")
    print(f"Total Issues: {summary['total_issues']}")
    print(f"  🔴 High Priority: {summary['high_priority_issues']}")
    print(f"  🟡 Medium Priority: {summary['medium_priority_issues']}")
    print(f"  🟢 Low Priority: {summary['low_priority_issues']}")
    
    print("\n📋 Top Issues by Category:")
    for category, count in sorted(results["issues_by_category"].items(), key=lambda x: -x[1])[:5]:
        print(f"  - {category}: {count}")
    
    print("\n📋 Top Issues by Repository:")
    for repo, count in sorted(results["issues_by_repo"].items(), key=lambda x: -x[1])[:5]:
        print(f"  - {repo}: {count}")


if __name__ == "__main__":
    main()

