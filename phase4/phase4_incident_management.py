#!/usr/bin/env python3
"""
Phase 4.3: Incident Management Setup
Creates incident management templates and processes.
"""

import json
from pathlib import Path
from typing import Dict, List, Any
from datetime import datetime

# Get repo/ directory (3 levels up from scripts/phase4/)
BASE_PATH = Path(__file__).parent.parent.parent.parent.parent  # repo/
main_repo = BASE_PATH / "core" / "main"


def create_postmortem_template():
    """Create postmortem template."""
    template_file = main_repo / "docs" / "templates" / "postmortem_template.md"
    template_file.parent.mkdir(parents=True, exist_ok=True)
    
    template = """# Postmortem: [Incident Title]

**Date**: [YYYY-MM-DD]  
**Duration**: [Start Time] - [End Time]  
**Impact**: [Service(s) affected, users impacted]  
**Severity**: [P0/P1/P2/P3]

## Summary

[Brief 2-3 sentence summary of what happened]

## Timeline

| Time | Event |
|------|-------|
| [Time] | [Event description] |
| [Time] | [Event description] |
| [Time] | [Event description] |

## Root Cause

[Detailed explanation of the root cause]

## Impact

- **Services Affected**: [List services]
- **Users Impacted**: [Number/percentage]
- **Downtime**: [Duration]
- **Data Loss**: [If any]

## Detection

[How was the incident detected?]

## Response

[What actions were taken to resolve?]

## Resolution

[How was it fixed?]

## Action Items

### Immediate (Next 24 hours)
- [ ] [Action item 1]
- [ ] [Action item 2]

### Short-term (Next week)
- [ ] [Action item 1]
- [ ] [Action item 2]

### Long-term (Next month)
- [ ] [Action item 1]
- [ ] [Action item 2]

## Lessons Learned

### What Went Well
- [Positive aspect 1]
- [Positive aspect 2]

### What Could Be Improved
- [Improvement 1]
- [Improvement 2]

### Blameless Culture
This postmortem follows a blameless culture. We focus on:
- Understanding what happened
- Preventing recurrence
- Improving systems and processes
- Learning as a team

## Follow-up

**Owner**: [Name]  
**Review Date**: [Date]  
**Status**: [Open/In Progress/Closed]

---

**Template Version**: 1.0  
**Last Updated**: 2025-11-08
"""
    
    template_file.write_text(template)
    return template_file


def create_incident_response_guide():
    """Create incident response guide."""
    guide_file = main_repo / "docs" / "INCIDENT_RESPONSE.md"
    guide_file.parent.mkdir(exist_ok=True)
    
    guide = """# FKS Incident Response Guide

## Overview

This guide outlines the incident response process for FKS services.

## Incident Severity Levels

### P0 - Critical
- Complete service outage
- Data loss or corruption
- Security breach
- **Response Time**: Immediate

### P1 - High
- Major feature broken
- Significant performance degradation
- Partial service outage
- **Response Time**: < 15 minutes

### P2 - Medium
- Minor feature broken
- Performance issues
- Non-critical service degradation
- **Response Time**: < 1 hour

### P3 - Low
- Cosmetic issues
- Minor bugs
- Non-user-facing issues
- **Response Time**: < 4 hours

## Incident Response Process

### 1. Detection

Incidents can be detected via:
- Monitoring alerts
- User reports
- Automated tests
- Team observations

### 2. Triage

**On-Call Engineer**:
1. Acknowledge incident
2. Assess severity
3. Escalate if needed
4. Create incident ticket

### 3. Response

**Immediate Actions**:
1. Stop the bleeding (mitigate impact)
2. Restore service if possible
3. Communicate status
4. Document actions

### 4. Resolution

**Steps**:
1. Identify root cause
2. Implement fix
3. Verify resolution
4. Monitor for recurrence

### 5. Post-Incident

**Within 24 hours**:
1. Write postmortem
2. Review with team
3. Create action items
4. Update runbooks

## Communication

### Internal
- **Slack**: #incidents channel
- **Status Page**: Update status.fkstrading.xyz
- **Email**: Notify team if P0/P1

### External
- **Status Page**: Public updates
- **Twitter**: For major incidents (optional)

## Runbooks

Common incident runbooks:
- Database connection issues
- Service unavailability
- High error rates
- Performance degradation

Location: `docs/runbooks/`

## Escalation

### Level 1: On-Call Engineer
- Initial response
- Basic troubleshooting
- Escalate if unresolved in 15 min (P0/P1)

### Level 2: Team Lead
- Complex issues
- Coordination needed
- Escalate if unresolved in 1 hour

### Level 3: Engineering Manager
- Critical incidents
- Business impact
- External communication

## Tools

- **Incident Tracking**: GitHub Issues, Jira, or Linear
- **Communication**: Slack, PagerDuty
- **Monitoring**: Prometheus, Grafana
- **Status Page**: Statuspage.io or custom

## Best Practices

1. **Blameless Culture**: Focus on systems, not people
2. **Document Everything**: Actions, decisions, timeline
3. **Communicate Early**: Better to over-communicate
4. **Learn from Incidents**: Every incident is a learning opportunity
5. **Update Runbooks**: Keep runbooks current

## Postmortem Process

1. **Schedule**: Within 48 hours of resolution
2. **Attendees**: All involved team members
3. **Duration**: 30-60 minutes
4. **Template**: Use `docs/templates/postmortem_template.md`
5. **Follow-up**: Track action items

## Metrics

Track:
- **MTTR**: Mean Time To Resolution
- **MTTD**: Mean Time To Detection
- **Incident Frequency**: Incidents per month
- **Resolution Rate**: % resolved within SLA

---

**Last Updated**: 2025-11-08
"""
    
    guide_file.write_text(guide)
    return guide_file


