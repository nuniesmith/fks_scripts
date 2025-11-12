#!/usr/bin/env python3
"""
Validation script for Phase 4.3 - Monitoring & Observability

Checks that all components are properly configured:
- Prometheus is running and has correct configuration
- Grafana is running and dashboard is loaded
- Metrics module is importable
- All instrumented files have metrics calls
- Alert rules are configured
"""

import os
import sys
import json
import requests
import time
from pathlib import Path


class Colors:
    """ANSI color codes."""
    GREEN = '\033[92m'
    RED = '\033[91m'
    YELLOW = '\033[93m'
    BLUE = '\033[94m'
    END = '\033[0m'
    BOLD = '\033[1m'


def print_header(text):
    """Print section header."""
    print(f"\n{Colors.BOLD}{Colors.BLUE}{'='*60}{Colors.END}")
    print(f"{Colors.BOLD}{Colors.BLUE}{text}{Colors.END}")
    print(f"{Colors.BOLD}{Colors.BLUE}{'='*60}{Colors.END}\n")


def print_success(text):
    """Print success message."""
    print(f"{Colors.GREEN}✅ {text}{Colors.END}")


def print_error(text):
    """Print error message."""
    print(f"{Colors.RED}❌ {text}{Colors.END}")


def print_warning(text):
    """Print warning message."""
    print(f"{Colors.YELLOW}⚠️  {text}{Colors.END}")


def print_info(text):
    """Print info message."""
    print(f"{Colors.BLUE}ℹ️  {text}{Colors.END}")


def check_prometheus_running():
    """Check if Prometheus is accessible."""
    print_header("Checking Prometheus")
    
    try:
        response = requests.get('http://localhost:9090/api/v1/status/config', timeout=5)
        if response.status_code == 200:
            print_success("Prometheus is running on port 9090")
            return True
        else:
            print_error(f"Prometheus returned status {response.status_code}")
            return False
    except requests.exceptions.RequestException as e:
        print_error(f"Cannot connect to Prometheus: {e}")
        print_info("Start Prometheus with: docker-compose up -d prometheus")
        return False


def check_prometheus_config():
    """Check Prometheus configuration."""
    print_header("Checking Prometheus Configuration")
    
    config_path = Path('/home/jordan/fks/monitoring/prometheus/prometheus.yml')
    
    if not config_path.exists():
        print_error(f"Config file not found: {config_path}")
        return False
    
    print_success(f"Config file exists: {config_path}")
    
    # Check rule files
    with open(config_path, 'r') as f:
        content = f.read()
        
    if 'rules/execution_alerts.yml' in content:
        print_success("Execution alerts configured in prometheus.yml")
    else:
        print_error("Execution alerts not configured in prometheus.yml")
        return False
    
    # Check if alerts file exists
    alerts_path = Path('/home/jordan/fks/monitoring/prometheus/rules/execution_alerts.yml')
    if alerts_path.exists():
        print_success(f"Alert rules file exists: {alerts_path}")
        
        with open(alerts_path, 'r') as f:
            alerts_content = f.read()
        
        # Count alerts
        alert_count = alerts_content.count('alert:')
        print_info(f"Found {alert_count} alert rules defined")
    else:
        print_error(f"Alert rules file not found: {alerts_path}")
        return False
    
    return True


def check_grafana_running():
    """Check if Grafana is accessible."""
    print_header("Checking Grafana")
    
    try:
        response = requests.get('http://localhost:3000/api/health', timeout=5)
        if response.status_code == 200:
            data = response.json()
            print_success(f"Grafana is running on port 3000 (version {data.get('version', 'unknown')})")
            return True
        else:
            print_error(f"Grafana returned status {response.status_code}")
            return False
    except requests.exceptions.RequestException as e:
        print_error(f"Cannot connect to Grafana: {e}")
        print_info("Start Grafana with: docker-compose up -d grafana")
        return False


def check_grafana_dashboard():
    """Check if execution pipeline dashboard exists."""
    print_header("Checking Grafana Dashboard")
    
    dashboard_path = Path('/home/jordan/fks/monitoring/grafana/dashboards/execution_pipeline.json')
    
    if not dashboard_path.exists():
        print_error(f"Dashboard file not found: {dashboard_path}")
        return False
    
    print_success(f"Dashboard file exists: {dashboard_path}")
    
    # Validate JSON
    try:
        with open(dashboard_path, 'r') as f:
            dashboard_data = json.load(f)
        
        # Check key fields
        if 'dashboard' in dashboard_data:
            dash = dashboard_data['dashboard']
            title = dash.get('title', 'Unknown')
            panel_count = len(dash.get('panels', []))
            
            print_success(f"Dashboard title: {title}")
            print_success(f"Panel count: {panel_count}")
            
            if panel_count >= 16:
                print_success("All 16 panels configured")
            else:
                print_warning(f"Expected 16 panels, found {panel_count}")
        else:
            print_warning("Dashboard structure may be invalid")
        
        return True
    except json.JSONDecodeError as e:
        print_error(f"Invalid JSON in dashboard: {e}")
        return False


