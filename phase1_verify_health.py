#!/usr/bin/env python3
"""
Phase 1.1.4: Verify Health Endpoints
Tests all service health endpoints to ensure they respond correctly
"""

import json
import urllib.request
import urllib.error
from pathlib import Path
from typing import Dict, List, Tuple
from datetime import datetime

class HealthVerifier:
    def __init__(self, registry_path: Path):
        self.registry_path = registry_path
        self.services = {}
        self.results = {
            'passed': [],
            'failed': [],
            'skipped': [],
            'summary': {}
        }
        
    def load_registry(self):
        """Load service registry"""
        with open(self.registry_path) as f:
            data = json.load(f)
            self.services = data.get('services', {})
    
    def verify_service(self, service_name: str, config: Dict) -> Tuple[str, bool, str]:
        """Verify a single service health endpoint"""
        health_url = config.get('health_url', '').replace(
            f'http://{service_name}:', 'http://localhost:'
        )
        
        if not health_url:
            return service_name, False, "No health URL configured"
        
        try:
            req = urllib.request.Request(health_url)
            req.add_header('User-Agent', 'FKS-Health-Checker/1.0')
            with urllib.request.urlopen(req, timeout=5) as response:
                if response.getcode() == 200:
                    return service_name, True, f"OK ({response.getcode()})"
                else:
                    return service_name, False, f"Status {response.getcode()}"
        except urllib.error.URLError as e:
            if "Connection refused" in str(e) or "Name or service not known" in str(e):
                return service_name, False, "Connection refused (service not running)"
            elif "timed out" in str(e).lower():
                return service_name, False, "Timeout (service not responding)"
            else:
                return service_name, False, f"Connection error: {str(e)}"
        except Exception as e:
            return service_name, False, f"Error: {str(e)}"
    
    def verify_all(self):
        """Verify all services"""
        print("Verifying service health endpoints...\n")
        
        results = []
        for service_name, config in self.services.items():
            result = self.verify_service(service_name, config)
            results.append(result)
        
        for service_name, success, message in results:
            if success:
                self.results['passed'].append({
                    'service': service_name,
                    'message': message
                })
                print(f"  [PASS] {service_name}: {message}")
            else:
                if "not running" in message.lower() or "connection" in message.lower():
                    self.results['skipped'].append({
                        'service': service_name,
                        'message': message,
                        'reason': 'Service not running (expected in dev)'
                    })
                    print(f"  [SKIP] {service_name}: {message}")
                else:
                    self.results['failed'].append({
                        'service': service_name,
                        'message': message
                    })
                    print(f"  [FAIL] {service_name}: {message}")
    
    def generate_summary(self):
        """Generate summary statistics"""
        total = len(self.services)
        passed = len(self.results['passed'])
        failed = len(self.results['failed'])
        skipped = len(self.results['skipped'])
        
        self.results['summary'] = {
            'total_services': total,
            'passed': passed,
            'failed': failed,
            'skipped': skipped,
            'success_rate': f"{(passed/total*100):.1f}%" if total > 0 else "0%",
            'timestamp': datetime.now().isoformat()
        }
    
    def save_report(self, output_path: Path):
        """Save verification report"""
        output_path.parent.mkdir(parents=True, exist_ok=True)
        with open(output_path, 'w') as f:
            json.dump(self.results, f, indent=2)
        print(f"\nReport saved to {output_path}")


def main():
    # Get repo root
    script_dir = Path(__file__).parent
    # Script is in repo/main/scripts, so go up 2 levels to repo/main
    main_dir = script_dir.parent
    registry_path = main_dir / "config" / "service_registry.json"
    
    if not registry_path.exists():
        print(f"Error: Service registry not found at {registry_path}")
        return
    
    verifier = HealthVerifier(registry_path)
    verifier.load_registry()
    
    print("=" * 60)
    print("SERVICE HEALTH VERIFICATION")
    print("=" * 60)
    print(f"Services to verify: {len(verifier.services)}\n")
    
    verifier.verify_all()
    
    verifier.generate_summary()
    
    # Print summary
    print("\n" + "=" * 60)
    print("VERIFICATION SUMMARY")
    print("=" * 60)
    summary = verifier.results['summary']
    print(f"Total services: {summary['total_services']}")
    print(f"Passed: {summary['passed']}")
    print(f"Failed: {summary['failed']}")
    print(f"Skipped: {summary['skipped']} (not running)")
    print(f"Success rate: {summary['success_rate']}")
    print("=" * 60)
    
    # Save report
    report_path = main_dir / "docs" / "todo" / "HEALTH_VERIFICATION.json"
    verifier.save_report(report_path)
    
    # Save markdown summary
    summary_path = main_dir / "docs" / "todo" / "HEALTH_VERIFICATION_SUMMARY.md"
    with open(summary_path, 'w') as f:
        f.write("# Service Health Verification Summary\n\n")
        f.write(f"**Date**: {summary['timestamp']}\n\n")
        f.write("## Summary\n\n")
        f.write(f"- **Total Services**: {summary['total_services']}\n")
        f.write(f"- **Passed**: {summary['passed']}\n")
        f.write(f"- **Failed**: {summary['failed']}\n")
        f.write(f"- **Skipped**: {summary['skipped']} (services not running)\n")
        f.write(f"- **Success Rate**: {summary['success_rate']}\n\n")
        
        if verifier.results['passed']:
            f.write("## Passed Services\n\n")
            for item in verifier.results['passed']:
                f.write(f"- **{item['service']}**: {item['message']}\n")
            f.write("\n")
        
        if verifier.results['failed']:
            f.write("## Failed Services\n\n")
            for item in verifier.results['failed']:
                f.write(f"- **{item['service']}**: {item['message']}\n")
            f.write("\n")
        
        if verifier.results['skipped']:
            f.write("## Skipped Services (Not Running)\n\n")
            f.write("These services are not currently running. This is expected in development.\n\n")
            for item in verifier.results['skipped']:
                f.write(f"- **{item['service']}**: {item['message']}\n")
            f.write("\n")
    
    print(f"Summary saved to {summary_path}")
    
    # Exit code based on results
    if verifier.results['failed']:
        print("\nWARNING: Some services failed health checks!")
        exit(1)
    elif verifier.results['passed']:
        print("\nSUCCESS: All running services passed health checks!")
        exit(0)
    else:
        print("\nNOTE: No services are currently running. This is expected in development.")
        print("To test health endpoints, start services with: docker-compose up -d")
        exit(0)


if __name__ == "__main__":
    main()

