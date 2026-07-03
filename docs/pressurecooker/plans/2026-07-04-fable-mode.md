# Fable Mode Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use pressurecooker:executing-plans to implement this plan task-by-task. All development is subagent-driven. Steps use checkbox (`- [ ]`) syntax for tracking.
>
> **Execution note for this specific plan:** the target repository is the pressureCooker plugin itself — markdown skill documents plus one bash hook, no test suite. The regression reference is: the hook runs and emits valid JSON, and cross-skill references stay consistent (grep sweep). Where the plan says "verify", that is the test.

**Goal:** Implement the approved fable-mode spec (`docs/pressurecooker/specs/2026-07-04-fable-mode-design.md`): committed project memory, SessionStart injection, memory read/write steps across the chain, risk-tiered execution, and explicit model routing.

**Architecture:** Memory is plain committed markdown in the *target project* (`docs/pressurecooker/memory/`), indexed by a small `MEMORY.md` injected at session start by the plugin hook. Chain skills gain minimal read/write steps. executing-plans scales per-task ceremony by a mechanical `Risk:` tier and routes roles to explicit models.

**Tech Stack:** Markdown (SKILL.md files), bash (`hooks/session-start.sh`), jq.

## Global Constraints

- Memory files and all artifacts are normal prose, never caveman.
- Memory is an accelerator, never a dependency: every reader falls back to current behavior when the index is missing/empty.
- Resource cuts never weaken safety rails: must-stay-green semantics, pre-flight blast radius, and full-suite gates are unchanged.
- Risk tier ambiguity resolves upward (higher tier).
- No secret values may ever appear in memory files (secure-data-handling applies to writers).
- Reference-only paths mechanism untouched (spec: out of scope).

## Blast Radius

- **Consumers:** all 6 chain skills reference each other; the hook is executed by every session. combined-reviewer-prompt.md is new (no consumers yet). Model Selection section in executing-plans is replaced — no other file references it (verify by grep).
- **Must-stay-green:** `bash -n hooks/session-start.sh` + live hook run emitting valid JSON with routing map still present; `grep -rn "superpowers:" skills/` stays empty; every `pressurecooker:*` reference resolves to an existing skill directory.
- **Compatibility:** hook must keep working when `docs/pressurecooker/memory/` is absent (all current projects); MEMORY.md injection is additive to existing context (dep check, map staleness, routing).

---

### Task 1: Hook — inject memory index [Risk: modifying]

**Files:** Modify: `hooks/session-start.sh`

**Impact:**
- Breaks-risk: hook emits invalid JSON → every session start breaks. The current script already builds JSON via `jq -Rs` with a sed fallback; memory content must flow through the same escaping path.
- Must-stay-green: hook run with no memory dir behaves exactly as today (dep line + map line + routing present).

- [ ] **Step 1: Add memory-index block** after the map-staleness block: if `${project_dir}/docs/pressurecooker/memory/MEMORY.md` exists and is non-empty, append `PROJECT MEMORY INDEX:` + file contents to `ctx`; also emit one line telling skills to read individual memory files on demand and verify against current code. Project root already resolved via `CLAUDE_PROJECT_DIR` fallback pwd — extend fallback to `git rev-parse --show-toplevel` before pwd.
- [ ] **Step 2: Verify no-memory case:** run hook in repo (no memory dir) → output unchanged vs. today (JSON valid via `jq .`, routing present, no PROJECT MEMORY text).
- [ ] **Step 3: Verify memory case:** create scratch `docs/pressurecooker/memory/MEMORY.md` with a quote-and-newline-containing line, run hook, assert `jq .` parses and index text present. Delete scratch file.
- [ ] **Step 4: Commit.**

### Task 2: using-git-worktrees — map read/write [Risk: modifying]

**Files:** Modify: `skills/using-git-worktrees/SKILL.md`

**Impact:**
- Breaks-risk: none functional (doc). Must not contradict baseline semantics.
- Must-stay-green: baseline/regression wording intact.

