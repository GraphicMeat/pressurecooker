---
name: executing-plans
description: Use when you have a written implementation plan to execute - always subagent-driven, with pre-flight and per-task blast-radius analysis
---

# Executing Plans

## Overview

Execute an implementation plan. **All development is subagent-driven, always.** The controller (you) never edits code directly — it loads the plan, analyzes blast radius, dispatches fresh subagents per task, reviews between them, and reports when complete.

**Announce at start:** "I'm using the executing-plans skill to implement this plan (subagent-driven)."

**Core principles:**
- **Controller coordinates, subagents implement.** Never write implementation code yourself — dispatch a subagent. This keeps your context clean for coordination and gives each task isolated, precisely-scoped context.
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

Give it: the plan's `Blast Radius` + `Global Constraints`, the list of fields/interfaces/contracts the plan adds or changes, and access to the current codebase.

It answers, for the change as a whole:
- **Forward compatibility:** for each added/changed field or interface, does existing code keep working with it as-is?
- **Cascade:** does a change force *other* fields, records, call sites, or migrations to change too — ones the plan did NOT list?
- **Coverage:** are there existing tests exercising affected paths that the plan's must-stay-green set missed?

Output: a confirmed/expanded must-stay-green set, and a list of **cascade gaps** (required changes not in the plan).

**Gate:** If pre-flight finds cascade gaps the plan doesn't cover, **STOP**. Report them to the human and suggest updating the plan (back to `pressurecooker:writing-plans`). Do NOT silently implement beyond the plan's scope.

## Step 2: Per-Task Loop

For each task, in order. Every box below is a fresh subagent — you only coordinate.

**a. Per-task compatibility check.** Dispatch the blast-radius analyst (`./blast-radius-prompt.md`, per-task mode) scoped to THIS task's added/changed fields only. Lighter than pre-flight: does this task's change work with existing consumers, and does it cascade to fields the task doesn't touch? Hand its findings to the implementer. If it surfaces a cascade beyond the task's scope, decide: widen the task's context, or stop and escalate.

**b. Implementer.** Dispatch the implementer subagent (`./implementer-prompt.md`) with the task's full text, scene-setting context, the compat findings from (a), the Must-stay-green set, and any reference-only paths from Global Constraints. It does TDD, runs the Step 4b regression check, commits, self-reviews, reports status.

**c. Spec compliance review.** Dispatch the spec reviewer (`./spec-reviewer-prompt.md`). If ❌, the implementer subagent fixes and the reviewer re-reviews. Loop until ✅.

**d. Code quality review.** Only after spec is ✅. Dispatch the code quality reviewer (`./code-quality-reviewer-prompt.md`) — it also confirms the Must-stay-green set is still green and no cascade was left unhandled. If issues, implementer fixes, reviewer re-reviews. Loop until approved.

**e. Mark the task complete in TodoWrite.**

## Step 3: Complete Development

After all tasks pass both reviews:
- Dispatch a final code reviewer subagent over the entire implementation, including a full regression run against the recorded baseline.
- Announce: "I'm using the finishing-a-development-branch skill to complete this work."
- **REQUIRED SUB-SKILL:** Use `pressurecooker:finishing-a-development-branch`.

## Model Selection

Use the least powerful model that can handle each role.
- **Blast-radius analysis & reviews:** standard-to-capable model — these need judgment and broad reading.
- **Mechanical implementation** (1-2 files, complete spec): fast, cheap model.
- **Integration/judgment implementation** (multi-file, pattern matching, debugging): standard model.
- **Architecture/design tasks:** most capable model.

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
- Implement in the controller — all development is subagent-driven, always
- Start implementation on main/master without explicit user consent
- Skip the pre-flight blast radius or a per-task compat check
- Proceed past a cascade gap without updating the plan
- Skip either review (spec compliance OR code quality), or run quality before spec is ✅
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
```