def check_metrics_module():
    """Check if metrics module exists and is valid."""
    print_header("Checking Metrics Module")
    
    metrics_path = Path('/home/jordan/fks/src/services/execution/metrics.py')
    
    if not metrics_path.exists():
        print_error(f"Metrics module not found: {metrics_path}")
        return False
    
    print_success(f"Metrics module exists: {metrics_path}")
    
    # Check for key metrics
    with open(metrics_path, 'r') as f:
        content = f.read()
    
    expected_metrics = [
        'webhook_requests_total',
        'webhook_processing_duration',
        'orders_total',
        'order_execution_duration',
        'rate_limit_requests',
        'circuit_breaker_state',
        'validation_errors',
        'normalization_operations'
    ]
    
    found_count = 0
    for metric in expected_metrics:
        if metric in content:
            found_count += 1
    
    print_success(f"Found {found_count}/{len(expected_metrics)} expected metrics")
    
    if found_count == len(expected_metrics):
        print_success("All core metrics defined")
        return True
    else:
        print_warning(f"Missing {len(expected_metrics) - found_count} metrics")
        return False


def check_instrumentation():
    """Check if code files are instrumented with metrics."""
    print_header("Checking Code Instrumentation")
    
    files_to_check = [
        ('/home/jordan/fks/src/services/execution/webhooks/tradingview.py', 'webhook_requests_total'),
        ('/home/jordan/fks/src/services/execution/exchanges/ccxt_plugin.py', 'orders_total'),
        ('/home/jordan/fks/src/services/execution/security/middleware.py', 'rate_limit_requests'),
        ('/home/jordan/fks/src/services/execution/validation/normalizer.py', 'validation_errors'),
    ]
    
    all_instrumented = True
    
    for file_path, expected_metric in files_to_check:
        path = Path(file_path)
        
        if not path.exists():
            print_error(f"File not found: {path}")
            all_instrumented = False
            continue
        
        with open(path, 'r') as f:
            content = f.read()
        
        if expected_metric in content:
            print_success(f"✓ {path.name} - instrumented with {expected_metric}")
        else:
            print_error(f"✗ {path.name} - missing {expected_metric}")
            all_instrumented = False
    
    return all_instrumented


def check_test_files():
    """Check if test files exist."""
    print_header("Checking Test Files")
    
    test_files = [
        '/home/jordan/fks/tests/integration/test_execution_metrics.py',
        '/home/jordan/fks/scripts/generate_test_traffic.py',
    ]
    
    all_exist = True
    
    for file_path in test_files:
        path = Path(file_path)
        
        if path.exists():
            size = path.stat().st_size
            print_success(f"✓ {path.name} ({size} bytes)")
        else:
            print_error(f"✗ {path.name} - not found")
            all_exist = False
    
    return all_exist


def check_documentation():
    """Check if documentation exists."""
    print_header("Checking Documentation")
    
    doc_files = [
        '/home/jordan/fks/docs/PHASE_4_1_COMPLETE.md',
        '/home/jordan/fks/docs/PHASE_4_2_COMPLETE.md',
    ]
    
    all_exist = True
    
    for file_path in doc_files:
        path = Path(file_path)
        
        if path.exists():
            size = path.stat().st_size
            print_success(f"✓ {path.name} ({size} bytes)")
        else:
            print_error(f"✗ {path.name} - not found")
            all_exist = False
    
    return all_exist


def main():
    """Run all validation checks."""
    print(f"\n{Colors.BOLD}Phase 4.3 Validation - Monitoring & Observability{Colors.END}")
    print(f"{Colors.BOLD}FKS Trading Platform{Colors.END}\n")
    
    results = {
        'Prometheus Running': check_prometheus_running(),
        'Prometheus Config': check_prometheus_config(),
        'Grafana Running': check_grafana_running(),
        'Grafana Dashboard': check_grafana_dashboard(),
        'Metrics Module': check_metrics_module(),
        'Code Instrumentation': check_instrumentation(),
        'Test Files': check_test_files(),
        'Documentation': check_documentation(),
    }
    
    # Summary
    print_header("Validation Summary")
    
    passed = sum(1 for v in results.values() if v)
    total = len(results)
    
    for check, result in results.items():
        if result:
            print_success(f"{check}")
        else:
            print_error(f"{check}")
    
    print(f"\n{Colors.BOLD}Results: {passed}/{total} checks passed{Colors.END}\n")
    
    if passed == total:
        print_success("✅ All validation checks passed!")
        print_info("\nNext steps:")
        print_info("1. Start application: docker-compose up -d")
        print_info("2. Generate test traffic: python3 scripts/generate_test_traffic.py --webhooks 100")
        print_info("3. View metrics: http://localhost:9090")
        print_info("4. View dashboard: http://localhost:3000/d/execution-pipeline")
        return 0
    else:
        print_error(f"❌ {total - passed} validation check(s) failed")
        print_info("\nPlease fix the failed checks before proceeding")
        return 1


if __name__ == '__main__':
    sys.exit(main())
