# Combined Reviewer Prompt Template (additive-tier tasks)

Use this template for tasks whose `Risk:` tier is **additive** — it merges the spec
compliance and code quality reviews into one dispatch. A ❌ on either dimension loops
the implementer exactly as the two-stage flow does. Modifying and interface-changing
tasks use the separate spec + quality reviewers instead.

```
Task tool (general-purpose):
  description: "Combined review for Task N: [task name]"
  prompt: |
    You are reviewing a completed ADDITIVE task — it should only add new code, with
    no existing consumers affected. You review; you do not edit.

    ## The task (spec)

    [FULL TEXT of Task N from the plan]

    ## What the implementer reports

    [Implementer's report: files changed, tests run, results]

    ## Must-stay-green

    [The existing tests that must still pass, from the task's Impact block]

    ## Reference-only paths / Secure-data fields

    [From Global Constraints, or "none" each.]

    ## Review dimensions

    **1. Spec compliance:** compare the actual diff (git diff / git log) against the
    task text line by line. Everything specified implemented? Anything implemented
    that was NOT specified? New tests match the task's test steps, and did the
    red-green cycle happen (failing test first)?

    **2. Additive check:** confirm the diff is actually additive — no existing file's
    behavior modified beyond wiring the new code in. If existing behavior changed,
    the task was mis-tiered: report ❌ with TIER-MISMATCH so the controller re-runs
    it through the modifying/interface-changing flow.

    **3. Quality:** each new file one clear responsibility with a well-defined
    interface? Clear names? No overbuilding (YAGNI)? Follows existing patterns?
    Tests verify real behavior, not mocks of it?

    **4. Must-stay-green:** run or inspect the named tests — confirm still green.
    Any regression is Critical.

    **5. Constraints:** diff touches NOTHING under reference-only paths (Critical);
    no secret value surfaced in code, tests, fixtures, logs, or comments (Critical —
    rotation needed, not just removal).

    ## Report

    - **Spec compliance:** ✅ / ❌ [+ specifics, file:line]
    - **Quality:** ✅ / ❌ [+ issues grouped Critical / Important / Minor]
    - **Must-stay-green:** green / RED [+ which]
    - **Tier check:** additive confirmed / TIER-MISMATCH [+ what modified existing behavior]
    - **Verdict:** APPROVED (all ✅) / CHANGES REQUIRED [the implementer fixes, you re-review]

    Report style: caveman-compressed — drop articles, filler, hedging, pleasantries;
    fragments fine. Technical terms, file:line refs, numbers, and quoted errors stay
    EXACT. Code blocks normal.
```
