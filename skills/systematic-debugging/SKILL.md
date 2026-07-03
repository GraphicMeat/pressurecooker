---
name: systematic-debugging
description: Use when encountering any bug, test failure, regression, or unexpected behavior, before proposing fixes - especially when a must-stay-green test goes red, a quick patch or guard looks tempting, previous fixes didn't stick, or the same class of bug keeps recurring
---

# Systematic Debugging

## Overview

Random fixes waste time and create new bugs. Quick patches mask underlying issues.

**Core principle:** ALWAYS find the root cause before attempting fixes. Symptom fixes are failure — the bug stays open until the cause is gone.

**Violating the letter of this process is violating the spirit of debugging.**

**Announce at start:** "I'm using the systematic-debugging skill to find the root cause."

## The Iron Law

```
NO FIXES WITHOUT ROOT CAUSE INVESTIGATION FIRST
```

If you haven't completed Phase 1, you cannot propose fixes. And a fix that only absorbs the symptom does not count as a fix (see the Root-Cause-Fix Gate).

## When to Use

Any technical issue: test failures, production bugs, unexpected behavior, performance problems, build failures, integration issues, a must-stay-green test going red during plan execution.

**Use ESPECIALLY when:**
- Under time pressure (emergencies make guessing tempting)
- "Just one quick fix" seems obvious
- You've already tried multiple fixes / previous fix didn't work
- The same class of bug keeps coming back

**Don't skip when** the issue seems simple, you're in a hurry, or someone wants it fixed NOW. Systematic is faster than thrashing.

## The Five Phases

Complete each phase before the next.

### Phase 1: Root Cause Investigation

**BEFORE attempting ANY fix:**

1. **Read error messages carefully** — stack traces completely, line numbers, error codes. They often contain the solution.
2. **Reproduce consistently** — exact steps, reliable trigger. Not reproducible → gather more data, don't guess.
3. **Check recent changes** — git diff, recent commits, new dependencies, config changes, environmental differences.
4. **Gather evidence at component boundaries** — in multi-component systems (CI → build → sign, API → service → DB), log what enters and exits each layer, verify env/config propagation, run once, and let the evidence show WHERE it breaks before analyzing WHY.
5. **Trace data flow to the source** — where does the bad value originate? Keep tracing up the call chain. See `root-cause-tracing.md`. Fix belongs at the source, not where the error surfaced.

**Context rules:**
- **Reference-only paths are evidence, never fix targets.** If the bug only reproduces inside a sample/reference folder (Global Constraints), observe it there but never edit it.
- **Inside executing-plans:** the controller never debugs by editing. Dispatch a read-only investigator subagent (`./evidence-gatherer-prompt.md`) to do Phase 1–2 and report; fixes go through an implementer subagent as usual.

**Architecture-Confusion Check (run before leaving Phase 1):**

Flag architecture as a suspect if ANY of these hold:

