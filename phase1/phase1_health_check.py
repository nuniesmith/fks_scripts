#!/usr/bin/env python3
"""
Phase 1: Health Check Assessment Script
Tests existing health endpoints and identifies repos lacking health probes.
"""

import os
import json
import requests
import subprocess
from pathlib import Path
from typing import Dict, List, Any, Optional
from datetime import datetime
from collections import defaultdict

# Base path to FKS repos
# Get repo/ directory (5 levels up from scripts/phase1/)
BASE_PATH = Path(__file__).parent.parent.parent.parent.parent  # repo/

# Service ports (if running locally)
SERVICE_PORTS = {
    "api": 8001,
    "app": 8002,
    "data": 8003,
    "execution": 8006,
    "web": 8000,
    "ai": 8007,
    "analyze": 8008,
    "monitor": 8009
}

# Health endpoint patterns
HEALTH_PATTERNS = ["/health", "/healthz", "/ping", "/ready", "/live"]


class HealthChecker:
    """Checks health endpoints for services."""
    
    def __init__(self, service_name: str, repo_path: Path):
        self.service_name = service_name
        self.repo_path = repo_path
        self.findings = []
        self.endpoints_found = []
        self.endpoints_tested = []
    
    def check_code_for_endpoints(self) -> List[str]:
        """Search code for health endpoint definitions."""
        endpoints = []
        python_files = list(self.repo_path.rglob("*.py"))
        
        for py_file in python_files[:100]:  # Limit for performance
            try:
                content = py_file.read_text()
                
                # Check for FastAPI routes
                if "@app.get" in content or "@router.get" in content:
                    for pattern in HEALTH_PATTERNS:
                        if pattern in content:
                            endpoints.append(pattern)
                
                # Check for Flask routes
                if "@app.route" in content:
                    for pattern in HEALTH_PATTERNS:
                        if pattern in content:
                            endpoints.append(pattern)
                
                # Check for Django URLs
                if "path(" in content or "url(" in content:
                    for pattern in HEALTH_PATTERNS:
                        if pattern in content:
                            endpoints.append(pattern)
            except:
                continue
        
        return list(set(endpoints))
    
    def test_endpoint(self, endpoint: str, port: Optional[int] = None) -> Dict[str, Any]:
        """Test a health endpoint."""
        if port is None:
            port = SERVICE_PORTS.get(self.service_name)
        
        if port is None:
            return {
                "endpoint": endpoint,
                "tested": False,
                "reason": "Port not configured"
            }
        
        url = f"http://localhost:{port}{endpoint}"
        
        try:
            response = requests.get(url, timeout=2)
            return {
                "endpoint": endpoint,
                "url": url,
                "tested": True,
                "status_code": response.status_code,
                "response_time_ms": round(response.elapsed.total_seconds() * 1000, 2),
                "healthy": response.status_code == 200,
                "response_body": response.text[:200] if response.text else None
            }
        except requests.exceptions.ConnectionError:
            return {
                "endpoint": endpoint,
                "url": url,
                "tested": True,
                "status_code": None,
                "healthy": False,
                "reason": "Service not running"
            }
        except Exception as e:
            return {
                "endpoint": endpoint,
                "url": url,
                "tested": True,
                "status_code": None,
                "healthy": False,
                "reason": str(e)
            }
    
    def assess(self) -> Dict[str, Any]:
        """Run complete health check assessment."""
        print(f"Assessing health checks for {self.service_name}...")
        
        if not self.repo_path.exists():
            return {
                "service": self.service_name,
                "path": str(self.repo_path),
                "exists": False,
                "error": "Repository not found"
            }
        
        # Find endpoints in code
        endpoints_in_code = self.check_code_for_endpoints()
        
        # Test endpoints if service is running
        endpoints_tested = []
        if endpoints_in_code:
            for endpoint in endpoints_in_code:
                test_result = self.test_endpoint(endpoint)
                endpoints_tested.append(test_result)
        else:
            # Try common endpoints even if not found in code
            for pattern in ["/health", "/healthz", "/ping"]:
                test_result = self.test_endpoint(pattern)
                if test_result.get("tested") and test_result.get("healthy"):
                    endpoints_tested.append(test_result)
                    break
        
        # Determine if health checks are missing
        has_health_endpoint = len(endpoints_in_code) > 0
        has_working_endpoint = any(t.get("healthy") for t in endpoints_tested)
        
        recommendations = []
        if not has_health_endpoint:
            recommendations.append({
                "priority": "High",
                "issue": "No health endpoint found in code",
                "recommendation": "Add /health endpoint with liveness and readiness probes"
            })
        elif not has_working_endpoint:
            recommendations.append({
                "priority": "Medium",
                "issue": "Health endpoint found but not responding",
                "recommendation": "Ensure service is running and endpoint is accessible"
            })
        
        # Check for liveness vs readiness
        has_liveness = any("/live" in e or "/healthz" in e for e in endpoints_in_code)
        has_readiness = any("/ready" in e or "/health" in e for e in endpoints_in_code)
        
        if has_health_endpoint and not (has_liveness and has_readiness):
            recommendations.append({
                "priority": "Medium",
                "issue": "Missing separate liveness/readiness probes",
                "recommendation": "Implement separate /live (liveness) and /ready (readiness) endpoints"
            })
        
        return {
            "service": self.service_name,
            "path": str(self.repo_path),
            "exists": True,
            "endpoints_in_code": endpoints_in_code,
            "endpoints_tested": endpoints_tested,
            "has_health_endpoint": has_health_endpoint,
            "has_working_endpoint": has_working_endpoint,
            "has_liveness": has_liveness,
            "has_readiness": has_readiness,
            "recommendations": recommendations
        }


