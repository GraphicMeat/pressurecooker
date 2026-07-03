# pressurecooker

An agentic skills framework & software development methodology that works under pressure.

Packaged as a [Claude Code plugin](https://docs.claude.com/en/docs/claude-code/plugins).

Inspired by the [superpowers](https://github.com/obra/superpowers) plugin.

## Structure

```
.
├── .claude-plugin/
│   ├── plugin.json         # Plugin manifest (name, version, deps)
│   └── marketplace.json    # Lets this repo be added as a plugin marketplace
├── skills/                 # The workflow skill chain (SKILL.md per directory)
│   ├── incoming-folder-triage/
│   ├── analyzing-codebase/ # + duplication / call-graph scan scripts
│   ├── brainstorming/
│   ├── writing-plans/
│   ├── using-git-worktrees/
│   ├── executing-plans/    # + blast-radius / implementer / reviewer prompts
│   ├── systematic-debugging/  # + evidence-gatherer prompt, tracing/waiting/defense techniques
│   ├── finishing-a-development-branch/
│   ├── quick-task/         # small-fix path with escalation triggers
│   ├── secure-data-handling/
│   ├── verification-before-completion/
│   └── silent-dev/         # minimal-narration output discipline
└── hooks/                  # Event hooks
    ├── hooks.json
    └── session-start.sh    # dep check + skill routing map + map staleness
```

## Workflow

The skills form one chain — each hands off to the next:

```
brainstorming → writing-plans → using-git-worktrees → executing-plans → finishing-a-development-branch
```

- **brainstorming** — idea → approved design spec (TDD/KISS, industry research for user-facing features)
- **writing-plans** — spec → task-by-task plan with blast-radius / impact analysis
- **using-git-worktrees** — isolated workspace + clean baseline (the regression reference)
- **executing-plans** — always subagent-driven: pre-flight + per-task blast radius, implementer + two-stage review per task
- **finishing-a-development-branch** — verify, then merge / PR / keep / discard

Standalone skills support the chain:

- **incoming-folder-triage** — a dropped folder is a sample or a target; ask before touching (reference-only paths propagate through the whole chain)
- **analyzing-codebase** — read-only recon before brainstorming big features: stack, architecture, duplication scan (never skipped), call graph, top-5 refactoring issues → committed map at `docs/pressurecooker/codebase-map/MAP.md` that brainstorming, blast-radius analysts, and debugging all consume; kept fresh by post-merge delta updates
- **systematic-debugging** — root cause before fixes: anti-workaround gate, architecture-confusion check, refactor-by-extraction (characterization tests → extract module → verify → fix); any red regression in the chain routes here
- **quick-task** — small clearly-scoped fixes without the full chain, but with the floor intact (split unrelated changes, failing test first for behavior changes, consumer check) and hard escalation triggers into the chain
- **secure-data-handling** — secrets and secure data never surface: fingerprint-don't-print diagnostics, env/secret-manager storage patterns, `Secure-data fields:` propagation through spec → plan → subagents → reviews
- **verification-before-completion** — no done/fixed/passing claims without fresh command output; controllers independently verify subagent claims via the diff
- **silent-dev** — minimal-narration output discipline for coding sessions; artifacts, commits, and security warnings stay normal prose

The SessionStart hook injects the skill routing map every session, so the right skill fires without being remembered, and reports codebase-map staleness.

## Project memory & fable mode

Each target project gets a committed memory store at `docs/pressurecooker/memory/` — one fact per file (`type: map | retro | convention`), indexed by a `MEMORY.md` the SessionStart hook injects. The chain reads and writes it: worktree setup records the test command, pre-flight blast radius warms from the consumer map, brainstorming records conventions, and finishing writes a `retro` after every branch (review catches, missed cascades, regression causes) that the next plan's self-review must consult — the learning loop. Memory is an accelerator, never a dependency: missing index means today's behavior.

Execution is risk-tiered: each plan task carries a `Risk:` tier (additive / modifying / interface-changing) that scales per-task ceremony — additive tasks run 2 subagents (implementer + combined reviewer) instead of 4 — and roles route to explicit models (judgment on Opus, mechanical on Haiku). Tiers relax ceremony only; must-stay-green rules never relax.

## Dependencies

Requires the [`caveman`](https://github.com/JuliusBrussee/caveman) plugin. Declared
in `plugin.json` (`dependencies`) and re-checked by the SessionStart hook, which
warns if caveman is not installed.

## Install (local dev)

Add this repo as a marketplace, then install the plugin:

```
/plugin marketplace add /Users/Rokas/Repos/pressureCooker
/plugin install pressurecooker@pressurecooker
```

## License

MIT
