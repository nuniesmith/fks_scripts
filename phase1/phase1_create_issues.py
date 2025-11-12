#!/usr/bin/env python3
"""
Phase 1: Create GitHub Issues from Assessment Findings
Generates GitHub Issues for high and medium priority findings from Phase 1 assessment.
"""

import json
import os
import subprocess
from pathlib import Path
from typing import Dict, List, Any
from datetime import datetime

# Paths
# Get repo/ directory (3 levels up from scripts/phase1/)
PROJECT_ROOT = Path(__file__).parent.parent.parent.parent.parent  # repo/
AUDIT_REPORT = PROJECT_ROOT / "docs/phase1_assessment/phase1_audit_report.json"
HEALTH_REPORT = PROJECT_ROOT / "docs/phase1_assessment/phase1_health_report.json"
ISSUES_OUTPUT = PROJECT_ROOT / "docs/phase1_assessment/generated_issues.md"

# Priority mapping
PRIORITY_TO_LABELS = {
    "High": ["🔴 critical", "bug", "phase2"],
    "Medium": ["🟡 high", "enhancement", "phase2"],
    "Low": ["🟢 medium", "enhancement"]
}

# Category to label mapping
CATEGORY_LABELS = {
    "Testing": "tests",
    "Docker": "docker",
    "Health Checks": "monitoring",
    "Code Quality": "code-quality",
    "Documentation": "documentation",
    "Dependencies": "dependencies"
}


def load_report(file_path: Path) -> Dict[str, Any]:
    """Load JSON report file."""
    if not file_path.exists():
        print(f"⚠️  Report not found: {file_path}")
        return {}
    
    with open(file_path, "r") as f:
        return json.load(f)


def create_issue_body(issue: Dict[str, Any], repo_name: str) -> str:
    """Create GitHub Issue body from issue data."""
    category = issue.get("category", "Unknown")
    issue_type = issue.get("type", "Issue")
    description = issue.get("description", "")
    recommendation = issue.get("recommendation", "")
    priority = issue.get("priority", "Unknown")
    
    body = f"""## Issue Type
{issue_type}

## Category
{category}

## Priority
{priority}

## Description
{description}

## Recommendation
{recommendation}

## Repository
`{repo_name}`

## Related
- Phase 1 Assessment Finding
- Priority: {priority}

## Acceptance Criteria
- [ ] Issue identified in Phase 1 assessment
- [ ] Solution implemented
- [ ] Tests added/updated
- [ ] Documentation updated
- [ ] Verified in Phase 2 review

## Notes
This issue was automatically generated from Phase 1 assessment results.
"""
    return body


def create_health_issue_body(service_data: Dict[str, Any]) -> str:
    """Create GitHub Issue body for health check recommendations."""
    service_name = service_data.get("service", "unknown")
    recommendations = service_data.get("recommendations", [])
    
    if not recommendations:
        return None
    
    body = f"""## Issue Type
Health Check Improvement

## Category
Health Checks / Monitoring

## Service
`{service_name}`

## Current State
- Health endpoints in code: {'✅ Yes' if service_data.get('has_health_endpoint') else '❌ No'}
- Working endpoints: {'✅ Yes' if service_data.get('has_working_endpoint') else '❌ No'}
- Liveness probe: {'✅ Yes' if service_data.get('has_liveness') else '❌ No'}
- Readiness probe: {'✅ Yes' if service_data.get('has_readiness') else '❌ No'}

## Recommendations
"""
    
    for rec in recommendations:
        priority_emoji = "🔴" if rec["priority"] == "High" else "🟡"
        body += f"""
### {priority_emoji} {rec['priority']} Priority
**Issue**: {rec['issue']}

**Recommendation**: {rec['recommendation']}
"""
    
    body += """
## Acceptance Criteria
- [ ] Separate `/live` (liveness) endpoint implemented
- [ ] Separate `/ready` (readiness) endpoint implemented
- [ ] Endpoints tested and verified
- [ ] Kubernetes manifests updated with probes
- [ ] Documentation updated

## Related
- Phase 1 Health Check Assessment
- Service: `""" + service_name + """`

## Notes
This issue was automatically generated from Phase 1 health check assessment.
"""
    return body