- Root cause spans 3+ files with no clear owner of the broken state
- You cannot answer "which module is responsible for this behavior?" in one sentence
- The same logic exists in multiple hand-rolled copies (and they've drifted)
- A correct fix would require the same edit at N call sites
- Shared mutable state is read/written from multiple places

Any flag raised, and investigation confirms it's a big part of the issue → go directly to **Phase 5 (Refactor by Extraction)**. Do not grind fix attempts against a structure that manufactures this bug class. The 3-failed-fixes rule (Phase 4) remains as a backstop for architecture problems you didn't spot early.

### Phase 2: Pattern Analysis

1. **Find working examples** — similar code in the same codebase that works.
2. **Compare against references** — read reference implementations COMPLETELY, not skimming.
3. **Identify differences** — list every difference between working and broken, however small.
4. **Understand dependencies** — settings, config, environment, assumptions.

### Phase 3: Hypothesis and Testing

1. **Form single hypothesis** — "I think X is the root cause because Y." Write it down.
2. **Test minimally** — smallest possible change to test the hypothesis, one variable at a time.
3. **Verify before continuing** — confirmed → Gate, then Phase 4. Not confirmed → new hypothesis. Don't stack fixes.
4. **When you don't know, say so** — "I don't understand X" beats pretending. Research or ask.

### The Root-Cause-Fix Gate

Before implementing, the proposed fix must pass all three checks:

1. **Deletion test:** Does this fix REMOVE the cause, or CATCH/ABSORB the symptom? "The crash stops" is not "the cause is gone."
2. **Recurrence test:** If another caller, record, or code path hits the same conditions tomorrow, does the bug reappear? Yes → it's a workaround, rejected.
3. **Smell scan:** These patterns are automatic workaround flags:

| Smell | What it usually hides |
|-------|----------------------|
| New try/catch around the failure site | The error still happens; now it's silent |
| Optional chaining / null guard added at crash site | Invalid data still being produced upstream |
| Special-case `if` for the failing input | The general case is broken |
| Default value (`?? 'Unknown'`, `|| 0`) | Missing/corrupt data rendered as if valid |
| Retry loop / timeout increase | Race or dependency failure unaddressed |
| Test skipped, assertion loosened, tolerance widened | The regression is now invisible |
| Reordering operations "so it works" | Hidden coupling between steps |

A smell is only acceptable WITH a written justification of why it is the actual root-cause fix (e.g. the contract genuinely says the field is optional), plus defense-in-depth validation upstream (see `defense-in-depth.md`).

**Emergency stopgap protocol.** Production is down, demo in 30 minutes, a guard stops the bleeding — reality happens. A stopgap is permitted ONLY under all of:
1. Failing repro test written FIRST (it stays red under the stopgap for the root cause, or is added at the root-cause level)
2. The stopgap is explicitly labeled a stopgap in code comment and commit message
3. Root-cause fix continues IMMEDIATELY after the emergency — same session, same branch. The bug stays OPEN until then.

"I'll fix the real cause after the demo" without a failing test and an open task is how symptom patches become load-bearing forever.

### Phase 4: Implementation

1. **Create failing test case first** — simplest reproduction of the ROOT CAUSE (not just the symptom), automated. TDD discipline: watch it fail before fixing.
2. **Check the fix's blast radius** — who consumes the code you're about to change? Which existing tests are the must-stay-green set for this fix? In executing-plans context, dispatch the per-task mode of `../executing-plans/blast-radius-prompt.md`; standalone, answer the same questions yourself before editing.
3. **Implement single fix** — the root cause identified. ONE change. No "while I'm here" improvements.
4. **Verify** — new test green AND must-stay-green set green (Step 4b regression check). A passing new test with a broken existing test is a regression, not progress.
5. **If the fix doesn't work: STOP and count.**
   - Fewer than 3 attempts → return to Phase 1 with the new information.
   - **3+ failed fixes → this is not a hypothesis problem, it's an architecture problem. Go to Phase 5.** Don't attempt fix #4.

### Phase 5: Refactor by Extraction

Entered from the Phase 1 architecture check or after 3+ failed fixes. The structure is manufacturing the bug; isolate the feature into a module you can reason about — **tests first, then refactor, then verify, then fix.**

**Order is mandatory:**

1. **Write the failing repro test for the bug.** Keep it separate; it STAYS RED until step 7. It's the proof the refactor was worth it.
2. **Enumerate the full extent first.** Find ALL copies of the duplicated logic and ALL readers/writers of the shared state — not just the ones that broke. The copy nobody mentioned is the next bug.
3. **Write passing characterization tests** pinning CURRENT behavior at the feature boundary: every consumer's observable output for representative inputs, including edge cases. If shared mutable state is involved, include at least one test exercising the REAL production call order — state bugs hide between correctly-passing isolated tests. Suite must be green before any refactoring.
4. **Record the baseline** test count (same mechanism as the worktree clean baseline).
5. **Extract the feature into its own module** — one responsibility, explicit interface, pure functions where possible (inputs → outputs, no module-level mutable state). KISS: the smallest extraction that isolates the broken behavior — not a big-bang rewrite. New seams get TDD. Migrate call sites to the module and delete the duplicated copies; shared mutable state gets deleted or reduced to read-only config as part of the extraction — that's the point.
6. **Verify nothing broke:** characterization tests + must-stay-green all green. Red here means the extraction changed behavior — fix the extraction, never the tests.
7. **Now fix the bug** inside the clean module: repro test red → minimal fix → green → full Step 4b regression check.

**Size gate:** extraction confined to ~2–3 files → do it inline, in order, now. Bigger (many call sites, migrations, cross-layer state) → STOP and route to `pressurecooker:writing-plans` for a refactor plan (characterization tests are Task 1), executed via `pressurecooker:executing-plans`. Either way the refactor IS the fix — "consolidate next sprint" while shipping another patch means the bug class stays open and you WILL be back in this skill. If the human explicitly chooses to defer, the deferral must carry the failing repro test and a written task; the bug is documented as open, not fixed.

## Red Flags — STOP and Return to Process

- "Quick fix for now, investigate later" / "Just try X and see"
- "It's probably X, let me fix that" — proposing solutions before tracing data flow
- Adding a guard/default/try-catch at the crash site without a written root-cause justification
- "The root cause can't hurt right now — the damage is already done" (fix it same session or it never happens)
- "Skip the test, I'll manually verify" / writing the repro test after the fix
- Multiple changes at once; fix #4 after 3 failures
- "Refactor next sprint" while shipping another symptom patch
- Editing files under reference-only paths to make a bug go away
- Each fix reveals a new problem in a different place (architecture signal — Phase 5)

## Common Rationalizations

| Excuse | Reality |
|--------|---------|
| "Issue is simple, don't need process" | Simple issues have root causes too. Process is fast on simple bugs. |
| "Emergency, no time for process" | Stopgap protocol exists for this — and it requires the repro test and an open bug. |
| "The guard is the only change whose blast radius I can reason about right now" | Phase 4 step 2 computes the root-cause fix's blast radius. Reason, don't guess. |
| "Cheap insurance, no downside" (fallback default) | A default that renders missing data as valid is data corruption with better UX. |
| "Root cause can't crash us now, damage is already in the DB" | Then it corrupts the next batch too. Same session or it never happens. |
| "Consolidation is ~1 day, we'll do it next sprint" | Deferred refactors don't happen. The refactor IS the fix (or the deferral is documented as an open bug). |
| "I'll write the test after confirming the fix works" | Untested fixes don't stick. Test first proves it. |
| "Multiple fixes at once saves time" | Can't isolate what worked. Causes new bugs. |
| "I see the problem, let me fix it" | Seeing the symptom ≠ understanding the cause. |
| "One more fix attempt" (after 3+) | That's an architecture problem. Phase 5. |

## Signals You're Doing It Wrong (user pushback)

- "Is that not happening?" — you assumed without verifying
- "Stop guessing" — you're proposing fixes without understanding
- "Didn't we fix this already?" — previous fix was a symptom patch
- "Why does this keep breaking?" — architecture signal; run the Phase 1 check
- Frustration at repeated attempts — STOP, return to Phase 1

## When Investigation Finds No Root Cause

Truly environmental / timing-dependent / external after full process: document what you investigated, implement appropriate handling (retry with backoff, timeout, clear error), add monitoring for the next occurrence. But 95% of "no root cause" is incomplete investigation.

## Supporting Techniques (this directory)

- `root-cause-tracing.md` — trace bugs backward through the call stack to the original trigger
- `defense-in-depth.md` — validate at every layer after finding the root cause, so the bug becomes structurally impossible
- `condition-based-waiting.md` (+ example.ts) — replace arbitrary timeouts with condition polling
- `find-polluter.sh` — bisect which test pollutes shared state
- `evidence-gatherer-prompt.md` — read-only investigator subagent (Phase 1–2) for controller contexts

## Integration

- **pressurecooker:executing-plans** — a must-stay-green test going red during execution routes HERE; investigation via evidence-gatherer subagent, fixes via implementer subagent; fix blast radius reuses `blast-radius-prompt.md` per-task mode
- **pressurecooker:using-git-worktrees** — the clean baseline is the regression reference for Step 4b and Phase 5
- **pressurecooker:writing-plans** → **executing-plans** — large Phase 5 extractions become a refactor plan
- **pressurecooker:finishing-a-development-branch** — failing full suite at the branch gate routes here, not to test-loosening
