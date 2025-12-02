#!/usr/bin/env python3
"""
Move files from untracked fks/ directory to repo/core/main
Organizes all created files into the proper git-tracked location.
"""

import shutil
from pathlib import Path
from typing import List, Tuple

SCRIPT_DIR = Path(__file__).parent
PROJECT_ROOT = SCRIPT_DIR.parent
BASE_PATH = PROJECT_ROOT.parent.parent  # Go up from scripts -> repo/main -> repo -> fks
MAIN_REPO = PROJECT_ROOT  # repo/main is the main repo

# File mappings: (source, destination)
FILE_MAPPINGS: List[Tuple[Path, Path]] = [
    # Configuration files
    (BASE_PATH / "config", MAIN_REPO / "config"),
    
    # Documentation
    (BASE_PATH / "docs" / "ALL_PHASES_SUMMARY.md", MAIN_REPO / "docs" / "ALL_PHASES_SUMMARY.md"),
    (BASE_PATH / "docs" / "AUTOMATION.md", MAIN_REPO / "docs" / "AUTOMATION.md"),
    (BASE_PATH / "docs" / "FKS_MAIN_SETUP.md", MAIN_REPO / "docs" / "FKS_MAIN_SETUP.md"),
    (BASE_PATH / "docs" / "FKS_MONITOR_SETUP.md", MAIN_REPO / "docs" / "FKS_MONITOR_SETUP.md"),
    (BASE_PATH / "docs" / "INCIDENT_RESPONSE.md", MAIN_REPO / "docs" / "INCIDENT_RESPONSE.md"),
    (BASE_PATH / "docs" / "PERFORMANCE_OPTIMIZATION.md", MAIN_REPO / "docs" / "PERFORMANCE_OPTIMIZATION.md"),
    (BASE_PATH / "docs" / "PHASE3_CORE_IMPROVEMENTS.md", MAIN_REPO / "docs" / "PHASE3_CORE_IMPROVEMENTS.md"),
    (BASE_PATH / "docs" / "PHASE4_SRE_INTEGRATION.md", MAIN_REPO / "docs" / "PHASE4_SRE_INTEGRATION.md"),
    (BASE_PATH / "docs" / "PHASE5_CHAOS_ENGINEERING.md", MAIN_REPO / "docs" / "PHASE5_CHAOS_ENGINEERING.md"),
    (BASE_PATH / "docs" / "SERVICE_DISCOVERY.md", MAIN_REPO / "docs" / "SERVICE_DISCOVERY.md"),
    (BASE_PATH / "docs" / "SLO_DEFINITIONS.md", MAIN_REPO / "docs" / "SLO_DEFINITIONS.md"),
    (BASE_PATH / "docs" / "STANDARDIZATION_GUIDE.md", MAIN_REPO / "docs" / "STANDARDIZATION_GUIDE.md"),
    (BASE_PATH / "docs" / "STANDARDIZATION_COMPLETE.md", MAIN_REPO / "docs" / "STANDARDIZATION_COMPLETE.md"),
    (BASE_PATH / "docs" / "VERIFICATION_FIXES.md", MAIN_REPO / "docs" / "VERIFICATION_FIXES.md"),
    (BASE_PATH / "docs" / "SETUP_COMPLETE.md", MAIN_REPO / "docs" / "SETUP_COMPLETE.md"),
    
    # Templates and runbooks
    (BASE_PATH / "docs" / "templates", MAIN_REPO / "docs" / "templates"),
    (BASE_PATH / "docs" / "runbooks", MAIN_REPO / "docs" / "runbooks"),
    
    # Phase 1 assessment (keep in docs)
    (BASE_PATH / "docs" / "phase1_assessment", MAIN_REPO / "docs" / "phase1_assessment"),
    (BASE_PATH / "docs" / "PHASE1_GUIDE.md", MAIN_REPO / "docs" / "PHASE1_GUIDE.md"),
    
    # K8s configurations
    (BASE_PATH / "k8s", MAIN_REPO / "k8s"),
    
    # Scripts - move to appropriate subdirectories
    (BASE_PATH / "scripts" / "phase1_*.py", MAIN_REPO / "scripts" / "phase1"),
    (BASE_PATH / "scripts" / "phase3_*.py", MAIN_REPO / "scripts" / "phase3"),
    (BASE_PATH / "scripts" / "phase4_*.py", MAIN_REPO / "scripts" / "phase4"),
    (BASE_PATH / "scripts" / "standardize*.py", MAIN_REPO / "scripts" / "standardization"),
    (BASE_PATH / "scripts" / "fix_*.py", MAIN_REPO / "scripts" / "fixes"),
    (BASE_PATH / "scripts" / "fix_*.sh", MAIN_REPO / "scripts" / "fixes"),
    (BASE_PATH / "scripts" / "create_*.py", MAIN_REPO / "scripts" / "setup"),
    (BASE_PATH / "scripts" / "verify_*.sh", MAIN_REPO / "scripts" / "verification"),
    (BASE_PATH / "scripts" / "setup_*.sh", MAIN_REPO / "scripts" / "setup"),
    (BASE_PATH / "scripts" / "deployment", MAIN_REPO / "scripts" / "deployment"),
    (BASE_PATH / "scripts" / "migrations", MAIN_REPO / "scripts" / "migrations"),
    (BASE_PATH / "scripts" / "backup", MAIN_REPO / "scripts" / "backup"),
    
    # Summary documents
    (BASE_PATH / "ALL_PHASES_COMPLETE.md", MAIN_REPO / "docs" / "ALL_PHASES_COMPLETE.md"),
    (BASE_PATH / "FINAL_STATUS.md", MAIN_REPO / "docs" / "FINAL_STATUS.md"),
    (BASE_PATH / "PHASES_3_5_COMPLETE.md", MAIN_REPO / "docs" / "PHASES_3_5_COMPLETE.md"),
    (BASE_PATH / "STANDARDIZATION_SUMMARY.md", MAIN_REPO / "docs" / "STANDARDIZATION_SUMMARY.md"),
    (BASE_PATH / "standardization_report.md", MAIN_REPO / "docs" / "standardization_report.md"),
    (BASE_PATH / "standardization_report.json", MAIN_REPO / "docs" / "standardization_report.json"),
    (BASE_PATH / "phase3_health_checks_results.json", MAIN_REPO / "docs" / "phase3_health_checks_results.json"),
]


