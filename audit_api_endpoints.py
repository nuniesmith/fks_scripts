#!/usr/bin/env python3
"""Audit API endpoints for authentication and rate limiting status.

This script scans all API route files and catalogs endpoints with their
security requirements.
"""
import ast
import re
from pathlib import Path
from typing import Dict, List, Tuple
from dataclasses import dataclass, field

@dataclass
class Endpoint:
    """Represents an API endpoint."""
    method: str
    path: str
    route_file: str
    line_number: int
    has_auth: bool = False
    has_rate_limit: bool = False
    auth_type: str = ""
    rate_limit_value: str = ""
    tags: List[str] = field(default_factory=list)
    description: str = ""

def find_route_decorators(file_path: Path) -> List[Endpoint]:
    """Find all route decorators in a Python file."""
    endpoints = []
    
    try:
        with open(file_path, 'r', encoding='utf-8') as f:
            content = f.read()
            lines = content.split('\n')
            
        # Find all @router. or @app. decorators
        pattern = r'@(?:router|app)\.(get|post|put|delete|patch)\s*\(([^)]+)\)'
        
        for line_num, line in enumerate(lines, 1):
            match = re.search(pattern, line)
            if match:
                method = match.group(1).upper()
                params = match.group(2)
                
                # Extract path
                path_match = re.search(r'["\']([^"\']+)["\']', params)
                path = path_match.group(1) if path_match else ""
                
                # Check for auth dependencies
                has_auth = 'Depends' in params or 'Security' in params or 'get_current_user' in params
                
                # Check for rate limiting
                has_rate_limit = 'rate_limit' in params.lower() or 'RateLimit' in params
                
                # Extract tags
                tags_match = re.search(r'tags\s*=\s*\[([^\]]+)\]', params)
                tags = []
                if tags_match:
                    tags_str = tags_match.group(1)
                    tags = [t.strip().strip('"\'') for t in tags_str.split(',')]
                
                endpoints.append(Endpoint(
                    method=method,
                    path=path,
                    route_file=str(file_path.relative_to(Path.cwd())),
                    line_number=line_num,
                    has_auth=has_auth,
                    has_rate_limit=has_rate_limit,
                    tags=tags
                ))
    except Exception as e:
        print(f"Error parsing {file_path}: {e}")
    
    return endpoints

def categorize_endpoint(endpoint: Endpoint) -> Tuple[str, str]:
    """Categorize endpoint by security requirements.
    
    Returns: (category, recommended_auth_level)
    """
    path = endpoint.path.lower()
    method = endpoint.method.upper()
    
    # Public endpoints (no auth needed)
    if any(x in path for x in ['/health', '/status', '/info', '/metrics', '/docs', '/openapi']):
        return "Public", "None"
    
    # Critical endpoints (must have auth)
    if any(x in path for x in ['/trading', '/orders', '/execution', '/positions', '/portfolio']):
        return "Critical", "Required"
    
    # Sensitive endpoints (should have auth)
    if any(x in path for x in ['/signals', '/backtest', '/admin', '/config', '/webhooks']):
        return "Sensitive", "Recommended"
    
    # Data endpoints (rate limit recommended)
    if any(x in path for x in ['/data', '/price', '/ohlcv', '/providers']):
        return "Data", "Optional"
    
    # Analysis endpoints (auth recommended)
    if any(x in path for x in ['/analyze', '/predict', '/ml', '/ai']):
        return "Analysis", "Recommended"
    
    # Default: moderate security
    return "Standard", "Optional"

def audit_services(base_path: Path) -> Dict[str, List[Endpoint]]:
    """Audit all services for API endpoints."""
    services_endpoints = {}
    
    # Find all route files
    route_patterns = [
        "**/routes/**/*.py",
        "**/api/routes/**/*.py",
        "**/src/api/routes/**/*.py",
    ]
    
    route_files = []
    for pattern in route_patterns:
        route_files.extend(base_path.glob(pattern))
    
    # Filter out __pycache__ and __init__.py files
    route_files = [f for f in route_files if '__pycache__' not in str(f) and f.name != '__init__.py']
    
    print(f"Found {len(route_files)} route files to audit...")
    
    for route_file in route_files:
        # Determine service name
        parts = route_file.parts
        service_name = "unknown"
        for part in parts:
            if part in ['services', 'api', 'app', 'data', 'portfolio', 'ai', 'training']:
                service_name = part
                break
        
        endpoints = find_route_decorators(route_file)
        if endpoints:
            if service_name not in services_endpoints:
                services_endpoints[service_name] = []
            services_endpoints[service_name].extend(endpoints)
    
    return services_endpoints

