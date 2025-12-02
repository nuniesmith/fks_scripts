#!/bin/bash
# Slimmed-down Codebase Analysis Script for FKS Project
# Tailored for CI/CD: Non-interactive, focuses on Python, Rust, Docker/K8s/Compose, Markdown, Shell/ENV/Config, Git/GitHub.
# Generates file structure, summary with counts/patterns, and optional linting.
# Usage: ./analyze_codebase.sh [options] <directory_path>
# Options:
# --lint Run language-specific linters and generate lint_report.txt
# --full Generate a full_code.txt file with concatenated contents of all analyzed files
# --output=DIR Specify output directory (defaults to timestamped)
# --exclude=DIR1,DIR2 Comma-separated directories to exclude (e.g., target,node_modules)
# --help Show this help message
# Env vars for CI: ANALYZE_OUTPUT_DIR, ANALYZE_LINT (true/false), ANALYZE_FULL (true/false), ANALYZE_EXCLUDE, ANALYZE_SKIP_SHARED (true/false)
set -e
# Parse options
LINT=0
FULL=0
OUTPUT_DIR=""
TARGET_DIR=""
EXCLUDE_LIST=""
SKIP_SHARED=0
while [[ $# -gt 0 ]]; do
case "$1" in
--lint) LINT=1; shift ;;
--full) FULL=1; shift ;;
--output=*) OUTPUT_DIR="${1#*=}"; shift ;;
--exclude=*) EXCLUDE_LIST="${1#*=}"; shift ;;
--help) echo "Usage: $0 [options] <directory_path>"; echo "Options: --lint, --full, --output=DIR, --exclude=DIR1,DIR2, --skip-shared, --help"; exit 0 ;;
*) TARGET_DIR="$1"; shift ;;
esac
done
# Environment overrides for CI/CD
[ -n "$ANALYZE_OUTPUT_DIR" ] && OUTPUT_DIR="$ANALYZE_OUTPUT_DIR"
[ "$ANALYZE_LINT" = "true" ] && LINT=1
[ "$ANALYZE_FULL" = "true" ] && FULL=1
[ -n "$ANALYZE_EXCLUDE" ] && EXCLUDE_LIST="$ANALYZE_EXCLUDE"
[ "$ANALYZE_SKIP_SHARED" = "true" ] && SKIP_SHARED=1
# Validate target dir
if [ -z "$TARGET_DIR" ] || [ ! -d "$TARGET_DIR" ]; then
echo "Error: Provide a valid directory path. Usage: $0 [options] <directory_path>"
exit 1
fi
# Set output dir
if [ -z "$OUTPUT_DIR" ]; then
OUTPUT_DIR="fks_analysis_report_$(date +%Y%m%d_%H%M%S)"
fi
mkdir -p "$OUTPUT_DIR"
echo "Starting FKS codebase analysis of: $TARGET_DIR"
echo "Reports in: $OUTPUT_DIR"
echo "Linting: $( [ $LINT -eq 1 ] && echo "Yes" || echo "No" )"
echo "Full code dump: $( [ $FULL -eq 1 ] && echo "Yes" || echo "No" )"
if [ -n "$EXCLUDE_LIST" ]; then echo "Excluding: $EXCLUDE_LIST"; fi
if [ $SKIP_SHARED -eq 1 ]; then
echo "Skipping shared/: Yes"
[ -n "$EXCLUDE_LIST" ] && EXCLUDE_LIST="$EXCLUDE_LIST,shared" || EXCLUDE_LIST="shared"
fi
# Filters for FKS-relevant files: Python, Rust, Docker/K8s/Compose (yml/yaml), MD/TXT, SH/Bash, ENV/Config (toml/json/ini/cfg/env), Git/GitHub (gitignore, yml/yaml in .github)
FILTER_EXT="py|rs|md|txt|sh|bash|yml|yaml|toml|json|ini|cfg|env"
ADDITIONAL_GREP="|Dockerfile$|docker-compose.*$|Cargo.toml$|Cargo.lock$|pyproject.toml$|requirements.*.txt$|k8s.*.yaml$|k8s.*.yml$|.gitignore$|.github.*"
# Common exclusions (tailored for FKS: target for Rust, venv for Python, etc.)
EXCLUDE_HIDDEN="-not -path '*/\.*'" # Exclude hidden unless GitHub/Docker
EXCLUDE_PATHS="$EXCLUDE_HIDDEN -not -path '*/__pycache__/*' -not -path '*/.pytest_cache/*' -not -path '*/.mypy_cache/*' -not -path '*/venv/*' -not -path '*/env/*' -not -path '*/target/*' -not -path '*/.idea/*' -not -path '*/.vscode/*' -not -path '*/coverage/*' -not -path '*/dist/*' -not -path '*/build/*'"
# Add custom excludes
if [ -n "$EXCLUDE_LIST" ]; then
IFS=',' read -r -a excludes <<< "$EXCLUDE_LIST"
for exclude in "${excludes[@]}"; do
EXCLUDE_PATHS="$EXCLUDE_PATHS -not -path '*/$exclude/*'"
done
fi
# Filtered find command
GREP_FILTER="| grep -E \"\.(${FILTER_EXT})\$${ADDITIONAL_GREP}\""
FILTERED_FIND="find \"$TARGET_DIR\" -type f $EXCLUDE_PATHS $GREP_FILTER 2>/dev/null | sort"
# 1. Generate file tree structure
echo "Generating file tree structure..."
TREE_OPTS=""
if [ -z "$EXCLUDE_HIDDEN" ]; then TREE_OPTS="-a"; fi
TREE_EXCLUDE_PATTERN="__pycache__|.git|.pytest_cache|.mypy_cache|venv|env|target|.idea|.vscode|coverage|dist|build"
if [ -n "$EXCLUDE_LIST" ]; then
TREE_EXCLUDE_PATTERN="$TREE_EXCLUDE_PATTERN|$(echo "$EXCLUDE_LIST" | sed 's/,/|/g')"
fi
if command -v tree &> /dev/null; then
tree $TREE_OPTS -n -I "$TREE_EXCLUDE_PATTERN" "$TARGET_DIR" > "$OUTPUT_DIR/file_structure.txt"
else
eval "find \"$TARGET_DIR\" $EXCLUDE_PATHS -type f -o -type d 2>/dev/null | sort | sed 's/[^/]*\//| /g;s/| *\([^| ]\)/+--- \1/g'" > "$OUTPUT_DIR/file_structure.txt"
fi
# 2. Generate summary report
echo "Generating summary report..."
SUMMARY_REPORT="$OUTPUT_DIR/summary.txt"
echo "FKS CODE ANALYSIS SUMMARY" > "$SUMMARY_REPORT"
echo "=================" >> "$SUMMARY_REPORT"
echo "Directory: $TARGET_DIR" >> "$SUMMARY_REPORT"
echo "Generated on: $(date)" >> "$SUMMARY_REPORT"
echo "=================" >> "$SUMMARY_REPORT"
# List of analyzed files
echo "" >> "$SUMMARY_REPORT"
echo "LIST OF ANALYZED FILES:" >> "$SUMMARY_REPORT"
echo "======================" >> "$SUMMARY_REPORT"
eval "$FILTERED_FIND" >> "$SUMMARY_REPORT"
# File counts by extension
echo "" >> "$SUMMARY_REPORT"
echo "File count by type/extension:" >> "$SUMMARY_REPORT"
eval "$FILTERED_FIND" | while read -r file; do
ext="${file##*.}"
[ "$ext" = "$file" ] && echo "no_ext" || echo "$ext"
done | sort | uniq -c | sort -nr >> "$SUMMARY_REPORT"
# Total/Avg size
total_files=$(eval "$FILTERED_FIND" | wc -l)
total_size=$(eval "$FILTERED_FIND" | xargs -I {} stat -c%s "{}" 2>/dev/null | awk '{sum+=$1} END {print sum}')
[ "$total_files" -eq 0 ] && avg_size=0 || avg_size=$((total_size / total_files))
echo "Total files: $total_files | Total size: $total_size bytes | Avg size: $avg_size bytes" >> "$SUMMARY_REPORT"
# Empty/Small files
echo "" >> "$SUMMARY_REPORT"
echo "EMPTY AND SMALL FILES ANALYSIS" >> "$SUMMARY_REPORT"
echo "=============================" >> "$SUMMARY_REPORT"
echo "Empty files (size 0 bytes):" >> "$SUMMARY_REPORT"
eval "find \"$TARGET_DIR\" -type f -size 0 $EXCLUDE_PATHS $GREP_FILTER 2>/dev/null | sort" >> "$SUMMARY_REPORT"
echo "" >> "$SUMMARY_REPORT"
echo "Small files (<100 bytes, excluding empty):" >> "$SUMMARY_REPORT"
eval "find \"$TARGET_DIR\" -type f -size -100c ! -size 0 $EXCLUDE_PATHS $GREP_FILTER 2>/dev/null | sort" >> "$SUMMARY_REPORT"
# Language-specific analysis
echo "" >> "$SUMMARY_REPORT"
echo "LANGUAGE-SPECIFIC ANALYSIS" >> "$SUMMARY_REPORT"
echo "=========================" >> "$SUMMARY_REPORT"
# Python
python_files=$(eval "find \"$TARGET_DIR\" -name '*.py' $EXCLUDE_PATHS 2>/dev/null | wc -l")
if [ "$python_files" -gt 0 ]; then
echo "" >> "$SUMMARY_REPORT"
echo "PYTHON ANALYSIS:" >> "$SUMMARY_REPORT"
echo "Python files count: $python_files" >> "$SUMMARY_REPORT"
echo "Python packages count: $(eval "find \"$TARGET_DIR\" -name '__init__.py' $EXCLUDE_PATHS 2>/dev/null | wc -l")" >> "$SUMMARY_REPORT"
echo "Test files count: $(eval "find \"$TARGET_DIR\" -name '*test*.py' -o -name 'test_*.py' $EXCLUDE_PATHS 2>/dev/null | wc -l")" >> "$SUMMARY_REPORT"
echo "Python imports found:" >> "$SUMMARY_REPORT"
grep -r -h "^[ \t]*\(from .* import\|import \)" --include="*.py" "$TARGET_DIR" 2>/dev/null | sed 's/.*import \([^ .;]*\).*/\1/' | sort | uniq -c | sort -nr | head -10 >> "$SUMMARY_REPORT"
echo "Python classes found:" >> "$SUMMARY_REPORT"
grep -r -h "^[ \t]*class " --include="*.py" "$TARGET_DIR" 2>/dev/null | sed 's/.*class \([^(:]*\).*/\1/' | sort | uniq | head -20 >> "$SUMMARY_REPORT"
fi
# Rust
rust_files=$(eval "find \"$TARGET_DIR\" -name '*.rs' $EXCLUDE_PATHS 2>/dev/null | wc -l")
if [ "$rust_files" -gt 0 ]; then
echo "" >> "$SUMMARY_REPORT"
echo "RUST ANALYSIS:" >> "$SUMMARY_REPORT"
echo "Rust files count: $rust_files" >> "$SUMMARY_REPORT"
echo "Cargo projects count: $(eval "find \"$TARGET_DIR\" -name 'Cargo.toml' $EXCLUDE_PATHS 2>/dev/null | wc -l")" >> "$SUMMARY_REPORT"
echo "Rust external crates used:" >> "$SUMMARY_REPORT"
grep -r -h "^use " --include="*.rs" "$TARGET_DIR" 2>/dev/null | sed 's/.*use \([^:;]*\).*/\1/' | grep -v "^crate\|^self\|^super" | sort | uniq -c | sort -nr | head -10 >> "$SUMMARY_REPORT"
echo "Rust structs found:" >> "$SUMMARY_REPORT"
grep -r -h "^[ \t]*struct " --include="*.rs" "$TARGET_DIR" 2>/dev/null | sed 's/.*struct \([^{<]*\).*/\1/' | sort | uniq | head -20 >> "$SUMMARY_REPORT"
fi
# Docker/K8s/Compose
docker_files=$(eval "find \"$TARGET_DIR\" \( -name 'Dockerfile' -o -name 'docker-compose.*' -o -name '*.env' \) $EXCLUDE_PATHS 2>/dev/null | wc -l")
if [ "$docker_files" -gt 0 ]; then
echo "" >> "$SUMMARY_REPORT"
echo "DOCKER/K8S/COMPOSE ANALYSIS:" >> "$SUMMARY_REPORT"
echo "Docker-related files count: $docker_files" >> "$SUMMARY_REPORT"
echo "K8s YAML files count: $(eval "find \"$TARGET_DIR\" -name '*k8s*.y*ml' $EXCLUDE_PATHS 2>/dev/null | wc -l")" >> "$SUMMARY_REPORT"
fi
# GitHub Actions and Git
github_workflows=$(eval "find \"$TARGET_DIR\" -path '*/.github/workflows/*' -name '*.y*ml' $EXCLUDE_PATHS 2>/dev/null | wc -l")
if [ "$github_workflows" -gt 0 ]; then
echo "" >> "$SUMMARY_REPORT"
echo "GITHUB ANALYSIS:" >> "$SUMMARY_REPORT"
echo "GitHub Actions workflows count: $github_workflows" >> "$SUMMARY_REPORT"
echo "Gitignores count: $(eval "find \"$TARGET_DIR\" -name '.gitignore' $EXCLUDE_PATHS 2>/dev/null | wc -l")" >> "$SUMMARY_REPORT"
fi
# Markdown/Text/Shell/Config
md_files=$(eval "find \"$TARGET_DIR\" -name '*.md' $EXCLUDE_PATHS 2>/dev/null | wc -l")
sh_files=$(eval "find \"$TARGET_DIR\" -name '*.sh' $EXCLUDE_PATHS 2>/dev/null | wc -l")
config_files=$(eval "find \"$TARGET_DIR\" \( -name '*.toml' -o -name '*.json' -o -name '*.ini' -o -name '*.cfg' -o -name '*.env' \) $EXCLUDE_PATHS 2>/dev/null | wc -l")
if [[ "$md_files" -gt 0 || "$sh_files" -gt 0 || "$config_files" -gt 0 ]]; then
echo "" >> "$SUMMARY_REPORT"
echo "OTHER FILES ANALYSIS:" >> "$SUMMARY_REPORT"
echo "Markdown/Text files count: $md_files" >> "$SUMMARY_REPORT"
echo "Shell scripts count: $sh_files" >> "$SUMMARY_REPORT"
echo "Config files count: $config_files" >> "$SUMMARY_REPORT"
fi
# Programming patterns (for Python/Rust)
echo "" >> "$SUMMARY_REPORT"
echo "PROGRAMMING PATTERNS ANALYSIS:" >> "$SUMMARY_REPORT"
echo "- Error/Exception handling: $(grep -ri 'try\|catch\|except\|Result\|error' --include='*.{py,rs}' \"$TARGET_DIR\" 2>/dev/null | wc -l)" >> "$SUMMARY_REPORT"
echo "- Async/concurrent: $(grep -ri 'async\|await\|tokio\|thread' --include='*.{py,rs}' \"$TARGET_DIR\" 2>/dev/null | wc -l)" >> "$SUMMARY_REPORT"
echo "- Testing: $(grep -ri 'test\|assert\|pytest\|#\[test\]' --include='*.{py,rs}' \"$TARGET_DIR\" 2>/dev/null | wc -l)" >> "$SUMMARY_REPORT"
# Dependencies
echo "" >> "$SUMMARY_REPORT"
echo "DEPENDENCIES ANALYSIS:" >> "$SUMMARY_REPORT"
[ -f "$TARGET_DIR/requirements.txt" ] && echo "Python requirements.txt found" >> "$SUMMARY_REPORT"
[ -f "$TARGET_DIR/pyproject.toml" ] && echo "Python pyproject.toml found" >> "$SUMMARY_REPORT"
[ -f "$TARGET_DIR/Cargo.toml" ] && echo "Rust Cargo.toml found" >> "$SUMMARY_REPORT"
# 3. Optional: Full code dump
if [ $FULL -eq 1 ]; then
echo "Generating full code dump..."
FULL_CODE="$OUTPUT_DIR/full_code.txt"
> "$FULL_CODE"
eval "$FILTERED_FIND" | while read -r file; do
echo "===== $file =====" >> "$FULL_CODE"
cat "$file" >> "$FULL_CODE"
echo "" >> "$FULL_CODE"
done
fi
# 4. Optional: Linting (Python/Rust only, quick for CI)
if [ $LINT -eq 1 ]; then
LINT_REPORT="$OUTPUT_DIR/lint_report.txt"
echo "Running linters..." > "$LINT_REPORT"
# Python (ruff if available)
if command -v ruff &> /dev/null && [ "$python_files" -gt 0 ]; then
echo "Python (Ruff):" >> "$LINT_REPORT"
ruff check "$TARGET_DIR" >> "$LINT_REPORT" 2>&1 || true
fi
# Rust (clippy if Cargo.toml exists)
if command -v cargo &> /dev/null && [ "$rust_files" -gt 0 ] && [ -f "$TARGET_DIR/Cargo.toml" ]; then
echo "Rust (Clippy):" >> "$LINT_REPORT"
(cd "$TARGET_DIR" && cargo clippy -- -D warnings >> "$LINT_REPORT" 2>&1 || true)
fi
fi
# 5. Generate slimmed-down guide (FKS-focused, with new app-specific sections)
GUIDE_REPORT="$OUTPUT_DIR/fks_analysis_guide.txt"
echo "Generating FKS analysis guide..."
cat > "$GUIDE_REPORT" << 'EOL'
FKS PROJECT ANALYSIS GUIDE
==========================
Tailored for FKS microservices/repos with Python, Rust, Docker/K8s, configs, scripts, docs.
1. PYTHON (Common in API, data, training, etc.)
- Structure: __init__.py, requirements.txt, pyproject.toml
- Patterns: Classes, decorators, comprehensions, with statements, try/except
- Testing: pytest, unittest
- Deps: pip, poetry
2. RUST (Common in core, auth, etc.)
- Structure: Cargo.toml, src/main.rs, src/lib.rs
- Patterns: Ownership, match, Result, traits, mod
- Testing: Built-in #[test]
- Deps: Cargo
3. DOCKER/K8S/COMPOSE
- Files: Dockerfile, docker-compose.yml, k8s/*.yaml
- Patterns: Multi-stage builds, env vars, volumes, services
- Tools: docker build, kubectl apply
4. SCRIPTS/CONFIG
- Shell: *.sh for deployment, migration, QA
- Config: *.env, *.toml, *.json, *.yaml for envs, schemas
- Patterns: Env var handling, error checks, loops
5. DOCS/MARKDOWN
- Files: README.md, MIGRATION.md, etc.
- Patterns: Headers, lists, code blocks for guides
6. GITHUB/CI/CD
- Workflows: .github/workflows/*.yml for build/deploy/test
- Patterns: Jobs, steps, actions (e.g., build-docker, lint-python)
- Git: .gitignore for exclusions
7. FKS APPS OVERVIEW
Each FKS app is a microservice with specific focus. Below are key structures/patterns based on codebase analysis.
7.1 fks_ai (AI Agents & Graph - Python-based, ~52 files)
- Role: Handles AI agents for analysis (macro, risk, sentiment, technical), debate logic, graph workflows, memory (Chroma), models (Lag-Llama, TimeCopilot), and processors.
- Structure: src/agents (analysts/debaters), src/api, src/evaluators, src/graph, src/memory, src/models, src/processors, tests (unit/integration).
- Patterns: State management (state.py), base classes (base.py), mocking in tests, async/await potential in main.py.
- Testing: Conftest, integration (API/E2E/ground truth), unit (analysts/debaters/graph/memory/signal/state).
- Deps: requirements-langgraph.txt, requirements.txt.
7.2 fks_api (Core API & Domain Logic - Python-based, ~235 files)
- Role: Central API for domains (analytics, events, market, ML, portfolio, risk, trading), framework (cache/config/exceptions/lifecycle/logging/middleware/patterns/services), infrastructure (database/external/messaging).
- Structure: src/domain (market/ml/portfolio/risk/trading with subdirs like backtesting/execution/strategies), src/framework (cache/config/exceptions/etc.), src/infrastructure (database/external/exchanges), src/routers, src/routes (v1/v2/monitoring).
- Patterns: Middleware (auth/circuit_breaker/cors/metrics/rate_limiter), exceptions handling, lifecycle management, enums/models in core.
- Testing: test_health.py, test_shared_import.py.
- Deps: requirements.dev.txt, requirements.txt.
7.3 fks_app (Strategies & Data Quality - Python-based, ~52 files)
- Role: Focuses on strategies (ASMBTR backtest/optimize/predict/strategy), evaluation (confusion matrix/statistical tests), features/metrics/validators for data quality.
- Structure: src/cache, src/database, src/evaluation, src/features, src/metrics, src/strategies/asmbtr, src/tasks, src/validators, tests/unit (data/strategies).
- Patterns: Caching (feature_cache), metrics collection (quality_collector/metrics), validators (completeness/freshness/outlier/quality_scorer).
- Testing: test_cache.py, test_database_connection.py, test_feature_processor.py, test_quality_collector.py, test_quality_metrics.py, test_validators.py, asmbtr-specific (btr/encoder/predictor/strategy).
- Deps: requirements.txt.
7.4 fks_auth (Auth & Shared Infra - Rust/Python mix, ~157 files)
- Role: Authentication service with shared Docker/scripts/rust/schema for infra, deployment, migration, QA.
- Structure: shared/actions/docs/templates, shared/docker (compose/scripts/templates), shared/rust (env/types/tests), shared/schema (json schemas), shared/scripts (deployment/dev/domains/migration/nginx/ninja/qa/ssl/typesync/utils), src/lib.rs/main.rs (Rust).
- Patterns: Rust structs/enums/traits, Python scripts (audit_dockerfiles/generate_env/compare-verify/sbom-diff), CI templates (ci-*.yml), actions (build-docker/deploy/lint/test).
- Testing: integration.rs, smoke_test.py, test-api.js, test_rithmic_integration.py.
- Deps: Cargo.toml/lock, requirements.txt.
7.5 fks_data (Data Collection & Processing - Python-based, ~239 files)
- Role: Data adapters/providers (Binance/EODHD/Polygon/etc.), collectors (forex/fundamentals), domain logic (analytics/events/market/ml/portfolio/risk/trading), pipelines (ETL/executor), validators/metrics.
- Structure: src/adapters, src/collectors, src/domain (market/ml/portfolio/risk/trading with subdirs), src/framework (cache/config/exceptions/etc.), src/infrastructure (database/external), src/providers, src/validators, tests.
- Patterns: Adapters/base classes, exception handling, lifecycle/middleware, quality metrics/validators (completeness/freshness/outlier/scorer).
- Testing: Numerous tests for adapters/bars/database/import/logging/manager/quality/repository/schema/smoke/validators.
- Deps: requirements.dev.txt, requirements.txt.
7.6 fks_execution (Execution & Plugins - Python/Rust mix, ~24 files)
- Role: Execution app with CCXT integration, exchanges/manager, metrics/security/validation/webhooks.
- Structure: exchanges (ccxt_plugin/manager), security/middleware, validation/normalizer, webhooks/tradingview, src/main.rs (Rust with plugins/mod/registry/tests).
- Patterns: Plugins (ccxt/mock/registry), Rust mods, Python middleware/security.
- Testing: webhook_integration_test.rs.
- Deps: Cargo.toml/lock, requirements.txt.
7.7 fks_main (Main App & Integration - Python-based, ~758 files)
- Role: Central hub with authentication, shared core/framework/monitor, staticfiles, tests (extensive integration/unit/performance), scripts (analyze/cleanup/deployment/dev/migration/qa/typesync/utils), SQL migrations, K8s manifests/charts, monitoring (Grafana/Prometheus), notebooks (transformer).
- Structure: src/authentication, src/shared/core/framework/monitor, src/staticfiles (admin/css/js/vendor), tests (fixtures/integration/performance/unit), scripts (actions/deployment/dev/domains/migration/nginx/ninja/qa/ssl/typesync/utils), k8s (charts/manifests/tests), monitoring (grafana/prometheus).
- Patterns: Django-style (admin/apps/migrations/models/serializers/urls/views), middleware/exceptions/lifecycle, extensive testing (backtest/celery/data/execution/rag/sentiment/trading).
- Testing: Conftest, integration (backtest/celery/data/execution/rag/tasks), performance (rag/trading), unit (data/evaluation/strategies/tasks/core/execution/rag/sentiment/trading/web).
- Deps: requirements.dev.txt, requirements.gpu.txt, requirements.txt.
7.8 fks_ninja (NinjaTrader Integration - C#/Python mix, ~162 files)
- Role: NinjaTrader package/addons/indicators/strategies, improvements/single_files for FKS (AI/AO/dashboard/PythonBridge/signals/strategy), scripts (build-api/linux/python), templates/manifest.
- Structure: fks-package (cs/xml/txt), improvements (cs/md/xml), scripts (cs/js/py), single_files (cs/md/txt/xml with backups/optimizations), src (AddOns/Indicators/Properties/Strategies/cs/xml).
- Patterns: C# classes (FKS_*/AssemblyInfo), Python scrapers (ninjatrader_*), optimization configs per asset (BTC/CL/ES/GC/NQ).
- Testing: None explicit, but build/test guides.
- Deps: package.json/lock.
7.9 fks_training (Training Pipelines - Python-based, ~430 files)
- Role: Training with dataset/manager/gpu_manager/models (baselines/time_series_cv), pipelines (base/ensemble/reinforcement/supervised), shared python/framework/schema/scripts similar to others.
- Structure: shared/actions/docs/templates, shared/docker, shared/python (apps/cli/config/exceptions/framework/logging/metrics/risk/runtime/simulation/tests/types/utils), shared/schema/scripts, src/domain (market/ml/portfolio/risk/trading), src/framework/infrastructure, src/models/pipelines, tests.
- Patterns: Pipelines/builder/executor, risk/hedge, simulation, types/training_types, middleware/exceptions/lifecycle.
- Testing: test_baselines_cv.py, test_health.py, test_import.py, shared tests (alias_imports/config/logging/market_bar/metrics/risk/risk_hedge/runtime_registry/schema/simulation/typesync/utils/features).
- Deps: requirements.dev.txt, requirements.txt.
7.10 fks_web (Web UI - Python/Django-based, ~184 files)
- Role: Web frontend with chatbot/config/db_helpers/forecasting/health/metrics/ninja/rag (document_processor/embeddings/ingestion/intelligence/local_llm/orchestrator/retrieval/services), staticfiles/templates.
- Structure: src/chatbot/config/forecasting/migrations/ninja/rag/static/templates, staticfiles (admin/css/img/js/vendor, css/js, rest_framework/css/docs/js).
- Patterns: Django apps/migrations/models/urls/views, RAG components, templates (base/pages/web).
- Testing: None explicit.
- Deps: requirements.txt.
BEST PRACTICES FOR FKS:
- Use shared/ for common code (e.g., shared/python, shared/rust)
- Standardize migrations in scripts/domains/migration/
- Ensure schemas in shared/schema/*.json
- Monitor with docker-compose.monitoring.yml
- CI: Use templates like ci-python.yml, release-please.yml
EOL
echo "Analysis complete!"
echo "- File structure: $OUTPUT_DIR/file_structure.txt"
echo "- Summary: $OUTPUT_DIR/summary.txt"
[ $FULL -eq 1 ] && echo "- Full code: $OUTPUT_DIR/full_code.txt"
[ $LINT -eq 1 ] && echo "- Lint report: $OUTPUT_DIR/lint_report.txt"
echo "- FKS guide: $OUTPUT_DIR/fks_analysis_guide.txt"