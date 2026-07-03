#!/usr/bin/env bash
# Duplication scan for analyzing-codebase skill. Read-only; writes report JSON
# to the map directory only. Exits 0 even when tooling is missing — the agent
# reads stdout and falls back to heuristic analysis.
#
# Usage: ./scan-duplication.sh <source-dir> [map-dir]
set -u

SRC="${1:?usage: scan-duplication.sh <source-dir> [map-dir]}"
MAP_DIR="${2:-docs/pressurecooker/codebase-map}"

if ! command -v npx >/dev/null 2>&1; then
  echo "TOOLING-MISSING: npx not available. Fall back to agent heuristic scan:"
  echo "  grep for repeated function names, similar file pairs, copy-paste markers."
  exit 0
fi

mkdir -p "$MAP_DIR"

# jscpd is language-agnostic (150+ formats). min-tokens 50 filters noise.
npx --yes jscpd "$SRC" \
  --min-tokens 50 \
  --reporters consoleFull,json \
  --output "$MAP_DIR" \
  --ignore "**/node_modules/**,**/dist/**,**/build/**,**/.git/**,**/vendor/**,**/*.min.*" \
  2>&1

STATUS=$?
if [ $STATUS -ne 0 ]; then
  echo "TOOLING-FAILED: jscpd exited $STATUS. Fall back to agent heuristic scan."
fi
echo "REPORT: $MAP_DIR/jscpd-report.json (if generated)"
exit 0