def generate_report(services_endpoints: Dict[str, List[Endpoint]]) -> str:
    """Generate security audit report."""
    report = []
    report.append("# API Endpoint Security Audit Report\n")
    report.append(f"**Generated**: {Path(__file__).stat().st_mtime}\n")
    report.append("---\n\n")
    
    # Summary statistics
    total_endpoints = sum(len(eps) for eps in services_endpoints.values())
    endpoints_with_auth = sum(
        sum(1 for ep in eps if ep.has_auth)
        for eps in services_endpoints.values()
    )
    endpoints_with_rate_limit = sum(
        sum(1 for ep in eps if ep.has_rate_limit)
        for eps in services_endpoints.values()
    )
    
    report.append("## Summary Statistics\n\n")
    report.append(f"- **Total Endpoints**: {total_endpoints}\n")
    report.append(f"- **Endpoints with Auth**: {endpoints_with_auth} ({endpoints_with_auth/total_endpoints*100:.1f}%)\n")
    report.append(f"- **Endpoints with Rate Limiting**: {endpoints_with_rate_limit} ({endpoints_with_rate_limit/total_endpoints*100:.1f}%)\n\n")
    
    # Service breakdown
    report.append("## Service Breakdown\n\n")
    for service, endpoints in sorted(services_endpoints.items()):
        report.append(f"### {service.upper()} Service\n\n")
        report.append(f"- **Total Endpoints**: {len(endpoints)}\n")
        report.append(f"- **With Auth**: {sum(1 for ep in endpoints if ep.has_auth)}\n")
        report.append(f"- **With Rate Limit**: {sum(1 for ep in endpoints if ep.has_rate_limit)}\n\n")
        
        # Categorize endpoints
        categories = {}
        for endpoint in endpoints:
            category, auth_level = categorize_endpoint(endpoint)
            if category not in categories:
                categories[category] = []
            categories[category].append((endpoint, auth_level))
        
        # Report by category
        for category in ["Critical", "Sensitive", "Analysis", "Data", "Standard", "Public"]:
            if category in categories:
                report.append(f"#### {category} Endpoints ({len(categories[category])})\n\n")
                report.append("| Method | Path | Auth Status | Rate Limit | Recommendation |\n")
                report.append("|--------|------|-------------|------------|----------------|\n")
                
                for endpoint, auth_level in sorted(categories[category], key=lambda x: x[0].path):
                    auth_status = "✅ Yes" if endpoint.has_auth else "❌ No"
                    rate_status = "✅ Yes" if endpoint.has_rate_limit else "❌ No"
                    recommendation = auth_level
                    
                    if category == "Critical" and not endpoint.has_auth:
                        recommendation = "🔴 REQUIRED"
                    elif category == "Sensitive" and not endpoint.has_auth:
                        recommendation = "🟡 Recommended"
                    
                    report.append(f"| {endpoint.method} | `{endpoint.path}` | {auth_status} | {rate_status} | {recommendation} |\n")
                report.append("\n")
    
    return "".join(report)

def main():
    """Main audit function."""
    repo_root = Path(__file__).parent.parent.parent
    services_path = repo_root / "services"
    
    if not services_path.exists():
        print(f"Error: Services directory not found at {services_path}")
        return 1
    
    print("Starting API endpoint security audit...")
    services_endpoints = audit_services(services_path)
    
    report = generate_report(services_endpoints)
    
    # Save report
    report_path = repo_root / "infrastructure" / "docs" / "API_ENDPOINT_SECURITY_AUDIT.md"
    report_path.parent.mkdir(parents=True, exist_ok=True)
    
    with open(report_path, 'w') as f:
        f.write(report)
    
    print(f"\n✅ Audit complete! Report saved to: {report_path}")
    print(f"\nSummary:")
    total = sum(len(eps) for eps in services_endpoints.values())
    print(f"  - Total endpoints found: {total}")
    print(f"  - Services audited: {len(services_endpoints)}")
    
    return 0

if __name__ == "__main__":
    exit(main())
