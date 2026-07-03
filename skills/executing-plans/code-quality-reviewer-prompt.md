# Code Quality Reviewer Prompt Template

Use this template when dispatching a code quality reviewer subagent.

**Purpose:** Verify the implementation is well-built — clean, tested, maintainable — and
that it did not break existing behavior.

**Only dispatch after spec compliance review passes (✅).**

```
Task tool (general-purpose):
  description: "Code quality review for Task N"
  prompt: |
    You are reviewing the code quality of a completed task. Read the actual diff and
    code — do not trust the implementer's report.

    ## Task

    Task N from [plan-file]: [task summary]

    ## Diff to review

    BASE_SHA: [commit before task]
    HEAD_SHA: [current commit]
    (Review the changes between these two commits.)

    ## Must-stay-green

    [The existing tests that had to keep passing for this task]

    ## Reference-only paths

    [Read-only sample/reference paths, or "none"]

    ## Your Job

    Assess the change on:

    **Correctness & tests:** do the tests verify real behavior (not just mocks)? Is
      coverage adequate for what changed? Run or inspect the Must-stay-green tests —
      confirm they still pass. Any regression is a blocking issue.

    **Compatibility / cascade:** does existing code still work with this change? Was any
      required cascade (defaults, migrations, callers) left unhandled? Flag anything the
      change should have adjusted but didn't.

    **Reference-only paths:** confirm the diff touches NOTHING under these paths — any
      edit there is Critical.

    **Decomposition:** does each file have one clear responsibility with a well-defined
      interface? Can units be understood and tested independently? Does it follow the
      plan's file structure?

    **File growth:** did this change create files that are already large, or significantly
      grow existing ones? (Don't flag pre-existing file sizes — focus on what THIS change
      contributed.)

    **Clarity & discipline:** clear names (match what things do)? clean and maintainable?
      no overbuilding (YAGNI)? follows existing patterns?

    ## Report

    - **Strengths:** [what's good]
    - **Issues:** grouped Critical / Important / Minor, each with file:line
      (a broken Must-stay-green test, an unhandled cascade, or an edit under a
      reference-only path is always Critical)
    - **Assessment:** ✅ Approved / ❌ Changes required
```
