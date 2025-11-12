#!/usr/bin/env python3
"""
Phase 4.1: Define SLOs and Error Budgets
Creates SLO definitions and monitoring configurations.
"""

import json
from pathlib import Path
from datetime import datetime
from typing import Dict, Any

# Get repo/ directory (3 levels up from scripts/phase4/)
BASE_PATH = Path(__file__).parent.parent.parent.parent.parent  # repo/

# SLO Definitions per Service
SLO_DEFINITIONS = {
    "fks_api": {
        "availability": 99.9,  # 99.9% uptime
        "latency_p95": 200,  # 200ms P95
        "error_rate": 1.0,  # <1% errors
        "throughput": 1000,  # 1000 req/s
        "error_budget": 0.1,  # 0.1% error budget
        "monthly_downtime_minutes": 43.2,
        "weekly_downtime_minutes": 10.08
    },
    "fks_monitor": {
        "availability": 99.95,  # Critical service
        "latency_p95": 100,
        "error_rate": 0.5,
        "throughput": 500,
        "error_budget": 0.05,
        "monthly_downtime_minutes": 21.6,
        "weekly_downtime_minutes": 5.04
    },
    "fks_main": {
        "availability": 99.9,
        "latency_p95": 150,
        "error_rate": 1.0,
        "throughput": 200,
        "error_budget": 0.1,
        "monthly_downtime_minutes": 43.2,
        "weekly_downtime_minutes": 10.08
    },
    "fks_data": {
        "availability": 99.5,
        "latency_p95": 300,
        "error_rate": 2.0,
        "throughput": 800,
        "error_budget": 0.5,
        "monthly_downtime_minutes": 216,
        "weekly_downtime_minutes": 50.4
    },
    "fks_execution": {
        "availability": 99.8,
        "latency_p95": 500,
        "error_rate": 1.5,
        "throughput": 300,
        "error_budget": 0.2,
        "monthly_downtime_minutes": 86.4,
        "weekly_downtime_minutes": 20.16
    },
    "fks_web": {
        "availability": 99.5,
        "latency_p95": 400,
        "error_rate": 2.0,
        "throughput": 500,
        "error_budget": 0.5,
        "monthly_downtime_minutes": 216,
        "weekly_downtime_minutes": 50.4
    },
    "fks_ai": {
        "availability": 99.0,
        "latency_p95": 2000,  # GPU processing
        "error_rate": 3.0,
        "throughput": 50,
        "error_budget": 1.0,
        "monthly_downtime_minutes": 432,
        "weekly_downtime_minutes": 100.8
    },
    "fks_analyze": {
        "availability": 99.0,
        "latency_p95": 5000,  # AI processing
        "error_rate": 3.0,
        "throughput": 20,
        "error_budget": 1.0,
        "monthly_downtime_minutes": 432,
        "weekly_downtime_minutes": 100.8
    }
}


def create_slo_config():
    """Create SLO configuration file."""
    # Config files go in repo/core/main/config/
main_repo = BASE_PATH / "core" / "main"
    slo_file = main_repo / "config" / "slos.json"
    slo_file.parent.mkdir(exist_ok=True)
    
    config = {
        "version": "1.0",
        "updated": datetime.utcnow().isoformat(),
        "services": SLO_DEFINITIONS,
        "global": {
            "error_budget_policy": "halt_features_if_exceeded",
            "review_frequency": "weekly",
            "alert_threshold": 0.8  # Alert at 80% of error budget used
        }
    }
    
    slo_file.write_text(json.dumps(config, indent=2))
    return slo_file


def create_prometheus_slo_rules():
    """Create Prometheus recording rules for SLOs."""
    # K8s configs go in repo/core/main/k8s/
main_repo = BASE_PATH / "core" / "main"
    rules_file = main_repo / "k8s" / "monitoring" / "slo-rules.yaml"
    rules_file.parent.mkdir(parents=True, exist_ok=True)
    
    rules_content = """# Prometheus SLO Recording Rules
# These rules calculate SLO metrics for each service

groups:
  - name: fks_slos
    interval: 30s
    rules:
"""
    
    for service_name, slo in SLO_DEFINITIONS.items():
        rules_content += f"""
      # {service_name} SLO Metrics
      - record: {service_name}:availability:ratio
        expr: |
          sum(rate(http_requests_total{{service="{service_name}",status!~"5.."}}[5m]))
          /
          sum(rate(http_requests_total{{service="{service_name}"}}[5m]))
      
      - record: {service_name}:error_rate:ratio
        expr: |
          sum(rate(http_requests_total{{service="{service_name}",status=~"5.."}}[5m]))
          /
          sum(rate(http_requests_total{{service="{service_name}"}}[5m]))
      
      - record: {service_name}:latency:p95
        expr: histogram_quantile(0.95, sum(rate(http_request_duration_seconds_bucket{{service="{service_name}"}}[5m])) by (le))
      
      - record: {service_name}:error_budget:remaining
        expr: |
          ({slo['error_budget']} - ({service_name}:error_rate:ratio)) / {slo['error_budget']}
"""
    
    rules_file.write_text(rules_content)
    return rules_file


