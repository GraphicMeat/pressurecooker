# Evidence-Gatherer Subagent Prompt Template

Use this template to dispatch a read-only investigator when debugging from a controller
context (e.g. during `pressurecooker:executing-plans`, where the controller never edits).
It performs Phase 1–2 of systematic-debugging and reports; it does NOT edit code or
propose patches.

```
Task tool (general-purpose):
  description: "Investigate root cause: [one-line symptom]"
  prompt: |
    You are investigating a bug. You read, run diagnostics, and reason only —
    do NOT edit any file, and do NOT propose a fix. Your deliverable is evidence.

    ## Symptom

    [Exact error message / failing test name + output / observed vs expected behavior.
    Paste verbatim — do not paraphrase error text.]

    ## Context

    [Where it appeared: which task, which must-stay-green test, when it started.
    Recent changes if known: commits, new dependencies, config edits.]

    ## Reference-only paths

    [Paths that are read-only samples, or "none". Evidence found inside them is valid;
    they are never fix targets and never the "recent change" that caused this.]

    ## Your job

    1. **Read the error completely** — full stack trace, line numbers, error codes.
    2. **Reproduce** — find the exact minimal trigger. If you cannot reproduce, report
       that with what you tried; do not speculate.
    3. **Check recent changes** — git log/diff around the affected paths.
    4. **Trace the data flow backward** — where does the bad value/state originate?
       Follow the call chain UP from the crash site to the original trigger.
       Fix location = source, not symptom site.
    5. **Compare against working examples** — similar code in this codebase that works;
       list the differences, however small.
    6. **Architecture check** — flag each of these that holds:
       - root cause spans 3+ files with no clear owner of the broken state
       - no single module is answerable for the behavior
       - same logic duplicated in multiple drifted copies (enumerate ALL copies)
       - a correct fix would need the same edit at N call sites
       - shared mutable state read/written from multiple places (enumerate all)

    ## Redaction rule

    Never include secret values (keys, tokens, credentials, PII, payment data) in your
    report — not from logs, error messages, configs, or code you read. Reference by name
    and fingerprint (sha256 prefix) only. A hardcoded secret you find IS evidence: report
    file:line and kind, never the value.

    ## Report

    - **Root-cause hypothesis:** one sentence — "X because Y" (or "not yet determined" + what's missing)
    - **Evidence chain:** symptom → immediate cause → ... → original trigger, each step file:line
    - **Reproduction:** exact minimal steps/command
    - **Recent-change correlation:** commit/change implicated, or "none found"
    - **Working-example diff:** what differs from the working pattern
    - **Architecture flags:** none / [list with file:line] — any flag means the controller
      should consider Phase 5 (refactor by extraction) instead of a point fix
    - **Suggested minimal experiment:** the smallest test/instrumentation that would
      confirm or kill the hypothesis (for the controller to run via an implementer)
    - **Confidence:** high / medium / low

    Report style: caveman-compressed — drop articles, filler, hedging; fragments fine.
    Technical terms, file:line refs, numbers, and quoted errors stay EXACT (never
    paraphrase error text). NO code echoes — evidence is file:line + the exact error,
    not pasted source.
```
