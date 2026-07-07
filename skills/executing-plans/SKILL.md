---
name: executing-plans
description: Use when you have a written implementation plan to execute - subagent-driven by default with a criteria-gated inline economy tier, plus pre-flight and per-task blast-radius analysis
---

# Executing Plans

## Overview

Execute an implementation plan. **Development is subagent-driven by default.** The controller (you) loads the plan, analyzes blast radius, dispatches fresh subagents per task, reviews between them, and reports when complete. A task may run **inline** (controller implements directly) only when it meets the Inline Execution criteria below — never by convenience.

**Announce at start:** "I'm using the executing-plans skill to implement this plan (subagent-driven)."

**Core principles:**
- **Controller coordinates, subagents implement (default).** Dispatching keeps your context clean for coordination and gives each task isolated, precisely-scoped context. Inline execution trades that isolation for token economy — allowed only inside the criteria below, because inline work lives in your context for the rest of the session and every later turn re-pays it.
- **Fresh subagent per task.** Subagents never inherit your session history — you construct exactly the context they need.
- **Two-tier blast radius.** A pre-flight analysis of the whole change surface once, plus a per-task compatibility check before each implementer runs.
- **Continuous execution.** Do not pause to check in between tasks. The only reasons to stop: an unresolvable BLOCKED status, a cascade gap the plan doesn't cover, or all tasks done.

**Prerequisite:** An isolated workspace exists (via `pressurecooker:using-git-worktrees`) and its clean baseline test count is recorded — that baseline is the regression reference for every must-stay-green check.

## Step 0: Load Plan

1. Read the plan file **once**.
2. Extract, into your own context: every task's full text, the plan's `Global Constraints`, the `Blast Radius` summary, and each task's `Impact:` (Breaks-risk + Must-stay-green).
3. Create a TodoWrite: one item for pre-flight blast radius, then one per task.
4. Never make a subagent read the plan file — you paste the full text it needs.

## Step 1: Pre-flight Blast Radius (once, before any task)

Dispatch a blast-radius analyst subagent (`./blast-radius-prompt.md`, preflight mode).

Give it: the plan's `Blast Radius` + `Global Constraints`, the list of fields/interfaces/contracts the plan adds or changes, a one-line-per-task list (task number, files, added/changed interfaces) for the per-task compat notes, access to the current codebase, and — if project memory holds a `map` consumer/contract graph (`docs/pressurecooker/memory/`) — that map, so it verifies deltas instead of cold discovery.

After pre-flight: write the confirmed/corrected consumer-contract map back to project memory (`type: map`, update the existing file, refresh its MEMORY.md line) so the next plan starts warm.

It answers, for the change as a whole:
- **Forward compatibility:** for each added/changed field or interface, does existing code keep working with it as-is?
- **Cascade:** does a change force *other* fields, records, call sites, or migrations to change too — ones the plan did NOT list?
- **Coverage:** are there existing tests exercising affected paths that the plan's must-stay-green set missed?

Output: a confirmed/expanded must-stay-green set, a list of **cascade gaps** (required changes not in the plan), and **per-task compat notes** — one per task, handed to that task's implementer in place of a separate per-task analyst dispatch.

**Gate:** If pre-flight finds cascade gaps the plan doesn't cover, **STOP**. Report them to the human and suggest updating the plan (back to `pressurecooker:writing-plans`). Do NOT silently implement beyond the plan's scope.

## Step 2: Per-Task Loop

For each task, in order. Every box below is a fresh subagent — you only coordinate — unless the task qualifies for the Inline Execution tier below.

**Ceremony scales to the task's `Risk:` tier** (from its Impact block; task missing a tier → treat as interface-changing — resolve up). Tiers relax ceremony ONLY — must-stay-green rules, Step 4b, and reference-only/secure-data checks never relax:

| Tier | (a) Per-task compat | (c)+(d) Reviews |
|------|---------------------|-----------------|
| additive | pre-flight compat note (no dispatch) | single combined reviewer (`./combined-reviewer-prompt.md`) — spec + quality + must-stay-green in one dispatch |
| modifying | pre-flight compat note; analyst dispatched only if the note is missing or the task's scope drifted since pre-flight | two-stage (spec, then quality) as below; economy mode ON and diff ≤2 files → single combined reviewer dispatch instead (still fresh eyes; use its modifying variant) |
| interface-changing | analyst always dispatched (per-task mode) | full two-stage as below |

**a. Per-task compatibility check** (per tier table). Default: hand the task's **pre-flight compat note** to the implementer — no dispatch. Dispatch the blast-radius analyst (`./blast-radius-prompt.md`, per-task mode) only where the table says: interface-changing tasks always; modifying tasks only when the note is missing or stale. Either way, if a cascade beyond the task's scope surfaces, decide: widen the task's context, or stop and escalate.

