#!/usr/bin/env bash
# Module-level dependency/call-graph scan for analyzing-codebase skill.
# Read-only. Best-effort per ecosystem; always exits 0 — the agent reads
# stdout and falls back to grep-imports heuristics when tooling is missing.
#
# Usage: ./scan-callgraph.sh <source-dir>
set -u

SRC="${1:?usage: scan-callgraph.sh <source-dir>}"

echo "=== callgraph scan: $SRC ==="

if [ -f "$SRC/package.json" ] && command -v npx >/dev/null 2>&1; then
  echo "--- JS/TS (madge) ---"
  npx --yes madge --summary "$SRC" 2>&1
  echo "--- circular dependencies ---"
  npx --yes madge --circular "$SRC" 2>&1
  exit 0
fi

if ls "$SRC"/*.py "$SRC"/**/*.py >/dev/null 2>&1; then
  if command -v pydeps >/dev/null 2>&1; then
    echo "--- Python (pydeps) ---"
    pydeps "$SRC" --show-deps --no-output 2>&1
    exit 0
  fi
  echo "--- Python (import grep fallback) ---"
  grep -rEh '^(import|from) ' "$SRC" --include='*.py' | sort | uniq -c | sort -rn | head -60
  exit 0
fi

if [ -f "$SRC/go.mod" ] && command -v go >/dev/null 2>&1; then
  echo "--- Go (go list) ---"
  (cd "$SRC" && go list -deps ./... 2>&1 | head -80)
  exit 0
fi

echo "--- generic import grep fallback ---"
grep -rEh '(^|[[:space:]])(import|require|include|use)[[:space:](]' "$SRC" \
  --include='*.js' --include='*.ts' --include='*.tsx' --include='*.rb' \
  --include='*.rs' --include='*.java' --include='*.php' --include='*.cs' \
  2>/dev/null | sort | uniq -c | sort -rn | head -60
echo "TOOLING-PARTIAL: generic fallback used. Agent should trace key module imports manually."
exit 0
