#!/usr/bin/env bash
# SessionStart hook for the pressurecooker plugin.
# 1. Verifies the `caveman` dependency (fallback for cross-marketplace installs).
# 2. Injects the skill-routing map so pressurecooker skills fire without being remembered.
# 3. Surfaces codebase-map staleness when a map exists.
set -euo pipefail

plugins_root="${HOME}/.claude/plugins/cache"
project_dir="${CLAUDE_PROJECT_DIR:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"

# --- caveman dependency check ---
if compgen -G "${plugins_root}/*/caveman/*/.claude-plugin/plugin.json" >/dev/null 2>&1 \
   || compgen -G "${plugins_root}/*/caveman/.claude-plugin/plugin.json" >/dev/null 2>&1; then
  dep_line="caveman dependency present."
else
  dep_line="WARNING: required plugin \`caveman\` not detected. Install it: /plugin install caveman@caveman"
fi

# --- codebase map staleness ---
map_file="${project_dir}/docs/pressurecooker/codebase-map/MAP.md"
map_line="No codebase map found — run pressurecooker:analyzing-codebase before brainstorming any big feature."
if [ -f "$map_file" ]; then
  map_hash=$(grep -m1 '^analyzed-at:' "$map_file" | awk '{print $2}' || true)
  if [ -n "${map_hash:-}" ] && git -C "$project_dir" rev-parse --verify -q "$map_hash" >/dev/null 2>&1; then
    drift=$(git -C "$project_dir" rev-list --count "${map_hash}..HEAD" 2>/dev/null || echo "?")
    if [ "$drift" != "?" ] && [ "$drift" -gt 30 ]; then
      map_line="Codebase map is STALE (${drift} commits behind) — refresh via pressurecooker:analyzing-codebase before relying on it."
    else
      map_line="Codebase map present (${drift:-?} commits behind): docs/pressurecooker/codebase-map/MAP.md — read it before exploring."
    fi
  else
    map_line="Codebase map present but analyzed-at hash unreadable — verify docs/pressurecooker/codebase-map/MAP.md freshness manually."
  fi
fi

# --- project memory index (fable mode) ---
memory_index="${project_dir}/docs/pressurecooker/memory/MEMORY.md"
memory_block=""
if [ -s "$memory_index" ]; then
  memory_block="

PROJECT MEMORY INDEX (docs/pressurecooker/memory/ — read individual memory files on demand; memories are hints, verify against current code before relying on them):
$(cat "$memory_index")"
fi

# --- economy mode (inline-first execution to save tokens) ---
economy_line="ECONOMY MODE: off — subagent-driven default; inline execution needs a declared deviation or a plan Execution stamp."
if [ "${PRESSURECOOKER_ECONOMY:-0}" = "1" ] || [ -f "${project_dir}/docs/pressurecooker/ECONOMY" ]; then
  economy_line="ECONOMY MODE: ON — inline-first execution. Run investigations and eligible tasks inline per the executing-plans Inline Execution table and systematic-debugging context rules; dispatch subagents only for wide exploration, interface-changing work, and the reviews the tier table mandates. Must-stay-green, TDD, and review requirements never relax."
fi

# --- skill routing map (the dispatcher) ---
routing=$(cat <<'EOF'
PRESSURECOOKER ROUTING — invoke the matching skill via the Skill tool BEFORE acting:
- New folder dropped/referenced with unclear role -> pressurecooker:incoming-folder-triage
- Big feature, unfamiliar codebase, or stale/missing map -> pressurecooker:analyzing-codebase
- Any creative work (feature, component, behavior change) -> pressurecooker:brainstorming (hard gate: design approval before implementation)
- Approved spec/requirements, multi-step work -> pressurecooker:writing-plans (refactors follow its Refactoring Plans rules: characterization tests first, one module per task)
- Executing a written plan -> pressurecooker:using-git-worktrees then pressurecooker:executing-plans (subagent-driven by default; inline economy tier per its criteria)
- ANY bug, test failure, regression, or unexpected behavior -> pressurecooker:systematic-debugging BEFORE proposing fixes (root cause, never symptom patches)
- Small clear fix not worth the full chain -> pressurecooker:quick-task (still test-first; escalates when scope grows)
- Writing ANY implementation code -> pressurecooker:test-driven-development (failing test first, no exceptions)
- Code touching credentials, tokens, PII, payment or other secure data -> pressurecooker:secure-data-handling (secrets never surface in logs, output, commits, artifacts)
- About to claim done/fixed/passing, or commit/PR -> pressurecooker:verification-before-completion (evidence before claims)
- All tasks done, integrating work -> pressurecooker:finishing-a-development-branch
- Coding sessions default to pressurecooker:silent-dev output discipline (minimal narration; artifacts stay normal prose)

SUBAGENT DISPATCH DISCIPLINE — MANDATORY, two rules:

RULE 1 — agent type. EVERY subagent you dispatch uses a pressurecooker agent type, whose system prompt enforces silence (a prompt footer alone loses to the default agent system prompt, which tells agents to narrate):
- Task writes/edits/commits files -> subagent_type: pressurecooker:implementer
- Task only reads, analyzes, reviews, investigates -> subagent_type: pressurecooker:investigator
- Fall back to general-purpose/Explore ONLY if these types are unavailable, or for built-in specialist agents the task genuinely needs.

RULE 2 — footer. EVERY subagent prompt — skill templates, Explore, reviewers, quick fixes, freeform Agent/Task calls, ALL of them, including pressurecooker-typed dispatches (belt-and-braces) — MUST end with this block VERBATIM:

  Output discipline (MANDATORY):
  - Work SILENT. NO text between tool calls — no preamble, no plan announcements,
    no progress narration, no findings-as-you-go. Only text you may emit: blocking
    questions before starting (if any), then the single final report.
  - Final report: caveman-compressed — drop articles, filler, hedging, pleasantries;
    fragments fine. Technical terms, file:line refs, numbers, and quoted errors stay
    EXACT. NO code echoes or diff dumps — reference file:line instead; changes are
    verified in git/PR, not in the report.
  - Shortest report that carries every required field; one line per finding.
  - Code, comments, commit messages: normal prose, never caveman.

Skill prompt templates already embed this block and name the agent type — keep both when adapting them. Dispatching a subagent without the type (when available) or without the footer is a routing violation.
EOF
)

ctx="pressurecooker plugin loaded. ${dep_line} ${map_line} ${economy_line}${memory_block}

${routing}"

# JSON-escape via jq if available, else minimal escaper.
if command -v jq >/dev/null 2>&1; then
  ctx_json=$(printf '%s' "$ctx" | jq -Rs .)
else
  ctx_json="\"$(printf '%s' "$ctx" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g' | awk '{printf "%s\\n", $0}')\""
fi

cat <<JSON
{
  "hookSpecificOutput": {
    "hookEventName": "SessionStart",
    "additionalContext": ${ctx_json}
  }
}
JSON
