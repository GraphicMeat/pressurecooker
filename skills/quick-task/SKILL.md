---
name: quick-task
description: Use for small, clearly-scoped fixes or changes (roughly 1-2 files, obvious approach) that don't warrant the full brainstorm-plan-execute chain - keeps test-first discipline on small work and escalates when scope grows
---

# Quick Task

## Overview

The full chain (brainstorm → plan → worktree → execute) is overkill for a typo, a label change, a one-function fix. But "small" is where discipline silently dies — no test, straight to main, drive-by edits. This skill is the lightweight gate: small work keeps the floor, and work that isn't actually small gets caught and escalated.

**Announce at start:** "I'm using the quick-task skill."

## When to Use

- Fix or change touching ~1–2 files with an obvious, agreed approach
- No design decisions, no new interfaces, no schema/data changes

**Not for:** anything matching the escalation triggers below — check them BEFORE starting, not after.

## The Floor (never waived)

1. **Split unrelated changes.** A cosmetic fix and a behavior fix requested together are two tasks with two risk profiles — never one commit. "While you're in there" is a second task.
2. **Behavior changes get a failing test first** (`pressurecooker:test-driven-development`). Cosmetic-only changes (copy, styling) may skip the new test but still run the affected suite. If the bug deserves fixing, it deserves the regression test that keeps it fixed.
3. **Check consumers before editing shared code.** One grep: who else calls this? A shared helper's "obvious 2-second fix" changes behavior for every caller — read the call sites first.
4. **Run the affected tests + touched-area suite.** Green before commit. Update snapshots/i18n only with eyes on the diff.
5. **Verify before claiming done** — `pressurecooker:verification-before-completion`: fresh command output, then the claim.
6. **Commit per task**, normal message. Direct-to-main only if the repo's norm allows it AND the change is cosmetic; behavior changes ride a branch/PR per repo convention.

## Escalation Triggers — STOP, Route to the Chain

Any of these means it is not a quick task; say so and switch:

| Trigger | Route |
|---------|-------|
| Bug's root cause unclear, or fix would be a guard/default/try-catch at the crash site | `pressurecooker:systematic-debugging` |
| Change cascades beyond ~2 files, or a shared helper's callers need per-caller handling | `pressurecooker:systematic-debugging` (architecture check) or full chain |
| Touches credentials, tokens, PII, payment/secure data | `pressurecooker:secure-data-handling` (applies on top) |
| Needs a design decision, new interface, or schema/data migration | `pressurecooker:brainstorming` |
| An existing test goes red and the fix isn't in scope | `pressurecooker:systematic-debugging` |
| "Quick fix" is the 2nd+ attempt at the same bug | `pressurecooker:systematic-debugging` — mandatory |

## Common Rationalizations

| Excuse | Reality |
|--------|---------|
| "It's literally two lines, ship straight to main" | Two lines in a shared helper is a behavior change at every call site. Check consumers, test, then ship. |
| "No need for tests on this" | The missing test is how this class of bug got here. Failing test first for any behavior change. |
| "While you're in there, also fix..." | Second task. Split it — separate commit, its own test, possibly its own escalation. |
| "It's 4:50pm, get it out" | Cosmetic part ships now; behavior part ships when its tests are green and someone's around. |

## Integration

- Escalates into: `pressurecooker:systematic-debugging`, `pressurecooker:brainstorming`, `pressurecooker:secure-data-handling`
- Exit gate: `pressurecooker:verification-before-completion`