def assess_all_services() -> Dict[str, Any]:
    """Assess health checks for all services."""
    results = {
        "timestamp": datetime.utcnow().isoformat(),
        "services": {},
        "summary": {
            "total_services": 0,
            "services_with_endpoints": 0,
            "services_with_working_endpoints": 0,
            "services_missing_endpoints": 0,
            "total_recommendations": 0
        }
    }
    
    # Services to check
    services_to_check = {
        "api": BASE_PATH / "core" / "api",
        "app": BASE_PATH / "core" / "app",
        "data": BASE_PATH / "core" / "data",
        "execution": BASE_PATH / "core" / "execution",
        "web": BASE_PATH / "core" / "web",
        "ai": BASE_PATH / "gpu" / "ai",
        "analyze": BASE_PATH / "tools" / "analyze",
        "monitor": BASE_PATH / "core" / "monitor"
    }
    
    for service_name, repo_path in services_to_check.items():
        checker = HealthChecker(service_name, repo_path)
        assessment = checker.assess()
        
        results["services"][service_name] = assessment
        results["summary"]["total_services"] += 1
        
        if assessment.get("exists"):
            if assessment.get("has_health_endpoint"):
                results["summary"]["services_with_endpoints"] += 1
            else:
                results["summary"]["services_missing_endpoints"] += 1
            
            if assessment.get("has_working_endpoint"):
                results["summary"]["services_with_working_endpoints"] += 1
            
            results["summary"]["total_recommendations"] += len(assessment.get("recommendations", []))
    
    return results


def generate_health_report(results: Dict[str, Any], output_file: str = "phase1_health_report.json"):
    """Generate health check report."""
    output_path = Path(output_file)
    
    # Save JSON
    with open(output_path, "w") as f:
        json.dump(results, f, indent=2)
    
    # Generate markdown report
    md_path = output_path.with_suffix(".md")
    with open(md_path, "w") as f:
        f.write("# Phase 1: Health Check Assessment Report\n\n")
        f.write(f"**Generated**: {results['timestamp']}\n\n")
        
        # Summary
        f.write("## Summary\n\n")
        summary = results["summary"]
        f.write(f"- **Total Services**: {summary['total_services']}\n")
        f.write(f"- **Services with Health Endpoints**: {summary['services_with_endpoints']}\n")
        f.write(f"- **Services with Working Endpoints**: {summary['services_with_working_endpoints']}\n")
        f.write(f"- **Services Missing Endpoints**: {summary['services_missing_endpoints']}\n")
        f.write(f"- **Total Recommendations**: {summary['total_recommendations']}\n\n")
        
        # Detailed findings
        f.write("## Detailed Findings\n\n")
        for service_name, service_data in results["services"].items():
            if not service_data.get("exists"):
                continue
            
            f.write(f"### {service_name}\n\n")
            f.write(f"**Path**: {service_data['path']}\n\n")
            
            # Endpoints
            endpoints = service_data.get("endpoints_in_code", [])
            if endpoints:
                f.write("**Endpoints Found in Code**:\n")
                for endpoint in endpoints:
                    f.write(f"- `{endpoint}`\n")
                f.write("\n")
            else:
                f.write("**Endpoints Found in Code**: None\n\n")
            
            # Test results
            tested = service_data.get("endpoints_tested", [])
            if tested:
                f.write("**Endpoint Test Results**:\n")
                for test in tested:
                    status = "✅" if test.get("healthy") else "❌"
                    f.write(f"- {status} `{test.get('endpoint', 'unknown')}`")
                    if test.get("url"):
                        f.write(f" ({test['url']})")
                    if test.get("status_code"):
                        f.write(f" - Status: {test['status_code']}")
                    if test.get("response_time_ms"):
                        f.write(f" - Response: {test['response_time_ms']}ms")
                    if test.get("reason"):
                        f.write(f" - {test['reason']}")
                    f.write("\n")
                f.write("\n")
            
            # Recommendations
            recommendations = service_data.get("recommendations", [])
            if recommendations:
                f.write("**Recommendations**:\n")
                for rec in recommendations:
                    priority_emoji = "🔴" if rec["priority"] == "High" else "🟡"
                    f.write(f"- {priority_emoji} **{rec['priority']}**: {rec['issue']}\n")
                    f.write(f"  - {rec['recommendation']}\n")
                f.write("\n")
            
            f.write("---\n\n")
        
        # Failure points mapping
        f.write("## Potential Failure Points\n\n")
        f.write("Based on the assessment, here are potential failure points:\n\n")
        f.write("1. **Database Connections**: Services that depend on PostgreSQL/Redis\n")
        f.write("2. **Inter-Service Communication**: Services calling other FKS services\n")
        f.write("3. **External APIs**: Services calling external APIs (exchanges, data providers)\n")
        f.write("4. **Missing Health Checks**: Services without health endpoints cannot be monitored\n\n")
    
    print(f"\n✅ Health check assessment complete!")
    print(f"📄 JSON report: {output_path}")
    print(f"📄 Markdown report: {md_path}")


def main():
    """Main entry point."""
    print("🏥 Starting Phase 1: Health Check Assessment\n")
    print("=" * 60)
    
    results = assess_all_services()
    generate_health_report(results)
    
    # Print summary
    print("\n" + "=" * 60)
    print("📊 Health Check Summary")
    print("=" * 60)
    summary = results["summary"]
    print(f"Total Services: {summary['total_services']}")
    print(f"Services with Health Endpoints: {summary['services_with_endpoints']}")
    print(f"Services with Working Endpoints: {summary['services_with_working_endpoints']}")
    print(f"Services Missing Endpoints: {summary['services_missing_endpoints']}")
    print(f"Total Recommendations: {summary['total_recommendations']}")


if __name__ == "__main__":
    main()