- [ ] **Step 1:** In Step 4 (Verify Clean Baseline): before auto-detecting the test command, check `docs/pressurecooker/memory/` for a `map` memory recording it; verify cheaply (run it) rather than re-deriving. After a successful baseline: write/update the `map` memory (`test command + baseline shape`, frontmatter `name/description/type: map`) and its MEMORY.md index line. Include memory-hygiene one-liner (update-don't-duplicate, delete-if-wrong, normal prose).
- [ ] **Step 2:** Verify: grep for `type: map` guidance and fallback wording ("memory missing → detect as today").
- [ ] **Step 3: Commit.**

### Task 3: brainstorming — map/convention read, convention write [Risk: modifying]

**Files:** Modify: `skills/brainstorming/SKILL.md`

- [ ] **Step 1:** Checklist item 1 gains: read `docs/pressurecooker/memory/MEMORY.md` first (with codebase map, if both exist read both); `map`/`convention` memories cover ground → skip re-exploring it after a cheap staleness spot-check.
- [ ] **Step 2:** Spec-writing section gains: durable project decisions surfaced during design → write/update `convention` memory + index line (names only for secure fields; normal prose).
- [ ] **Step 3:** Verify by grep; commit.

### Task 4: writing-plans — retro/map reads, Risk tier [Risk: modifying]

**Files:** Modify: `skills/writing-plans/SKILL.md`

- [ ] **Step 1:** Impact Assessment gains lead bullet: read `retro` + `map` memories — past misses become checklist items; map's consumer graph feeds the Blast Radius (verify against code, memory is a hint).
- [ ] **Step 2:** Task `Impact:` block template gains `Risk:` line with the three mechanical tiers (additive / modifying / interface-changing) + ambiguity-resolves-up rule.
- [ ] **Step 3:** Self-Review gains check 6: "Consulted retro memories? Does any task repeat a recorded past miss? Does every task carry a Risk tier?"
- [ ] **Step 4:** Verify by grep (three anchors); commit.

### Task 5: executing-plans — map in pre-flight, tiered ceremony, model routing [Risk: interface-changing]

(Interface: changes the per-task dispatch contract other prompt files serve.)

**Files:** Modify: `skills/executing-plans/SKILL.md`, `skills/executing-plans/blast-radius-prompt.md`

- [ ] **Step 1:** Step 1 (pre-flight): analyst also receives `map` memories (consumer/contract graph) — verifies deltas instead of cold discovery; after pre-flight, controller writes updated consumer/contract map back to memory (update-don't-duplicate).
- [ ] **Step 2:** Step 2 (per-task loop) gains tier table: additive → skip per-task analyst, single combined reviewer (`./combined-reviewer-prompt.md`); modifying → analyst skipped when pre-flight covers the touched area, two-stage review; interface-changing → always analyst + full two-stage. Note: tiers relax ceremony only — must-stay-green rules never relax. Missing `Risk:` on a task → treat as interface-changing (resolve up).
- [ ] **Step 3:** Replace "Model Selection" section with the spec's explicit table (controller/analysts/quality reviewer → Opus 4.8; mechanical implementer + spec/combined reviewer → Haiku 4.5; judgment implementer → Opus 4.8) + existing BLOCKED-re-dispatch rule cross-ref.
- [ ] **Step 4:** blast-radius-prompt preflight mode gains optional `## Known consumer map (from project memory)` input slot — verify deltas, report corrections.
- [ ] **Step 5:** Verify by grep (tier table, model table, combined-reviewer ref); commit.

### Task 6: combined-reviewer-prompt.md (new) [Risk: additive]

**Files:** Create: `skills/executing-plans/combined-reviewer-prompt.md`

**Interfaces:** Consumed by Task 5's tier table for additive tasks. Merges spec-reviewer + code-quality-reviewer checklists into one dispatch: spec compliance (task text vs. diff), quality (decomposition, clarity, YAGNI, patterns), must-stay-green confirmation, reference-only + secure-data checks (each Critical). Report: ✅/❌ per dimension; ❌ on either loops the implementer.

- [ ] **Step 1:** Write template following the two existing reviewer prompts' structure.
- [ ] **Step 2:** Verify template refers only to inputs the controller can paste; commit.

### Task 7: finishing — retro write (learning-loop engine) [Risk: modifying]

**Files:** Modify: `skills/finishing-a-development-branch/SKILL.md`

- [ ] **Step 1:** After Step 1's gate passes (before presenting options): write one `retro` memory — what reviews caught, cascade gaps found at execution time, regressions hit + causes; update existing recurring retro instead of duplicating; update MEMORY.md index; consolidate when index exceeds ~30 lines. Skip silently when nothing notable (no empty retros).
- [ ] **Step 2:** Verify by grep; commit.

### Task 8: README — project memory section [Risk: additive]

**Files:** Modify: `README.md`

- [ ] **Step 1:** Add "Project memory" bullet/section: committed store at `docs/pressurecooker/memory/` (map/retro/convention), MEMORY.md index injected by hook, learning loop via finishing retro, risk-tiered execution + model routing one-liner.
- [ ] **Step 2:** Final sweep: `grep -rn "superpowers:" skills/` empty; every `pressurecooker:*` ref resolves; hook run valid JSON. Commit.

## Self-Review (completed at write time)

1. Spec coverage: Components 1–5 map to Tasks 1–8 (Component 1's format is embedded in each writer's step — no central format file needed; hygiene rules carried by writers). Out-of-scope items untouched. Edge cases: missing-index fallback in every reader step; conflict rule in Task 7 (update-don't-duplicate + one-line index); tier ambiguity in Tasks 4/5.
2. No placeholders.
3. Consistency: `combined-reviewer-prompt.md` name matches Task 5 reference and spec; tier names identical across Tasks 4/5.
4. Regression: hook no-memory case (Task 1 Step 2) is the compatibility gate; final sweep in Task 8.
5. Fit: mirrors existing conventions (announce lines, prompt-template style, docs/pressurecooker/* layout).
