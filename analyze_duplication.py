#!/usr/bin/env python3
"""Analyze code duplication in FKS monorepo structure.

This script identifies duplicate directories and files to help with
the monorepo refactoring effort.
"""

import hashlib
import json
from collections import defaultdict
from pathlib import Path
from typing import Dict, List, Set


def get_file_hash(filepath: Path) -> str:
    """Get MD5 hash of a file."""
    try:
        return hashlib.md5(filepath.read_bytes()).hexdigest()
    except Exception:
        return ""


def analyze_directory(base_path: Path, exclude_dirs: Set[str] = None) -> Dict:
    """Analyze a directory structure for duplicates."""
    exclude_dirs = exclude_dirs or {
        ".git",
        "__pycache__",
        ".pytest_cache",
        "node_modules",
        ".venv",
        "venv",
        "staticfiles",
        "migrations",
    }

    files_by_hash = defaultdict(list)
    dirs_analyzed = []
    total_files = 0
    total_size = 0

    for py_file in base_path.rglob("*.py"):
        # Skip excluded directories
        if any(excluded in py_file.parts for excluded in exclude_dirs):
            continue

        total_files += 1
        file_size = py_file.stat().st_size
        total_size += file_size

        file_hash = get_file_hash(py_file)
        if file_hash:
            rel_path = str(py_file.relative_to(base_path))
            files_by_hash[file_hash].append((rel_path, file_size))

    # Find duplicates
    duplicates = {h: paths for h, paths in files_by_hash.items() if len(paths) > 1}

    return {
        "total_files": total_files,
        "total_size": total_size,
        "unique_hashes": len(files_by_hash),
        "duplicate_groups": len(duplicates),
        "duplicates": duplicates,
    }


def compare_directories(dir1: Path, dir2: Path) -> Dict:
    """Compare two directories to see if they're identical."""
    if not dir1.exists() or not dir2.exists():
        return {"error": "One or both directories don't exist"}

    files1 = {
        f.relative_to(dir1): get_file_hash(f)
        for f in dir1.rglob("*.py")
        if "__pycache__" not in f.parts and "migrations" not in f.parts
    }

    files2 = {
        f.relative_to(dir2): get_file_hash(f)
        for f in dir2.rglob("*.py")
        if "__pycache__" not in f.parts and "migrations" not in f.parts
    }

    common_files = set(files1.keys()) & set(files2.keys())
    only_in_1 = set(files1.keys()) - set(files2.keys())
    only_in_2 = set(files2.keys()) - set(files1.keys())

    identical_files = {f for f in common_files if files1[f] == files2[f]}
    different_files = common_files - identical_files

    return {
        "dir1": str(dir1),
        "dir2": str(dir2),
        "total_in_1": len(files1),
        "total_in_2": len(files2),
        "common_files": len(common_files),
        "identical_files": len(identical_files),
        "different_files": len(different_files),
        "only_in_1": len(only_in_1),
        "only_in_2": len(only_in_2),
        "identical_percentage": (
            round(len(identical_files) / len(common_files) * 100, 2)
            if common_files
            else 0
        ),
        "different_file_list": sorted([str(f) for f in different_files]),
        "only_in_1_list": sorted([str(f) for f in only_in_1])[:10],  # First 10
        "only_in_2_list": sorted([str(f) for f in only_in_2])[:10],  # First 10
    }