def copy_file_or_dir(source: Path, dest: Path):
    """Copy file or directory, creating parent directories if needed."""
    if not source.exists():
        return False
    
    dest.parent.mkdir(parents=True, exist_ok=True)
    
    if source.is_dir():
        if dest.exists():
            # Merge directories
            for item in source.iterdir():
                copy_file_or_dir(item, dest / item.name)
        else:
            shutil.copytree(source, dest, dirs_exist_ok=True)
    else:
        shutil.copy2(source, dest)
    
    return True


def move_scripts_by_pattern(pattern: str, dest_dir: Path):
    """Move scripts matching a pattern to destination directory."""
    scripts_dir = BASE_PATH / "scripts"
    dest_dir.mkdir(parents=True, exist_ok=True)
    
    moved = []
    for script in scripts_dir.glob(pattern):
        dest = dest_dir / script.name
        if script.exists():
            shutil.copy2(script, dest)
            moved.append(script.name)
    
    return moved


def main():
    """Main entry point."""
    print("📦 Moving files to repo/core/main\n")
    print("=" * 60)
    
    moved_count = 0
    skipped_count = 0
    
    # Handle direct file mappings
    for source, dest in FILE_MAPPINGS:
        if "*" in str(source):
            # Pattern-based move
            pattern = source.name
            if "phase1" in pattern:
                moved = move_scripts_by_pattern("phase1_*.py", MAIN_REPO / "scripts" / "phase1")
            elif "phase3" in pattern:
                moved = move_scripts_by_pattern("phase3_*.py", MAIN_REPO / "scripts" / "phase3")
            elif "phase4" in pattern:
                moved = move_scripts_by_pattern("phase4_*.py", MAIN_REPO / "scripts" / "phase4")
            elif "standardize" in pattern:
                moved = move_scripts_by_pattern("standardize*.py", MAIN_REPO / "scripts" / "standardization")
            elif "fix_" in pattern and pattern.endswith(".py"):
                moved = move_scripts_by_pattern("fix_*.py", MAIN_REPO / "scripts" / "fixes")
            elif "fix_" in pattern and pattern.endswith(".sh"):
                moved = move_scripts_by_pattern("fix_*.sh", MAIN_REPO / "scripts" / "fixes")
            elif "create_" in pattern:
                moved = move_scripts_by_pattern("create_*.py", MAIN_REPO / "scripts" / "setup")
            elif "verify_" in pattern:
                moved = move_scripts_by_pattern("verify_*.sh", MAIN_REPO / "scripts" / "verification")
            elif "setup_" in pattern:
                moved = move_scripts_by_pattern("setup_*.sh", MAIN_REPO / "scripts" / "setup")
            
            if moved:
                print(f"✅ Moved {len(moved)} scripts matching {pattern}")
                moved_count += len(moved)
            continue
        
        if copy_file_or_dir(source, dest):
            print(f"✅ Moved: {source.name} → {dest.relative_to(MAIN_REPO)}")
            moved_count += 1
        else:
            print(f"⚠️  Skipped (not found): {source.name}")
            skipped_count += 1
    
    # Move remaining scripts
    scripts_dir = BASE_PATH / "scripts"
    remaining_scripts = [
        "analyze.sh",
        "docker_clean_all.sh",
        "standardize_and_verify.sh",
    ]
    
    for script_name in remaining_scripts:
        script = scripts_dir / script_name
        if script.exists():
            dest = MAIN_REPO / "scripts" / script_name
            shutil.copy2(script, dest)
            print(f"✅ Moved: {script_name} → scripts/")
            moved_count += 1
    
    print("\n" + "=" * 60)
    print("📊 Summary")
    print("=" * 60)
    print(f"Files moved: {moved_count}")
    print(f"Files skipped: {skipped_count}")
    print(f"\n✅ Files moved to: repo/core/main/")
    print("\nNext steps:")
    print("  1. Review moved files in repo/core/main")
    print("  2. Commit to git: cd repo/core/main && git add .")
    print("  3. Update any hardcoded paths in scripts if needed")


if __name__ == "__main__":
    main()

