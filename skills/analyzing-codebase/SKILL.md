---
name: analyzing-codebase
description: Use before brainstorming or planning any big feature, when entering an unfamiliar codebase, or when the codebase map is stale or missing - produces the architecture, stack, duplication, and call-graph map plus ranked refactoring issues that downstream skills consume
---

# Analyzing Codebase

## Overview

Read-only reconnaissance that turns a codebase into a **committed virtual map** — architecture, stack, duplication hotspots, module call graph, and the top 5 refactoring issues. Downstream skills consume it: brainstorming starts from it, blast-radius analysts look up consumers in it, systematic-debugging's extraction phase starts from its duplication report.

**Announce at start:** "I'm using the analyzing-codebase skill to map the codebase."

## Absolute Constraints

- **No code modifications in this workflow.** The ONLY files this skill writes are the map artifacts under `docs/pressurecooker/codebase-map/`. No fixes, no cleanups, no "trivial" typo/unused-import commits — an analysis pass that edits code produces unreviewed changes and pollutes the baseline. Anything broken you notice gets LOGGED in the map's findings, not touched.
- **Never skip the duplication step** — it determines the order of subsequent actions.
- **Always present call graph and duplicate report results, even if numbers are low.** "4 modules, no cycles, 1% duplication" is a finding — it anchors trust in the rest of the map and downstream skills consume the numbers, not your impression of them.
- **The map never contains secret values.** A hardcoded secret found during analysis goes in Risks as file:line + kind, flagged Critical (needs rotation + relocation) — never the value itself (`pressurecooker:secure-data-handling`).

Violating the letter of these constraints is violating the spirit of the skill.

## When to Use

- Before `pressurecooker:brainstorming` on any big feature
- Entering an unfamiliar or inherited codebase
- Map missing, or stale (see Staleness below)

**Skip only when** the map is fresh — then read it instead of re-analyzing.

## Workflow

Run steps in order. On large codebases (>~50 files), dispatch read-only analyst subagents per step to keep your context clean — same pattern as executing-plans; you synthesize their reports into the map.

### Step 1: Stack Inventory

Manifests first: `package.json`/lockfile, `pyproject.toml`/`requirements`, `go.mod`, `Cargo.toml`, CI config, Dockerfiles. Record: languages, frameworks + versions (flag EOL), build/test tooling and commands, key dependencies, how it runs.

### Step 2: Architecture Pass

Entry points → routing/dispatch → business logic → data layer. Answer: what are the layers and do they hold? Where does business logic actually live? What are the module boundaries and responsibilities? Error handling, config, auth — pattern or scattered? Note conventions (naming, file layout, test style) — downstream implementers must match them.

### Step 3: Duplication Scan — NEVER SKIPPED

Run `./scan-duplication.sh <src-dir>` (jscpd; language-agnostic). Tooling missing → the script says so; do a heuristic pass instead (repeated function names, similar file pairs, parallel directory structures). "Codebase too small to bother" is not an exemption — the scan costs under a minute at any size, and small codebases duplicate too.

**The result orders everything after it:**
- **Significant duplication** (drifted copies of the same logic, or >~5%): the deep-dive (Step 4b) targets the duplicated clusters FIRST, and duplication-driven items lead the Top 5 (Step 6). Drifted copies of one concept are the highest-value refactor class this skill can find — they are where the next bug is manufactured (see systematic-debugging Phase 5).
- **Low duplication:** deep-dive follows churn × complexity instead, and the Top 5 leads with coupling/architecture findings.

### Step 4: Call Graph

Run `./scan-callgraph.sh <src-dir>` (madge / pydeps / go list / grep-imports fallback). Record: module dependency summary, circular dependencies, fan-in hotspots (most-imported modules = highest blast radius). Combine with churn (`git log --format= --name-only | sort | uniq -c | sort -rn | head -30`): churn × fan-in = the files where change is riskiest.

### Step 4b: Hotspot Deep-Dive

Open the top files the scans point at — order per Step 3. Look for patterns, not instances: god modules, `utils` dumping grounds, shared mutable state, logic-in-controllers. This is where the Top 5 gets its evidence (`file:line` references).

### Step 5: Write the Map

