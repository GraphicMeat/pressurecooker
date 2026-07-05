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

Give it: the plan's `Blast Radius` + `Global Constraints`, the list of fields/interfaces/contracts the plan adds or changes, access to the current codebase, and — if project memory holds a `map` consumer/contract graph (`docs/pressurecooker/memory/`) — that map, so it verifies deltas instead of cold discovery.

After pre-flight: write the confirmed/corrected consumer-contract map back to project memory (`type: map`, update the existing file, refresh its MEMORY.md line) so the next plan starts warm.

It answers, for the change as a whole:
- **Forward compatibility:** for each added/changed field or interface, does existing code keep working with it as-is?
- **Cascade:** does a change force *other* fields, records, call sites, or migrations to change too — ones the plan did NOT list?
- **Coverage:** are there existing tests exercising affected paths that the plan's must-stay-green set missed?

Output: a confirmed/expanded must-stay-green set, and a list of **cascade gaps** (required changes not in the plan).

**Gate:** If pre-flight finds cascade gaps the plan doesn't cover, **STOP**. Report them to the human and suggest updating the plan (back to `pressurecooker:writing-plans`). Do NOT silently implement beyond the plan's scope.

## Step 2: Per-Task Loop

For each task, in order. Every box below is a fresh subagent — you only coordinate — unless the task qualifies for the Inline Execution tier below.

**Ceremony scales to the task's `Risk:` tier** (from its Impact block; task missing a tier → treat as interface-changing — resolve up). Tiers relax ceremony ONLY — must-stay-green rules, Step 4b, and reference-only/secure-data checks never relax:

| Tier | (a) Per-task analyst | (c)+(d) Reviews |
|------|---------------------|-----------------|
| additive | skipped | single combined reviewer (`./combined-reviewer-prompt.md`) — spec + quality + must-stay-green in one dispatch |
| modifying | skipped when the pre-flight report already covers the touched area; otherwise dispatched | two-stage (spec, then quality) as below |
| interface-changing | always dispatched | full two-stage as below |

**a. Per-task compatibility check** (per tier table). Dispatch the blast-radius analyst (`./blast-radius-prompt.md`, per-task mode) scoped to THIS task's added/changed fields only. Lighter than pre-flight: does this task's change work with existing consumers, and does it cascade to fields the task doesn't touch? Hand its findings to the implementer. If it surfaces a cascade beyond the task's scope, decide: widen the task's context, or stop and escalate.

**b. Implementer** (always). Dispatch the implementer subagent (`./implementer-prompt.md`) with the task's full text, scene-setting context, the compat findings from (a) if any, the Must-stay-green set, and any reference-only paths / secure-data fields from Global Constraints. It does TDD, runs the Step 4b regression check, commits, self-reviews, reports status.

**c. Spec compliance review.** Additive tier: dispatch the combined reviewer instead (spec + quality in one; ❌ on either dimension loops the implementer, then re-review). Otherwise dispatch the spec reviewer (`./spec-reviewer-prompt.md`). If ❌, the implementer subagent fixes and the reviewer re-reviews. Loop until ✅.

**d. Code quality review** (modifying and interface-changing tiers). Only after spec is ✅. Dispatch the code quality reviewer (`./code-quality-reviewer-prompt.md`) — it also confirms the Must-stay-green set is still green and no cascade was left unhandled. If issues, implementer fixes, reviewer re-reviews. Loop until approved.

**e. Mark the task complete in TodoWrite.**

## Inline Execution (economy tier)

Inline = the controller implements the task itself instead of dispatching an implementer. It saves the dispatch cost (fresh context + file re-reads per subagent) but bloats controller context permanently — so it is criteria-gated, not a mood:

| Tier | Inline allowed? | Review requirement |
|------|-----------------|--------------------|
| additive | yes, if ≤2 files AND the task text is a complete spec | combined reviewer dispatch as usual; for trivial tasks (docs/config/no behavior change) the controller may instead run the combined reviewer checklist inline against the actual diff |
| modifying | only if every touched file was already read this session | spec + quality review dispatches stay MANDATORY — the controller reviewing its own inline work is the weakest check in the chain, so fresh eyes never relax here |
| interface-changing | never | — |

Rules that never relax inline: TDD (failing test first), the Step 4b must-stay-green run, reference-only paths, secure-data handling, and `pressurecooker:verification-before-completion` evidence. Inline changes commit per task exactly like an implementer would.

**Choosing:** honor the task's `Execution:` stamp when the plan carries one (from `pressurecooker:writing-plans`). Without a stamp: economy mode ON (session-start reports it) → inline-first wherever the table allows; economy mode OFF → dispatch by default and go inline only with a one-line declared deviation ("running Task N inline: additive, 1 file, spec complete").

**Token heuristic (both directions):** inline is cheaper for small tasks over files already in context; a subagent is cheaper for anything that would pull many new files into the controller — a broad exploration done inline is paid again on every subsequent turn.

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
| Per-task analyst (when the tier table dispatches one) | investigator default (Sonnet) |
| Implementer — mechanical (1-2 files, complete spec in task) | Haiku 4.5 (`model` override on the dispatch) |
| Implementer — integration/judgment (multi-file, pattern matching, debugging) | Opus 4.8 |
| Spec reviewer / combined reviewer (additive) | Haiku 4.5 (`model` override) |
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
- Dispatch multiple implementer subagents in parallel (conflicts)
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