def create_runbook_template():
    """Create runbook template."""
    # Docs go in repo/core/main/docs/
main_repo = BASE_PATH / "core" / "main"
    runbook_dir = main_repo / "docs" / "runbooks"
    runbook_dir.mkdir(exist_ok=True)
    
    template_file = runbook_dir / "template.md"
    template = """# Runbook: [Issue Name]

## Overview

[Brief description of the issue this runbook addresses]

## Symptoms

- [Symptom 1]
- [Symptom 2]
- [Symptom 3]

## Diagnosis

### Check 1: [What to check]
```bash
# Command to run
```

### Check 2: [What to check]
```bash
# Command to run
```

## Resolution

### Step 1: [Action]
```bash
# Command
```

### Step 2: [Action]
```bash
# Command
```

## Verification

```bash
# Command to verify fix
```

## Prevention

- [Prevention measure 1]
- [Prevention measure 2]

## Related

- [Related runbook 1]
- [Related documentation]

---

**Last Updated**: [Date]
"""
    
    template_file.write_text(template)
    return template_file


def create_incident_config():
    """Create incident management configuration."""
    config_file = main_repo / "config" / "incident_management.json"
    config_file.parent.mkdir(exist_ok=True)
    
    config = {
        "version": "1.0",
        "updated": datetime.utcnow().isoformat(),
        "severity_levels": {
            "P0": {
                "name": "Critical",
                "response_time_minutes": 0,
                "resolution_time_hours": 1
            },
            "P1": {
                "name": "High",
                "response_time_minutes": 15,
                "resolution_time_hours": 4
            },
            "P2": {
                "name": "Medium",
                "response_time_minutes": 60,
                "resolution_time_hours": 24
            },
            "P3": {
                "name": "Low",
                "response_time_minutes": 240,
                "resolution_time_hours": 72
            }
        },
        "escalation": {
            "levels": [
                {
                    "level": 1,
                    "role": "oncall-engineer",
                    "timeout_minutes": 15
                },
                {
                    "level": 2,
                    "role": "team-lead",
                    "timeout_minutes": 60
                },
                {
                    "level": 3,
                    "role": "engineering-manager",
                    "timeout_minutes": 120
                }
            ]
        },
        "communication": {
            "channels": {
                "internal": "#incidents",
                "external": "status.fkstrading.xyz"
            }
        }
    }
    
    config_file.write_text(json.dumps(config, indent=2))
    return config_file


def main():
    """Main entry point."""
    print("🚨 Phase 4.3: Incident Management Setup\n")
    print("=" * 60)
    
    files_created = []
    
    # Create postmortem template
    print("\n1. Creating postmortem template...")
    template_file = create_postmortem_template()
    files_created.append(template_file)
    print(f"   ✅ Created: {template_file}")
    
    # Create incident response guide
    print("\n2. Creating incident response guide...")
    guide_file = create_incident_response_guide()
    files_created.append(guide_file)
    print(f"   ✅ Created: {guide_file}")
    
    # Create runbook template
    print("\n3. Creating runbook template...")
    runbook_file = create_runbook_template()
    files_created.append(runbook_file)
    print(f"   ✅ Created: {runbook_file}")
    
    # Create incident config
    print("\n4. Creating incident management configuration...")
    config_file = create_incident_config()
    files_created.append(config_file)
    print(f"   ✅ Created: {config_file}")
    
    print("\n" + "=" * 60)
    print("📊 Summary")
    print("=" * 60)
    print(f"Files created: {len(files_created)}")
    print("\n✅ Incident management setup complete!")
    print("\nNext steps:")
    print("  1. Review incident response guide")
    print("  2. Create initial runbooks")
    print("  3. Set up incident tracking")
    print("  4. Train team on process")
    print("  5. Review: docs/INCIDENT_RESPONSE.md")


if __name__ == "__main__":
    main()

