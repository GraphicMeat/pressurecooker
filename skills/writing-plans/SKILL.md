---
name: writing-plans
description: Use when you have a spec or requirements for a multi-step task, before touching code
---

# Writing Plans

## Overview

Write comprehensive implementation plans assuming the engineer has zero context for our codebase and questionable taste. Document everything they need to know: which files to touch for each task, code, testing, docs they might need to check, how to test it, and what their change could break. Give them the whole plan as bite-sized tasks. DRY. YAGNI. TDD. KISS. Frequent commits.

Assume they are a skilled developer, but know almost nothing about our toolset or problem domain. Assume they don't know good test design very well.

Announce at start: "I'm using the writing-plans skill to create the implementation plan."

**Write the plan in normal, readable prose — NOT caveman.** The plan is a review-and-execution artifact; clarity matters more than compression. Caveman stays for chat.

Context: If working in an isolated worktree, it should have been created via the `pressurecooker:using-git-worktrees` skill at execution time.

Save plans to: `docs/pressurecooker/plans/YYYY-MM-DD-<feature-name>.md`
(User preferences for plan location override this default)

## Scope Check

If the spec covers multiple independent subsystems, it should have been broken into sub-project specs during brainstorming. If it wasn't, suggest breaking this into separate plans — one per subsystem. Each plan should produce working, testable software on its own.

## Impact Assessment (Blast Radius)

Before mapping files, assess what this change touches beyond the new code. This is the "does it break anything else?" pass, and it feeds the decomposition below.

- **Project memory first:** read `docs/pressurecooker/memory/MEMORY.md` if present. `retro` memories record past misses (cascade gaps, regressions, review catches) — each relevant one becomes a checklist item this plan must not repeat. `map` memories feed the consumer graph below. Memories are hints — verify against current code; missing memory = proceed as today.
- **Consumers:** Who calls / imports / depends on the code being changed? List the call sites, public interfaces, and contracts (APIs, events, schemas) that other code relies on.
- **Existing test coverage:** Which existing tests exercise the affected paths? These become the "must-stay-green" set for the tasks that touch them.
- **Data & compatibility:** Any schema, config, migration, serialization, or backward-compatibility concerns? Note version floors and anything a downstream consumer would notice.
- **Make-sense / fit check:** Does this change fit the existing patterns and how the surrounding feature already behaves (per industry norms where they apply)? If the change forces the codebase into an unnatural shape, that's a signal the boundary is wrong — consider extracting the feature into its own module (TDD + KISS) rather than forcing it in. Reflect that decision in the File Structure.
- **Reference-only paths:** If the spec lists reference-only paths (sample folders marked by triage), exclude them from this analysis — sample code is not a consumer and its tests are never must-stay-green targets. Carry the paths into Global Constraints instead so every task inherits the "never modify" rule.
- **Secure data:** Does the change touch credentials, tokens, PII, payment or other secure data? Copy the spec's `Secure-data fields:` line into Global Constraints (names only, never values); every task touching those fields carries `pressurecooker:secure-data-handling` rules in its text — no secrets in code, logs, fixtures, or artifacts.

Summarize the blast radius in a few lines. Every task that touches an at-risk area must carry the relevant items forward in its own `Impact:` block.

## File Structure

Before defining tasks, map out which files will be created or modified and what each one is responsible for. This is where decomposition decisions get locked in.

Design units with clear boundaries and well-defined interfaces. Each file should have one clear responsibility.

You reason best about code you can hold in context at once, and your edits are more reliable when files are focused. Prefer smaller, focused files over large ones that do too much.

Files that change together should live together. Split by responsibility, not by technical layer.

In existing codebases, follow established patterns. If the codebase uses large files, don't unilaterally restructure - but if a file you're modifying has grown unwieldy, including a split in the plan is reasonable.

This structure informs the task decomposition. Each task should produce self-contained changes that make sense independently.

## Refactoring Plans

When the plan's goal is refactoring (extraction, consolidation, restructuring) — including plans arriving from `pressurecooker:systematic-debugging` Phase 5 or from `pressurecooker:analyzing-codebase` Top 5 issues — these rules override the generic task shape:

- **Plan before any work.** No exploratory refactoring; module order and test gates are decided here, not discovered mid-flight.
- **Task 1 is ALWAYS characterization tests.** Pin the CURRENT behavior of every affected module before anything moves: golden-master tests over representative inputs and edge cases; a **drift matrix** when duplicated copies disagree (which copy does what, per input class); at least one test exercising the real production call order when shared mutable state is involved. Suite green before any refactor task starts. "Pure refactor, behavior identical by definition" is not an exemption — that claim is exactly what characterization tests verify.
  - **Depth scales with risk, floor doesn't move.** Pure code movement (files/renames, no logic edits) may scale Task 1 down to: full-suite before/after fingerprint (identical passes AND failures AND skips), targeted tests for every compiler-blind spot (dynamic imports, string-built paths, serialized class references, reflection), plus real characterization tests for any high-stakes logic being moved (money math, state transitions) regardless of movement purity. "The existing suite is ancient/half-skipped, don't test old code" concedes the safety net is missing — that raises the requirement, never lowers it.
  - **Decision gate:** drifted copies disagree → canonical behavior must be decided, in the plan. Product-visible divergence (two surfaces showing users different numbers) → escalate to the human before tasks are written.
- **One module per task.** Order by blast radius: lowest-risk consumer first (proves the migration pattern), highest-stakes/thinnest-tested module LAST, with the pattern proven and its characterization tests already in place. Never "move it all in one go."
- **Every task ends with the full gate:** refactor step → run characterization + must-stay-green suites → fix until green → commit. Never start the next module on red. Red characterization test = the refactor changed behavior — **fix the refactor, never the test.** A deliberate expectation change must reference the drift-matrix decision; no silent test edits.
- **No blended behavior changes.** Bug fixes and improvements ("since you're in there anyway") are their own task at the END — after all migration tasks, isolated in one commit whose test diff IS the report of what changed — or a separate plan. Never inside a migration task: with mixed changes every diff becomes ambiguous (refactor error or intended fix?).
- **Cut line under deadline pressure:** scope — later modules slip to a follow-up plan; the trailing behavior-change task slips easily (post-consolidation it's a one-file change). NEVER cut Task 1, never cut per-task test gates.

## Task Right-Sizing

A task is the smallest unit that carries its own test cycle and is worth a fresh reviewer's gate. When drawing task boundaries: fold setup, configuration, scaffolding, and documentation steps into the task whose deliverable needs them; split only where a reviewer could meaningfully reject one task while approving its neighbor. Each task ends with an independently testable deliverable.

## Bite-Sized Task Granularity

Each step is one action (2-5 minutes):
- "Write the failing test" - step
- "Run it to make sure it fails" - step
- "Implement the minimal code to make the test pass" - step
- "Run the tests and make sure they pass" - step
- "Run the affected existing tests to confirm no regressions" - step
- "Commit" - step

## Plan Document Header

Every plan MUST start with this header:

```
# [Feature Name] Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use pressurecooker:executing-plans to implement this plan task-by-task. All development is subagent-driven. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** [One sentence describing what this builds]
**Architecture:** [2-3 sentences about approach]
**Tech Stack:** [Key technologies/libraries]

## Global Constraints
[The spec's project-wide requirements — version floors, dependency limits,
naming and copy rules, platform requirements — one line each, with exact
values copied verbatim from the spec. Include the spec's `Reference-only
paths:` line verbatim if present — those paths are read for patterns, never
modified. Every task's requirements implicitly include this section.]

## Blast Radius
[The Impact Assessment summary — consumers, must-stay-green tests, and
compatibility concerns that span the whole change. Per-task Impact blocks
draw from this.]

---
```

## Task Structure

```
### Task N: [Component Name]

**Files:**
- Create: `exact/path/to/file.py`
- Modify: `exact/path/to/existing.py:123-145`
- Test: `tests/exact/path/to/test.py`

**Interfaces:**
- Consumes: [what this task uses from earlier tasks — exact signatures]
- Produces: [what later tasks rely on — exact function names, parameter
  and return types. A task's implementer sees only their own task; this
  block is how they learn the names and types neighboring tasks use.]

**Impact:**
- Breaks-risk: [existing behavior this task could break — empty only if the
  task is purely additive with no consumers]
- Must-stay-green: [exact existing tests/files that must still pass after
  this task, drawn from the Blast Radius]
- Risk: [additive | modifying | interface-changing — derived mechanically:
  additive = Breaks-risk empty, only new code with no existing consumers;
  modifying = touches existing code/behavior but no public interface or
  contract changes; interface-changing = changes a public interface, schema,
  serialized format, or any contract with consumers outside this task's
  files. In doubt between tiers → pick the higher one.]
- Execution: [inline | subagent — derived mechanically from Risk: additive
  AND ≤2 files AND the task text is a complete spec → inline; everything
  else → subagent. Executing-plans honors this stamp; its Inline Execution
  rules still apply (reviews per tier, must-stay-green never relaxes).
  In doubt → subagent.]
```

Then the TDD step cycle:

```
- [ ] **Step 1: Write the failing test**
```python
def test_specific_behavior():
    result = function(input)
    assert result == expected
```

- [ ] **Step 2: Run test to verify it fails**
Run: `pytest tests/path/test.py::test_name -v`
Expected: FAIL with "function not defined"

- [ ] **Step 3: Write minimal implementation**
```python
def function(input):
    return expected
```

- [ ] **Step 4: Run test to verify it passes**
Run: `pytest tests/path/test.py::test_name -v`
Expected: PASS

- [ ] **Step 4b: Run affected existing tests (regression check)**
Run: `<suite covering the touched area — from Must-stay-green>`
Expected: PASS — no regressions. If red, fix before committing.

- [ ] **Step 5: Commit**
```bash
git add tests/path/test.py src/path/file.py
git commit -m "feat: add specific feature"
```
```

Regression-check guard (KISS): run the tests covering the *affected* area plus any relevant integration tests — not the entire world on every task. Scale the suite to the blast radius.

## No Placeholders

Every step must contain the actual content an engineer needs. These are plan failures — never write them:
- "TBD", "TODO", "implement later", "fill in details"
- "Add appropriate error handling" / "add validation" / "handle edge cases"
- "Write tests for the above" (without actual test code)
- "Similar to Task N" (repeat the code — the engineer may be reading tasks out of order)
- Steps that describe what to do without showing how (code blocks required for code steps)
- References to types, functions, or methods not defined in any task

## Remember

- Exact file paths always
- Complete code in every step — if a step changes code, show the code
- Exact commands with expected output
- Every task carries its Impact block — breaks-risk and must-stay-green
- DRY, YAGNI, TDD, KISS, frequent commits

## Self-Review

After writing the complete plan, look at the spec with fresh eyes and check the plan against it. This is a checklist you run yourself — not a subagent dispatch.

1. **Spec coverage:** Skim each section/requirement in the spec. Can you point to a task that implements it? List any gaps.
2. **Placeholder scan:** Search your plan for red flags — any of the patterns from the "No Placeholders" section above. Fix them.
3. **Type consistency:** Do the types, method signatures, and property names you used in later tasks match what you defined in earlier tasks? A function called `clearLayers()` in Task 3 but `clearFullLayers()` in Task 7 is a bug.
4. **Regression coverage:** Does every task that touches existing code name the existing tests that must stay green (Must-stay-green), and does its cycle include the Step 4b regression check?
5. **Fit check:** Is each change consistent with existing patterns and how the surrounding feature already behaves (industry norms where they apply)? A change that technically works but breaks the feature's expected behavior is a defect.
6. **Memory & risk check:** Did you consult `retro` memories, and does any task repeat a recorded past miss? Does every task's Impact block carry a `Risk:` tier and an `Execution:` stamp?

If you find issues, fix them inline. No need to re-review — just fix and move on. If you find a spec requirement with no task, add the task.

## Execution Handoff

After saving the plan, hand off to execution. There is one execution path — subagent-driven by default, with per-task `Execution: inline` stamps honored under the executing-plans Inline Execution rules.

> "Plan complete and saved to `docs/pressurecooker/plans/<filename>.md`. I'll execute it with executing-plans: pre-flight blast-radius analysis, then a fresh subagent per task with per-task compatibility checks and two-stage review."

- REQUIRED SUB-SKILL: Use `pressurecooker:executing-plans`
- It runs pre-flight blast radius (which also emits per-task compat notes), then dispatches implementer + reviewer subagents per task — honoring `Execution: inline` stamps, batching eligible additive tasks, and overlapping/parallelizing disjoint tasks under its Concurrency gate.
