# Fable Mode: Project Memory, Learning Loop, and Resource-Tiered Execution

**Date:** 2026-07-04
**Status:** Implemented 2026-07-04 (plan: `docs/pressurecooker/plans/2026-07-04-fable-mode.md`)

## Goal

Make pressureCooker behave more like a Fable-5-class harness on Opus 4.8: remember the
project across sessions, improve its own workflow from feedback, and spend far fewer
tokens by scaling ceremony and model choice to task risk.

## Motivation

Today the skill chain is stateless and fixed-cost:

- Every session re-explores the project from scratch (brainstorming step 1, blast-radius
  consumer discovery, test-command detection in using-git-worktrees).
- Review findings, missed cascades, and regression causes die with the session — nothing
  feeds back into future plans.
- executing-plans dispatches 4 subagents per task (blast-radius analyst, implementer,
  spec reviewer, code quality reviewer) regardless of whether the task is trivially
  additive or interface-breaking.

## Component 1: Committed Project Memory Store

**Location:** `docs/pressurecooker/memory/` in the target project's repository,
committed to git. This matches the existing `docs/pressurecooker/{specs,plans}/`
convention, makes memory reviewable in PRs, and shares it with the whole team.

**Format** (mirrors the Fable memory model):

- `MEMORY.md` — the index. One line per memory:
  `- [title](file.md) — one-line hook`. This is the only file injected at session start,
  so it must stay small (soft cap: 30 lines; consolidate when exceeded).
- One fact per file, with frontmatter:

  ```markdown
  ---
  name: <kebab-case-slug>
  description: <one-line summary>
  type: map | retro | convention
  ---

  <the fact>
  ```

**Memory types:**

- `map` — project facts the chain re-derives today: test command, baseline suite shape,
  module → consumers/contracts graph, architecture notes.
- `retro` — lessons from completed branches: what reviews caught, cascades the plan
  missed, regressions and their causes.
- `convention` — durable project decisions (naming, patterns, boundaries) surfaced
  during brainstorming or review.

**Hygiene rules (enforced by every writer):**

- Update the existing file rather than creating a near-duplicate; delete memories proven
  wrong.
- Never store what git history or the code itself already records.
- Memories are hints, not ground truth: readers verify a memory against the current
  codebase before relying on it (cheap spot-check, not full re-derivation).
- Memory files are written in normal prose, not caveman — they are artifacts.

## Component 2: SessionStart Injection

Extend `hooks/session-start.sh`: after the existing caveman dependency check, if
`docs/pressurecooker/memory/MEMORY.md` exists under the project root, append its
contents to the hook's `additionalContext`.

Implementation constraints:

- Resolve the project root via `$CLAUDE_PROJECT_DIR` (fall back to
  `git rev-parse --show-toplevel`, then CWD).
- The current script interpolates a shell variable directly into a JSON heredoc; raw
  markdown will break that. Build the JSON with `jq -n --arg` (or equivalent proper
  escaping) instead.
- Inject only the index, never the individual memory files — skills read those on demand.

## Component 3: Memory Writers and Readers in the Chain

Each skill gains one small read step and/or write step:

| Skill | Reads | Writes |
|---|---|---|
| brainstorming | `map` (skip re-exploring what the map covers; verify staleness cheaply), `convention` | new/updated `convention` memories surfaced during design |
| writing-plans | `retro` (past misses become plan checklist items), `map` (consumer graph feeds Blast Radius) | — |
| using-git-worktrees | `map` (test command; skip auto-detection when present) | test command + baseline shape into `map` |
| executing-plans (pre-flight) | `map` consumer graph (analyst receives cached map, verifies deltas only instead of full discovery) | updated consumer/contract map from pre-flight findings |
| finishing-a-development-branch | — | `retro`: what reviews caught, cascade gaps found at execution time, regressions hit and their causes |

The retro write in finishing-a-development-branch is the learning loop's engine: it runs
after the branch-level regression gate passes, appends one `retro` memory (or updates an
existing recurring one), and updates `MEMORY.md`. writing-plans' self-review gains a
check: "did you consult retros, and does the plan repeat a recorded past miss?"

## Component 4: Risk-Tiered Execution

**writing-plans:** each task's `Impact:` block gains a `Risk:` line, derived
mechanically:

- `additive` — Breaks-risk is empty; task only adds new code with no existing consumers.
- `modifying` — touches existing code/behavior but no public interface or contract
  changes.
- `interface-changing` — changes a public interface, schema, serialized format, or any
  contract with consumers outside the task's files.

**executing-plans:** per-task ceremony scales to the tier:

| Tier | Per-task blast-radius analyst | Reviews |
|---|---|---|
| additive | skipped | single combined reviewer (spec compliance + quality + must-stay-green in one dispatch) |
| modifying | skipped when the pre-flight report already covers the touched area; otherwise dispatched | spec review, then quality review (current two-stage) |
| interface-changing | always dispatched | full two-stage review |

Pre-flight blast radius always runs once regardless of tiers. The combined reviewer for
additive tasks is a new prompt template (`combined-reviewer-prompt.md`) merging the spec
and quality checklists; a ❌ on either dimension loops the implementer as today.

Expected effect: additive tasks drop from 4 subagent dispatches to 2.

## Component 5: Explicit Model Routing

Replace executing-plans' vague "least powerful model" guidance with a concrete table:

| Role | Model |
|---|---|
| Controller (the session itself) | Opus 4.8 |
| Pre-flight blast-radius analyst | Opus 4.8 |
| Per-task analyst (whenever the tier table dispatches one) | Opus 4.8 |
| Implementer — mechanical (1-2 files, complete spec in task) | Haiku 4.5 |
| Implementer — integration/judgment (multi-file, debugging) | Opus 4.8 |
| Spec reviewer / combined reviewer (additive) | Haiku 4.5 |
| Code quality reviewer (modifying, interface-changing) | Opus 4.8 |

Rule of thumb stated in the skill: judgment roles stay on Opus; mechanical execution and
checklist verification go to Haiku. If a Haiku subagent reports BLOCKED for reasoning
depth, re-dispatch on Opus (this rule already exists in Handling Implementer Status).

## Out of Scope

- No MCP server, no external storage — memory is plain committed markdown.
- No conversation-transcript mining (mempal/MemPalace territory; pressureCooker memory
  stores project facts only).
- No changes to incoming-folder-triage or the reference-only mechanism.
- No global (`~/.config/pressurecooker/`) memory tier — committed-only, per user
  decision 2026-07-04.

## Edge Cases

- **Memory index missing/empty:** every reader falls back to today's behavior (full
  exploration). Memory is an accelerator, never a dependency.
- **Stale map (code moved on):** readers spot-check before trusting; a wrong map entry
  is corrected or deleted by whoever finds it — same session.
- **Merge conflicts in MEMORY.md:** one line per memory keeps conflicts trivial;
  resolution rule is "keep both lines, dedupe files later" (consolidation is a hygiene
  task, not a blocker).
- **Risk tier ambiguity:** when in doubt between tiers, pick the higher one. Cheap
  insurance; the tiers only ever relax ceremony, never the must-stay-green rules.
- **Worktree sessions:** memory lives in the repo, so worktrees see it automatically;
  retro writes from a worktree merge back with the branch.

## Success Criteria

- Second session on a project skips test-command detection and cold consumer discovery.
- A cascade gap found at execution time appears as a `retro` and surfaces in the next
  plan's self-review.
- An all-additive plan executes with 2 subagents per task, mechanical roles on Haiku.
- Full-suite regression gates and must-stay-green semantics unchanged — resource cuts
  never weaken the safety rails.