Write `docs/pressurecooker/codebase-map/MAP.md`:

```markdown
# Codebase Map: <project>
analyzed-at: <commit hash>   date: <YYYY-MM-DD>   scope: <src dirs analyzed>

## Stack
[languages, frameworks + versions, build/test commands, key deps, EOL flags]

## Architecture
[layers, request/data flow, module responsibilities — one line per module]

## Module Graph
[mermaid graph of module dependencies + fan-in table. ALWAYS present,
even if trivial: "4 modules, no cycles" is the finding.]

## Duplication Report
[jscpd numbers + clusters of drifted copies with file:line. ALWAYS present,
even if low: "1.2%, no drifted logic" is the finding.]

## Conventions
[naming, layout, test style — what implementers must match]

## Risks & Observations
[broken/suspicious things NOTICED but not touched — this is the no-modification
constraint's outlet; each may become a spawned task or debugging session]

## Top 5 Refactoring Issues
[see Step 6 format]
```

Written in normal prose (chain convention: artifacts are never caveman). Commit the map — it's a build artifact of this skill, the one write this workflow is allowed.

### Step 6: Top 5 Refactoring Issues

Ranked by (duplication severity if Step 3 was significant, else coupling/churn × complexity) and by relevance to upcoming work. Each issue:

```
N. <name>
   What: [the structural problem, file:line evidence]
   Why it costs: [bug class it manufactures / velocity it burns]
   Blast radius: [consumers affected, must-stay-green candidates]
   Size: S / M / L
```

Each entry is a ready `pressurecooker:writing-plans` input — executed under its **Refactoring Plans** rules (characterization tests first, one module per task, test gate every task). **None of them get fixed in this workflow.**

## Staleness & Updates

- Consumers check: `git rev-list --count <analyzed-at-hash>..HEAD` — over ~30 commits (or the map's scope was directly restructured) → recommend re-analysis before relying on it.
- After a merged branch, `pressurecooker:finishing-a-development-branch` triggers a **delta update**: re-scan only the touched modules, refresh the affected map sections and `analyzed-at`, keep the rest.
- Full re-analysis only on major restructuring — delta is the default (KISS).

## Common Rationalizations

| Excuse | Reality |
|--------|---------|
| "Codebase too small — scans are theater" | The scan costs <1 minute at any size, its result sets the workflow order, and small codebases duplicate too. Run it. |
| "I'll skip it from the report, not from the work" / "private appendix" | The map IS the deliverable and machines consume it (blast-radius, debugging). Results go IN the map, always. |
| "Boring numbers, leave them out" | Boring numbers are findings — they anchor trust and prove coverage. "No cycles" saves the next analyst a cold search. |
| "Fix trivia while I'm in there — separate commit makes it clean" | Analysis with edits = unreviewed changes + polluted baseline. Log in Risks, don't touch. |
| "An obvious null check is harmless" | It's a behavior change wearing a cleanup costume. Log it; it may be a systematic-debugging session. |
| "No time for the mechanical steps" | Scans are the fastest steps in the workflow. Cut deep-dive breadth under time pressure, never the scans. |

## Red Flags — STOP

- About to edit ANY file outside `docs/pressurecooker/codebase-map/`
- Skipping or deferring the duplication scan for any reason
- Map missing the call graph or duplication section, or results summarized away ("fine, nothing notable" without numbers)
- Recommending a fix inline instead of logging it as a Top 5 / Risks entry

## Integration

- **pressurecooker:brainstorming** — "Explore project context" starts by reading a fresh `MAP.md`; re-explore only what the map lacks
- **pressurecooker:writing-plans / executing-plans** — blast-radius analysis (Impact Assessment + analyst subagents) uses the map's fan-in table and consumers before cold-grepping
- **pressurecooker:systematic-debugging** — Phase 5 "enumerate ALL copies" starts from the map's Duplication Report; the architecture-confusion check cross-references the module graph
- **pressurecooker:finishing-a-development-branch** — post-merge delta update keeps the map alive

**Scripts (this directory):** `./scan-duplication.sh`, `./scan-callgraph.sh` — read-only, always exit 0, print fallback instructions when tooling is missing.
