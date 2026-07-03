---
name: verification-before-completion
description: Use when about to claim work is complete, fixed, or passing, before committing or creating PRs - requires running verification commands and confirming output before making any success claims; evidence before assertions always
---

# Verification Before Completion

## Overview

Claiming work is complete without verification is dishonesty, not efficiency.

**Core principle:** Evidence before claims, always.

**Violating the letter of this rule is violating the spirit of this rule.**

## The Iron Law

```
NO COMPLETION CLAIMS WITHOUT FRESH VERIFICATION EVIDENCE
```

If you haven't run the verification command in this message, you cannot claim it passes.

## The Gate Function

```
BEFORE claiming any status or expressing satisfaction:

1. IDENTIFY: What command proves this claim?
2. RUN: Execute the FULL command (fresh, complete)
3. READ: Full output, check exit code, count failures
4. VERIFY: Does output confirm the claim?
   - If NO: State actual status with evidence
   - If YES: State claim WITH evidence
5. ONLY THEN: Make the claim

Skip any step = lying, not verifying
```

## Common Failures

| Claim | Requires | Not Sufficient |
|-------|----------|----------------|
| Tests pass | Test command output: 0 failures | Previous run, "should pass" |
| Linter clean | Linter output: 0 errors | Partial check, extrapolation |
| Build succeeds | Build command: exit 0 | Linter passing, logs look good |
| Bug fixed | Test original symptom: passes | Code changed, assumed fixed |
| Regression test works | Red-green cycle verified | Test passes once |
| Subagent completed | VCS diff shows the changes | Subagent reports "DONE" |
| Requirements met | Line-by-line checklist vs. spec/task | Tests passing |
| Must-stay-green intact | The named suite run fresh, green | New tests passing |

## Controller Context (executing-plans)

The controller never edits, so its verification is **independent checking of subagent claims**:
- Implementer reports DONE → check the actual `git diff`/`git log` for the claimed changes and the claimed test run
- Reviewer reports ✅ → confirm the must-stay-green suite result is stated with output, not implied
- Final task → the full regression run against the recorded baseline is the completion evidence

## Red Flags — STOP

- Using "should", "probably", "seems to"
- Expressing satisfaction before verification ("Great!", "Perfect!", "Done!")
- About to commit/push/PR without verification
- Trusting subagent success reports without checking the diff
- Relying on partial verification
- Thinking "just this once"
- Tired and wanting work over
- **ANY wording implying success without having run verification**

## Rationalization Prevention

| Excuse | Reality |
|--------|---------|
| "Should work now" | RUN the verification |
| "I'm confident" | Confidence ≠ evidence |
| "Just this once" | No exceptions |
| "Linter passed" | Linter ≠ compiler ≠ tests |
| "Subagent said success" | Verify independently — check the diff |
| "I'm tired" | Exhaustion ≠ excuse |
| "Partial check is enough" | Partial proves nothing |
| "Different words so rule doesn't apply" | Spirit over letter |

## Key Patterns

**Tests:** run the command, see `34/34 pass`, THEN say "all tests pass" — never "should pass now".

**Regression tests (red-green):** write → run (pass) → revert fix → run (MUST FAIL) → restore → run (pass). "I've written a regression test" without the red proves nothing.

**Requirements:** re-read the plan/task → checklist each requirement → verify each → report gaps or completion.

**Silent-dev interplay:** verification is silent — run the commands without narration; the CLAIM carries the evidence in one line ("34/34 pass, must-stay-green green"). Silence never skips the run.

## Integration

- Exit gate for: `pressurecooker:quick-task`, every implementer/reviewer loop in `pressurecooker:executing-plans`, Step 1 of `pressurecooker:finishing-a-development-branch`
- Complements `pressurecooker:systematic-debugging` Phase 4 verify and Step 4b regression checks
