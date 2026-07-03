# Blast-Radius Analyst Prompt Template

Use this template to dispatch a blast-radius / forward-compatibility analyst subagent.
It has two modes — **preflight** (once, whole change) and **per-task** (scoped to one task).
This subagent reads and reasons only. It does NOT edit code.

## Preflight mode (Step 1 — run once before any task)

```
Task tool (general-purpose):
  description: "Pre-flight blast radius for [feature]"
  prompt: |
    You are analyzing the blast radius of a planned change BEFORE any code is written.
    You read and reason only — do not edit anything.

    ## Planned change surface

    [Paste the plan's Blast Radius section + Global Constraints]

    ## Fields / interfaces / contracts this change adds or modifies

    [List each one — e.g. "adds field `status` to Order", "changes `parse()` return type"]

    ## Reference-only paths (exclude from analysis)

    [Paste the Global Constraints' reference-only paths, or "none". These are
    sample/reference folders: their code is not a consumer, their tests are not
    must-stay-green candidates, and nothing may modify them.]

    ## Your job

    Working from the CURRENT codebase, determine for the change as a whole:

    1. **Forward compatibility** — For each added or changed field/interface/contract:
       does existing code keep working with it as-is? Read the actual consumers.
       - New field: do readers/serializers/validators/DB schema handle its presence?
         Is a default or migration required for existing records?
       - Changed field/type/signature: does every existing call site still hold? List
         the ones that would break.

    2. **Cascade** — Does a change force OTHER fields, records, call sites, configs, or
       migrations to change too? Specifically: if one field is added or changed, does
       what we had before now need MORE fields adjusted to stay consistent? List every
       cascade the plan did NOT already account for.

    3. **Coverage** — Find existing tests that exercise the affected paths. Report any
       the plan's must-stay-green set missed. These get added to must-stay-green.

    ## Report

    - **Forward-compat verdict:** per field — OK as-is / needs default+migration / breaks callers (list file:line)
    - **Cascade gaps:** required changes NOT in the plan (file:line + what must change), or "none"
    - **Expanded must-stay-green:** existing tests the plan missed, or "plan set is complete"
    - **Recommendation:** SAFE TO PROCEED / PLAN NEEDS UPDATE (with specifics)
```

## Per-task mode (Step 2a — before each implementer)

```
Task tool (general-purpose):
  description: "Per-task compat check for Task N"
  prompt: |
    You are checking the compatibility impact of ONE task before it is implemented.
    You read and reason only — do not edit anything.

    ## This task

    [FULL TEXT of Task N]

    ## Fields / interfaces this task adds or changes

    [List, scoped to this task only]

    ## Pre-flight findings relevant to this task

    [Paste the slice of the pre-flight report touching this task, if any]

    ## Reference-only paths (exclude from analysis)

    [Paste the Global Constraints' reference-only paths, or "none" — not consumers,
    not must-stay-green, never modified.]

    ## Your job (scoped to this task only — keep it light)

    1. Does this task's added/changed field or interface work with existing consumers
       as-is? If not, what must the implementer also touch (default, migration, callers)?
    2. Does this change cascade to fields or call sites OUTSIDE this task's stated files?
       If yes, name them — the controller decides whether to widen the task or stop.

    ## Report

    - **Works with existing:** yes / no (+ what the implementer must also handle)
    - **Cascade beyond task scope:** none / [list file:line + what changes]
    - **Must-stay-green for this task:** [tests that must still pass after it]
```
