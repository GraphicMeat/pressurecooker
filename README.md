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
│   ├── test-driven-development/  # + testing anti-patterns reference
│   └── silent-dev/         # minimal-narration output discipline
├── agents/                 # Subagent types with silence baked into their system prompts
│   ├── implementer.md      # pressurecooker:implementer — writes code, TDD, single compressed report
│   └── investigator.md     # pressurecooker:investigator — read-only analysis/review, never edits
├── hooks/                  # Event hooks
│   ├── hooks.json
│   └── session-start.sh    # dep check + skill routing map + map staleness + memory index
├── mcp/
│   └── map-server.mjs      # zero-dep MCP server exposing the codebase map as tools
└── .mcp.json               # registers the pressurecooker-map server
```

## Workflow

The skills form one chain — each hands off to the next:

```
brainstorming → writing-plans → using-git-worktrees → executing-plans → finishing-a-development-branch
```

- **brainstorming** — idea → approved design spec (TDD/KISS/SOLID, industry research for user-facing features)
- **writing-plans** — spec → task-by-task plan with blast-radius / impact analysis
- **using-git-worktrees** — isolated workspace + clean baseline (the regression reference)
- **executing-plans** — subagent-driven by default: pre-flight + per-task blast radius, implementer + two-stage review per task; criteria-gated inline economy tier for small additive/warm-context tasks
- **finishing-a-development-branch** — verify, then merge / PR / keep / discard

Standalone skills support the chain:

- **incoming-folder-triage** — a dropped folder is a sample or a target; ask before touching (reference-only paths propagate through the whole chain)
- **analyzing-codebase** — read-only recon before brainstorming big features: stack, architecture, duplication scan (never skipped), call graph, top-5 refactoring issues → committed map at `docs/pressurecooker/codebase-map/MAP.md` that brainstorming, blast-radius analysts, and debugging all consume; kept fresh by post-merge delta updates
- **systematic-debugging** — root cause before fixes: anti-workaround gate, architecture-confusion check, refactor-by-extraction (characterization tests → extract module → verify → fix); any red regression in the chain routes here
- **quick-task** — small clearly-scoped fixes without the full chain, but with the floor intact (split unrelated changes, failing test first for behavior changes, consumer check) and hard escalation triggers into the chain
- **secure-data-handling** — secrets and secure data never surface: fingerprint-don't-print diagnostics, env/secret-manager storage patterns, `Secure-data fields:` propagation through spec → plan → subagents → reviews
- **verification-before-completion** — no done/fixed/passing claims without fresh command output; controllers independently verify subagent claims via the diff
- **silent-dev** — minimal-narration output discipline for coding sessions; artifacts, commits, and security warnings stay normal prose
- **test-driven-development** — the RED-GREEN-REFACTOR discipline every implementer runs: failing test first, minimal code, Step 4b regression check; characterization tests (refactors) explicitly distinguished

The SessionStart hook injects the skill routing map every session, so the right skill fires without being remembered, and reports codebase-map staleness.

All chain dispatches run on the plugin's own agent types — `pressurecooker:implementer` (writes files) and `pressurecooker:investigator` (read-only) — whose system prompts enforce working silently and returning one compressed report. A custom agent's system prompt replaces the default agent prompt entirely, so the silence rule can't be overridden by narration habits; prompt footers remain as a fallback for other agent types.

## Project memory & fable mode

Each target project gets a committed memory store at `docs/pressurecooker/memory/` — one fact per file (`type: map | retro | convention`), indexed by a `MEMORY.md` the SessionStart hook injects. The chain reads and writes it: worktree setup records the test command, pre-flight blast radius warms from the consumer map, brainstorming records conventions, and finishing writes a `retro` after every branch (review catches, missed cascades, regression causes) that the next plan's self-review must consult — the learning loop. Memory is an accelerator, never a dependency: missing index means today's behavior.

Execution is risk-tiered: each plan task carries a `Risk:` tier (additive / modifying / interface-changing) that scales per-task ceremony — additive tasks run 2 subagents (implementer + combined reviewer) instead of 4 — and roles route to explicit models (judgment on Opus, mechanical on Haiku; the investigator agent defaults to Sonnet). Tiers relax ceremony only; must-stay-green rules never relax.

Token economy is built in: plans stamp each task `Execution: inline | subagent` (additive + ≤2 files + complete spec → inline-eligible), the controller may implement eligible tasks inline under the executing-plans Inline Execution rules (reviews per tier still dispatch; fresh-eyes review never relaxes for modifying work), and debugging Phase 1–2 runs inline when the suspect files are already in context. Economy mode (`PRESSURECOOKER_ECONOMY=1` or a `docs/pressurecooker/ECONOMY` flag file) makes inline-first the session default; the guiding heuristic either way: inline for small warm-context work, subagents for anything that would flood controller context — wide exploration inline is re-paid every turn after.

The plugin also ships the `pressurecooker-map` MCP server (`map_overview`, `map_section`, `consumers_of`, `map_staleness`) — agents query the codebase map instead of re-reading MAP.md — and a CI template (`skills/finishing-a-development-branch/ci-template.yml`) that finishing offers to projects without CI: full suite server-side plus map staleness/duplication drift warnings.

## Dependencies

Requires the [`caveman`](https://github.com/JuliusBrussee/caveman) plugin. Declared
in `plugin.json` (`dependencies`) and re-checked by the SessionStart hook, which
warns if caveman is not installed.

## Install

Run these in an interactive `claude` terminal.

**From GitHub (recommended):**

```
/plugin marketplace add GraphicMeat/pressurecooker
/plugin install pressurecooker@pressurecooker
```

**From a local clone** (point at the repo directory — no trailing slash, no leading `~`; a bare local path can be misread as an option, so use the full path or `.` from inside the repo):

```
/plugin marketplace add .
/plugin install pressurecooker@pressurecooker
```

Then install the required dependency (served from this same marketplace):

```
/plugin install caveman@pressurecooker
```

The `pressurecooker-map` MCP server needs `node` on your PATH. Reload the session after install so the SessionStart hook loads.

## License

MIT