**b. Implementer** (always). Dispatch the implementer subagent (`./implementer-prompt.md`) with the task's full text, scene-setting context, the compat findings from (a) if any, the Must-stay-green set, and any reference-only paths / secure-data fields from Global Constraints. It does TDD, runs the Step 4b regression check, commits, self-reviews, reports status.

**c. Spec compliance review.** Additive tier: dispatch the combined reviewer instead (spec + quality in one; ❌ on either dimension loops the implementer, then re-review). Otherwise dispatch the spec reviewer (`./spec-reviewer-prompt.md`). If ❌, the implementer subagent fixes and the reviewer re-reviews. Loop until ✅.

**d. Code quality review** (modifying and interface-changing tiers). Only after spec is ✅. Dispatch the code quality reviewer (`./code-quality-reviewer-prompt.md`) — it also confirms the Must-stay-green set is still green and no cascade was left unhandled. If issues, implementer fixes, reviewer re-reviews. Loop until approved.

**Loop continuation:** fix/re-review loops CONTINUE the same agents instead of fresh dispatches. Send the implementer the reviewer's findings via SendMessage (its task context is already warm); send the reviewer "re-check findings N–M against commit `<sha>`" the same way — it re-verifies only the named findings plus must-stay-green, not the whole diff. Fresh dispatch only when continuation is unavailable (agent gone, platform lacks SendMessage) or the reviewer's verdict suggests it misread the task.

**e. Mark the task complete in TodoWrite.**

## Inline Execution (economy tier)

Inline = the controller implements the task itself instead of dispatching an implementer. It saves the dispatch cost (fresh context + file re-reads per subagent) but bloats controller context permanently — so it is criteria-gated, not a mood:

| Tier | Inline allowed? | Review requirement |
|------|-----------------|--------------------|
| additive | yes, if ≤2 files AND the task text is a complete spec | combined reviewer dispatch as usual; for trivial tasks (docs/config/no behavior change) the controller may instead run the combined reviewer checklist inline against the actual diff |
| modifying | only if every touched file was already read this session | fresh-eyes review dispatch stays MANDATORY — the controller reviewing its own inline work is the weakest check in the chain. Economy ON and diff ≤2 files → the single combined reviewer dispatch (modifying variant) satisfies this; otherwise spec + quality two-stage |
| interface-changing | never | — |

Rules that never relax inline: TDD (failing test first), the Step 4b must-stay-green run, reference-only paths, secure-data handling, and `pressurecooker:verification-before-completion` evidence. Inline changes commit per task exactly like an implementer would.

**Choosing:** honor the task's `Execution:` stamp when the plan carries one (from `pressurecooker:writing-plans`). Without a stamp: economy mode ON (session-start reports it) → inline-first wherever the table allows; economy mode OFF → dispatch by default and go inline only with a one-line declared deviation ("running Task N inline: additive, 1 file, spec complete").

**Token heuristic (both directions):** inline is cheaper for small tasks over files already in context; a subagent is cheaper for anything that would pull many new files into the controller — a broad exploration done inline is paid again on every subsequent turn.

## Batching Additive Tasks

Consecutive additive tasks may share ONE implementer dispatch and ONE combined review when ALL hold:
- every task in the batch is `Risk: additive` with a complete-spec task text
- their `Files:` sets are disjoint
- no task `Consumes:` another batch member's `Produces:` output — a dependency chain inside a batch is fine only in plan order within the single dispatch

Mechanics: paste ALL task texts into one implementer dispatch; the implementer runs the full cycle (failing test → green → Step 4b → commit) **per task, in plan order** — never one blended commit. One combined reviewer dispatch covers the batch diff with a per-task verdict; a ❌ loops the implementer on that task only. TodoWrite items stay one per task.

## Concurrency (gated)

Serial is the default. Two gated exceptions, both requiring the pre-flight report to certify **file-disjointness** (no shared `Files:`, no overlapping cascade targets) and **no `Consumes:`/`Produces:` dependency** between the tasks involved:

- **Pipeline overlap.** While task N's reviews run, dispatch the implementer for task N+1 if N+1 is disjoint from N. N's fix loop and N+1's implementation can't collide — that's what disjointness buys. If N's review fails in a way that invalidates N+1's premise (rare — means they weren't really disjoint), stop N+1 and re-run it after.
- **Parallel implementers.** Disjoint-certified tasks may run in parallel, EACH in its own isolated worktree (Agent `isolation: worktree`). The controller merges results in plan order and runs the combined must-stay-green set after each merge. Any merge conflict = the disjointness call was wrong: stop parallel dispatch for the rest of the plan, fall back to serial.

Without pre-flight certification, neither applies — guessing disjointness trades speed for merge conflicts.

## Step 3: Complete Development