def generate_issues_from_audit(audit_data: Dict[str, Any]) -> List[Dict[str, Any]]:
    """Generate GitHub Issues from audit report."""
    issues = []
    
    repos = audit_data.get("repos", {})
    
    for repo_name, repo_data in repos.items():
        if not repo_data.get("exists"):
            continue
        
        priority_issues = repo_data.get("priority_issues", {})
        
        # High priority issues
        for issue in priority_issues.get("high", []):
            issues.append({
                "title": f"[{repo_name}] {issue.get('type')} - {issue.get('category')}",
                "body": create_issue_body(issue, repo_name),
                "labels": PRIORITY_TO_LABELS["High"] + [CATEGORY_LABELS.get(issue.get("category"), "other")],
                "repo": repo_name,
                "priority": "High",
                "category": issue.get("category")
            })
        
        # Medium priority issues
        for issue in priority_issues.get("medium", []):
            issues.append({
                "title": f"[{repo_name}] {issue.get('type')} - {issue.get('category')}",
                "body": create_issue_body(issue, repo_name),
                "labels": PRIORITY_TO_LABELS["Medium"] + [CATEGORY_LABELS.get(issue.get("category"), "other")],
                "repo": repo_name,
                "priority": "Medium",
                "category": issue.get("category")
            })
    
    return issues


def generate_issues_from_health(health_data: Dict[str, Any]) -> List[Dict[str, Any]]:
    """Generate GitHub Issues from health check report."""
    issues = []
    
    services = health_data.get("services", {})
    
    for service_name, service_data in services.items():
        if not service_data.get("exists"):
            continue
        
        recommendations = service_data.get("recommendations", [])
        if not recommendations:
            continue
        
        # Check if we need separate issues or one combined
        high_priority_recs = [r for r in recommendations if r.get("priority") == "High"]
        medium_priority_recs = [r for r in recommendations if r.get("priority") == "Medium"]
        
        if high_priority_recs:
            # Create high priority issue
            body = create_health_issue_body(service_data)
            if body:
                issues.append({
                    "title": f"[{service_name}] Health Check Improvements - High Priority",
                    "body": body,
                    "labels": PRIORITY_TO_LABELS["High"] + ["monitoring", "health-checks"],
                    "repo": service_name,
                    "priority": "High",
                    "category": "Health Checks"
                })
        
        if medium_priority_recs and not high_priority_recs:
            # Create medium priority issue if no high priority
            body = create_health_issue_body(service_data)
            if body:
                issues.append({
                    "title": f"[{service_name}] Health Check Improvements - Medium Priority",
                    "body": body,
                    "labels": PRIORITY_TO_LABELS["Medium"] + ["monitoring", "health-checks"],
                    "repo": service_name,
                    "priority": "Medium",
                    "category": "Health Checks"
                })
    
    return issues


def generate_markdown_issues(issues: List[Dict[str, Any]]) -> str:
    """Generate markdown file with all issues for manual creation."""
    md = f"""# Phase 1: Generated GitHub Issues

**Generated**: {datetime.now().isoformat()}
**Total Issues**: {len(issues)}

## Instructions

1. Review each issue below
2. Create issues in GitHub using the GitHub CLI or web interface
3. Use the provided labels and body text
4. Update this file with issue numbers after creation

## Issues

"""
    
    # Group by priority
    high_priority = [i for i in issues if i["priority"] == "High"]
    medium_priority = [i for i in issues if i["priority"] == "Medium"]
    
    if high_priority:
        md += "### 🔴 High Priority Issues\n\n"
        for idx, issue in enumerate(high_priority, 1):
            md += f"""#### Issue {idx}: {issue['title']}

**Labels**: `{', '.join(issue['labels'])}`  
**Repository**: `{issue['repo']}`  
**Category**: `{issue['category']}`

**Body**:
```markdown
{issue['body']}
```

**GitHub CLI Command**:
```bash
gh issue create --title "{issue['title']}" --body "$(cat <<'EOF'
{issue['body']}
EOF
)" --label "{','.join(issue['labels'])}"
```

---

"""
    
    if medium_priority:
        md += "### 🟡 Medium Priority Issues\n\n"
        for idx, issue in enumerate(medium_priority, 1):
            md += f"""#### Issue {idx + len(high_priority)}: {issue['title']}

**Labels**: `{', '.join(issue['labels'])}`  
**Repository**: `{issue['repo']}`  
**Category**: `{issue['category']}`

**Body**:
```markdown
{issue['body']}
```

**GitHub CLI Command**:
```bash
gh issue create --title "{issue['title']}" --body "$(cat <<'EOF'
{issue['body']}
EOF
)" --label "{','.join(issue['labels'])}"
```

---

"""
    
    return md