def create_grafana_dashboard():
    """Create Grafana dashboard JSON for SLO monitoring."""
    # K8s configs go in repo/core/main/k8s/
main_repo = BASE_PATH / "core" / "main"
    dashboard_file = main_repo / "k8s" / "monitoring" / "slo-dashboard.json"
    dashboard_file.parent.mkdir(parents=True, exist_ok=True)
    
    # Simplified Grafana dashboard structure
    dashboard = {
        "dashboard": {
            "title": "FKS SLO Dashboard",
            "panels": [],
            "refresh": "30s"
        }
    }
    
    # Add panels for each service
    for service_name, slo in SLO_DEFINITIONS.items():
        dashboard["dashboard"]["panels"].extend([
            {
                "title": f"{service_name} - Availability",
                "targets": [{
                    "expr": f"{service_name}:availability:ratio * 100",
                    "legendFormat": "Availability %"
                }],
                "type": "graph"
            },
            {
                "title": f"{service_name} - Error Budget Remaining",
                "targets": [{
                    "expr": f"{service_name}:error_budget:remaining * 100",
                    "legendFormat": "Budget %"
                }],
                "type": "graph",
                "alert": {
                    "conditions": [{
                        "evaluator": {
                            "params": [20],  # Alert if <20% budget remaining
                            "type": "lt"
                        }
                    }]
                }
            }
        ])
    
    dashboard_file.write_text(json.dumps(dashboard, indent=2))
    return dashboard_file


def create_slo_documentation():
    """Create SLO documentation."""
    # Docs go in repo/core/main/docs/
main_repo = BASE_PATH / "core" / "main"
    doc_file = main_repo / "docs" / "SLO_DEFINITIONS.md"
    doc_file.parent.mkdir(exist_ok=True)
    
    doc_content = """# FKS Service Level Objectives (SLOs)

## Overview

This document defines Service Level Objectives (SLOs) for all FKS services. SLOs help us balance reliability with feature velocity by defining acceptable levels of service quality.

## Error Budgets

Error Budget = 100% - SLO

When error budget is exhausted, we halt new features and focus on reliability.

## Service SLOs

"""
    
    for service_name, slo in SLO_DEFINITIONS.items():
        doc_content += f"""
### {service_name}

- **Availability**: {slo['availability']}%
- **Latency (P95)**: {slo['latency_p95']}ms
- **Error Rate**: <{slo['error_rate']}%
- **Throughput**: {slo['throughput']} req/s
- **Error Budget**: {slo['error_budget']}%
- **Monthly Downtime Allowed**: {slo['monthly_downtime_minutes']} minutes
- **Weekly Downtime Allowed**: {slo['weekly_downtime_minutes']} minutes

"""
    
    doc_content += """
## Monitoring

SLO metrics are tracked in:
- Prometheus: Recording rules calculate SLO metrics
- Grafana: SLO Dashboard shows compliance
- Alerts: Triggered when error budget is at risk

## Review Process

- Weekly: Review error budget consumption
- Monthly: Review SLO compliance
- Quarterly: Adjust SLOs based on business needs

## Error Budget Policy

When error budget is at risk (<20% remaining):
1. Halt new feature development
2. Focus on reliability improvements
3. Review and fix root causes
4. Resume features when budget recovers
"""
    
    doc_file.write_text(doc_content)
    return doc_file


def main():
    """Main entry point."""
    print("📊 Phase 4.1: Defining SLOs and Error Budgets\n")
    print("=" * 60)
    
    files_created = []
    
    # Create SLO config
    print("\n1. Creating SLO configuration...")
    slo_file = create_slo_config()
    files_created.append(slo_file)
    print(f"   ✅ Created: {slo_file}")
    
    # Create Prometheus rules
    print("\n2. Creating Prometheus SLO rules...")
    rules_file = create_prometheus_slo_rules()
    files_created.append(rules_file)
    print(f"   ✅ Created: {rules_file}")
    
    # Create Grafana dashboard
    print("\n3. Creating Grafana dashboard...")
    dashboard_file = create_grafana_dashboard()
    files_created.append(dashboard_file)
    print(f"   ✅ Created: {dashboard_file}")
    
    # Create documentation
    print("\n4. Creating SLO documentation...")
    doc_file = create_slo_documentation()
    files_created.append(doc_file)
    print(f"   ✅ Created: {doc_file}")
    
    print("\n" + "=" * 60)
    print("📊 Summary")
    print("=" * 60)
    print(f"Services with SLOs: {len(SLO_DEFINITIONS)}")
    print(f"Files created: {len(files_created)}")
    print("\n✅ SLO definitions complete!")
    print("\nNext steps:")
    print("  1. Deploy Prometheus rules: kubectl apply -f k8s/monitoring/slo-rules.yaml")
    print("  2. Import Grafana dashboard: k8s/monitoring/slo-dashboard.json")
    print("  3. Review SLOs: docs/SLO_DEFINITIONS.md")


if __name__ == "__main__":
    main()