After all tasks pass both reviews:
- Dispatch a final code reviewer subagent over the entire implementation, including a full regression run against the recorded baseline.
- Announce: "I'm using the finishing-a-development-branch skill to complete this work."
- **REQUIRED SUB-SKILL:** Use `pressurecooker:finishing-a-development-branch`.

## Model Routing

Judgment roles stay on the capable model; mechanical execution and checklist verification go to the fast model:

| Role | Model |
|------|-------|
| Controller (this session) | Opus 4.8 |
| Pre-flight blast-radius analyst | Opus 4.8 (dispatch with `model` override — investigator agent defaults to Sonnet) |
| Per-task analyst (fallback dispatches only, per tier table) | investigator default (Sonnet) |
| Implementer — mechanical (1-2 files, complete spec in task) | Haiku 4.5 (`model` override on the dispatch) |
| Implementer — integration/judgment (multi-file, pattern matching, debugging) | Opus 4.8 |
| Spec reviewer / combined reviewer (additive) | Haiku 4.5 (`model` override) |
| Combined reviewer (modifying variant, economy) | investigator default (Sonnet) |
| Code quality reviewer (modifying) | investigator default (Sonnet) |
| Code quality reviewer (interface-changing) | Opus 4.8 (`model` override) |

The `pressurecooker:investigator` agent carries `model: sonnet` in its definition — the cheap default for read-only work; the dispatch-time `model` parameter overrides it in either direction per this table. `pressurecooker:implementer` inherits the session model unless overridden. A cheap-model subagent reporting BLOCKED for reasoning depth → re-dispatch on Opus (see Handling Implementer Status). Substitute the current-generation equivalents if these models age out.

## Handling Implementer Status

- **DONE:** Proceed to spec review.
- **DONE_WITH_CONCERNS:** Read the concerns first. If about correctness/scope/compat, address before review; if observations, note and proceed.
- **NEEDS_CONTEXT:** Provide the missing context, re-dispatch.
- **BLOCKED:** Assess — context problem (re-dispatch with more context), needs more reasoning (re-dispatch with a more capable model), too large (break into pieces), or plan is wrong (escalate to human). Never force the same model to retry unchanged.

## When to Stop and Ask for Help

**STOP when:**
- Pre-flight or a per-task check finds a cascade gap the plan doesn't cover
- A blocker you can't resolve (missing dependency, unclear instruction)
- Verification fails repeatedly

**When a regression goes red** (an existing must-stay-green test breaks) or a bug surfaces during execution: do NOT patch symptoms or loosen tests. **REQUIRED SUB-SKILL:** Use `pressurecooker:systematic-debugging` — investigation runs through its evidence-gatherer subagent (the controller still never edits), fixes go through an implementer subagent. If it reveals an architecture problem the plan didn't anticipate, stop and escalate.

**Ask rather than guess.**

## Red Flags

**Never:**
- Implement in the controller outside the Inline Execution criteria — inline is a gated economy tier, not a convenience default
- Start implementation on main/master without explicit user consent
- Skip the pre-flight blast radius or a per-task compat check
- Proceed past a cascade gap without updating the plan
- Skip the reviews the task's tier requires (two-stage for modifying/interface-changing; combined for additive), or run quality before spec is ✅
- Use the additive shortcut on a task that modifies existing behavior (TIER-MISMATCH from the combined reviewer → re-run through the full flow)
- Dispatch multiple implementer subagents in parallel outside the Concurrency gate (shared files = conflicts)
- Batch tasks that aren't all additive/disjoint/complete-spec, or let a batch produce one blended commit
- Make a subagent read the plan file (paste full text instead)
- Treat a green new test with a broken must-stay-green test as progress — it's a regression; route to `pressurecooker:systematic-debugging`, never patch the symptom or loosen the test
- Edit files under reference-only paths (Global Constraints) — samples are read-only; a task that seems to require it means the plan is wrong, escalate

## Integration

**Required workflow skills:**
- **pressurecooker:using-git-worktrees** — isolated workspace + baseline regression reference
- **pressurecooker:writing-plans** — creates the plan (with Blast Radius + per-task Impact) this skill executes
- **pressurecooker:systematic-debugging** — any red regression or bug during execution routes there (root cause, never symptom patches)
- **pressurecooker:finishing-a-development-branch** — complete development after all tasks

**Prompt templates (in this skill directory):**
- `./blast-radius-prompt.md` — pre-flight and per-task blast-radius analyst
- `./implementer-prompt.md` — implementer subagent (TDD + regression)
- `./spec-reviewer-prompt.md` — spec compliance reviewer
- `./code-quality-reviewer-prompt.md` — code quality + regression reviewer
- `./combined-reviewer-prompt.md` — single-dispatch spec+quality reviewer for additive-tier tasks
```