def create_issues_via_cli(issues: List[Dict[str, Any]], dry_run: bool = True, repo: str = None):
    """Create GitHub Issues using GitHub CLI."""
    if dry_run:
        print("🔍 DRY RUN MODE - No issues will be created")
        print("=" * 60)
    
    # Default to nuniesmith/fks if not specified
    if repo is None:
        repo = "nuniesmith/fks"
    
    created = 0
    failed = 0
    
    for issue in issues:
        title = issue["title"]
        body = issue["body"]
        labels = ",".join(issue["labels"])
        
        if dry_run:
            print(f"\n📋 Would create issue: {title}")
            print(f"   Labels: {labels}")
            print(f"   Repo: {repo}")
        else:
            try:
                # Create issue using GitHub CLI with explicit repo
                cmd = [
                    "gh", "issue", "create",
                    "--repo", repo,
                    "--title", title,
                    "--body", body,
                    "--label", labels
                ]
                
                result = subprocess.run(cmd, capture_output=True, text=True)
                
                if result.returncode == 0:
                    print(f"✅ Created: {title}")
                    print(f"   {result.stdout.strip()}")
                    created += 1
                else:
                    # Try creating without labels if label error
                    if "not found" in result.stderr and "label" in result.stderr.lower():
                        print(f"⚠️  Label issue, trying without labels: {title}")
                        cmd_no_labels = [
                            "gh", "issue", "create",
                            "--repo", repo,
                            "--title", title,
                            "--body", body
                        ]
                        result2 = subprocess.run(cmd_no_labels, capture_output=True, text=True)
                        if result2.returncode == 0:
                            print(f"✅ Created (without labels): {title}")
                            print(f"   {result2.stdout.strip()}")
                            created += 1
                        else:
                            print(f"❌ Failed: {title}")
                            print(f"   Error: {result2.stderr.strip()}")
                            failed += 1
                    else:
                        print(f"❌ Failed: {title}")
                        print(f"   Error: {result.stderr.strip()}")
                        failed += 1
            except Exception as e:
                print(f"❌ Error creating issue {title}: {e}")
                failed += 1
    
    if not dry_run:
        print(f"\n📊 Summary: {created} created, {failed} failed")


def main():
    """Main entry point."""
    import argparse
    
    parser = argparse.ArgumentParser(description="Create GitHub Issues from Phase 1 assessment")
    parser.add_argument("--dry-run", action="store_true", default=True,
                       help="Dry run mode (default: True)")
    parser.add_argument("--create", action="store_true",
                       help="Actually create issues (overrides dry-run)")
    parser.add_argument("--output", default=str(ISSUES_OUTPUT),
                       help="Output file for markdown issues")
    parser.add_argument("--repo", default="nuniesmith/fks",
                       help="GitHub repository (owner/repo)")
    
    args = parser.parse_args()
    
    dry_run = not args.create
    
    print("📋 Phase 1: Creating GitHub Issues from Assessment")
    print("=" * 60)
    print()
    
    # Load reports
    print("📂 Loading assessment reports...")
    audit_data = load_report(AUDIT_REPORT)
    health_data = load_report(HEALTH_REPORT)
    
    if not audit_data and not health_data:
        print("❌ No reports found. Run phase1_run_all.sh first.")
        return
    
    # Generate issues
    print("🔨 Generating issues...")
    all_issues = []
    
    if audit_data:
        audit_issues = generate_issues_from_audit(audit_data)
        all_issues.extend(audit_issues)
        print(f"   Found {len(audit_issues)} issues from audit report")
    
    if health_data:
        health_issues = generate_issues_from_health(health_data)
        all_issues.extend(health_issues)
        print(f"   Found {len(health_issues)} issues from health check report")
    
    print(f"\n✅ Total issues to create: {len(all_issues)}")
    print(f"   High Priority: {len([i for i in all_issues if i['priority'] == 'High'])}")
    print(f"   Medium Priority: {len([i for i in all_issues if i['priority'] == 'Medium'])}")
    print()
    
    # Generate markdown file
    print(f"📄 Generating markdown file: {args.output}")
    md_content = generate_markdown_issues(all_issues)
    with open(args.output, "w") as f:
        f.write(md_content)
    print(f"✅ Markdown file created")
    print()
    
    # Create issues via CLI
    if dry_run:
        print("💡 To actually create issues, run with --create flag:")
        print(f"   python3 {__file__} --create --repo {args.repo}")
        print()
    
    create_issues_via_cli(all_issues, dry_run=dry_run, repo=args.repo)
    
    if not dry_run:
        print(f"\n✅ Issues creation complete!")
    else:
        print(f"\n💡 Review the markdown file: {args.output}")
        print("   Then run with --create to create issues in GitHub")


if __name__ == "__main__":
    main()