def main():
    """Run the duplication analysis."""
    root = Path(__file__).parent.parent
    print("=" * 80)
    print("FKS MONOREPO DUPLICATION ANALYSIS")
    print("=" * 80)
    print()

    # Check if problematic directories exist
    print("## Directory Existence Check\n")
    dirs_to_check = [
        "src/core",
        "src/framework",
        "src/monitor",
        "src/shared/core",
        "src/shared/framework",
        "src/shared/monitor",
        "src/shared/core/core",  # The nested problem
    ]

    existing_dirs = []
    for dir_path in dirs_to_check:
        full_path = root / dir_path
        exists = full_path.exists()
        status = "✅ EXISTS" if exists else "❌ MISSING"
        print(f"{status:12} {dir_path}")
        if exists:
            existing_dirs.append(full_path)
    print()

    # Compare duplicate pairs
    print("## Directory Comparison Analysis\n")

    comparisons = [
        (root / "src/core", root / "src/shared/core"),
        (root / "src/framework", root / "src/shared/framework"),
        (root / "src/monitor", root / "src/shared/monitor"),
    ]

    for dir1, dir2 in comparisons:
        if not dir1.exists() or not dir2.exists():
            print(f"⚠️  Skipping {dir1.name} vs {dir2.parent.name}/{dir2.name} (one missing)")
            continue

        print(f"### Comparing `{dir1.relative_to(root)}` vs `{dir2.relative_to(root)}`\n")
        result = compare_directories(dir1, dir2)

        print(f"- Files in {dir1.name}: {result['total_in_1']}")
        print(f"- Files in {dir2.parent.name}/{dir2.name}: {result['total_in_2']}")
        print(f"- Common files: {result['common_files']}")
        print(f"- Identical files: {result['identical_files']}")
        print(f"- Different files: {result['different_files']}")
        print(f"- **Identical percentage: {result['identical_percentage']}%**")

        if result["different_files"] > 0:
            print(f"\nDifferent files: {', '.join(result['different_file_list'][:5])}")
            if len(result["different_file_list"]) > 5:
                print(f"... and {len(result['different_file_list']) - 5} more")

        print()

    # Check for nested core/core issue
    nested_core = root / "src/shared/core/core"
    if nested_core.exists():
        print("## ⚠️ CRITICAL: Nested core/core Directory Found!\n")
        print(f"Path: {nested_core}")
        py_files = list(nested_core.rglob("*.py"))
        print(f"Python files: {len(py_files)}")
        print("This is likely a mistake and should be cleaned up.\n")

    # Analyze service duplicates
    print("## Service Duplication Analysis\n")
    services = [
        "api",
        "app",
        "data",
        "execution",
        "ai",
        "web",
        "ninja",
    ]

    service_framework_dirs = []
    for service in services:
        service_framework = root / f"repo/{service}/src/framework"
        if service_framework.exists():
            service_framework_dirs.append((service, service_framework))

    if service_framework_dirs:
        print(f"Found {len(service_framework_dirs)} services with duplicate framework code:\n")
        for service, framework_dir in service_framework_dirs:
            py_files = list(framework_dir.rglob("*.py"))
            total_size = sum(f.stat().st_size for f in py_files) / 1024  # KB
            print(f"- `repo/{service}/src/framework/` - {len(py_files)} files, {total_size:.1f} KB")
        print()

    # Summary and recommendations
    print("## 📊 Summary and Recommendations\n")

    # Count total duplicates
    total_duplicate_dirs = 0
    if (root / "src/core").exists() and (root / "src/shared/core").exists():
        total_duplicate_dirs += 1
    if (root / "src/framework").exists() and (root / "src/shared/framework").exists():
        total_duplicate_dirs += 1
    if (root / "src/monitor").exists() and (root / "src/shared/monitor").exists():
        total_duplicate_dirs += 1

    print(f"**Duplicate directory sets found**: {total_duplicate_dirs}")
    print(f"**Services with duplicate framework code**: {len(service_framework_dirs)}")

    if nested_core.exists():
        print(f"**Nested core/core issue**: ⚠️ YES - needs immediate fix")
    else:
        print(f"**Nested core/core issue**: ✅ No")

    print("\n### Immediate Action Items\n")
    if total_duplicate_dirs > 0:
        print("1. **Decide on canonical location** for shared code")
        print("   - Option A: Keep `/src/shared/` (recommended for future split)")
        print("   - Option B: Keep root level `/src/core`, `/src/framework`, `/src/monitor`")
        print()

    if nested_core.exists():
        print("2. **Fix nested core/core directory** (CRITICAL)")
        print("   ```bash")
        print("   rm -rf src/shared/core/core/")
        print("   ```")
        print()

    if total_duplicate_dirs > 0:
        print("3. **Remove duplicates** after deciding canonical location")
        print("   ```bash")
        print("   # If keeping src/shared/:")
        print("   rm -rf src/core src/framework src/monitor")
        print("   # OR if keeping root level:")
        print("   rm -rf src/shared/")
        print("   ```")
        print()

    if service_framework_dirs:
        print("4. **Extract shared code to package** to eliminate service duplicates")
        print("   - Create `shared/` package with `pyproject.toml`")
        print("   - Remove duplicate code from service repos")
        print("   - Update imports to use `fks_shared` package")
        print()

    print("See `/docs/MONOREPO_REFACTOR_PLAN.md` for detailed migration steps.\n")

    # Save JSON report
    report_path = root / "docs/DUPLICATION_ANALYSIS.json"
    report = {
        "date": "2025-11-07",
        "duplicate_directory_sets": total_duplicate_dirs,
        "services_with_duplicates": len(service_framework_dirs),
        "nested_core_issue": nested_core.exists(),
        "comparisons": {},
    }

    for dir1, dir2 in comparisons:
        if dir1.exists() and dir2.exists():
            key = f"{dir1.name}_vs_{dir2.parent.name}_{dir2.name}"
            report["comparisons"][key] = compare_directories(dir1, dir2)

    with open(report_path, "w") as f:
        json.dump(report, f, indent=2)

    print(f"📄 Detailed JSON report saved to: {report_path}")


if __name__ == "__main__":
    main()
