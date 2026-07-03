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
│   ├── brainstorming/
│   ├── writing-plans/
│   ├── using-git-worktrees/
│   ├── executing-plans/    # + blast-radius / implementer / reviewer prompts
│   ├── systematic-debugging/  # + evidence-gatherer prompt, tracing/waiting/defense techniques
│   └── finishing-a-development-branch/
└── hooks/                  # Event hooks
    ├── hooks.json
    └── session-start.sh
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

Two standalone skills support the chain:

- **incoming-folder-triage** — a dropped folder is a sample or a target; ask before touching (reference-only paths propagate through the whole chain)
- **systematic-debugging** — root cause before fixes: anti-workaround gate, architecture-confusion check, refactor-by-extraction (characterization tests → extract module → verify → fix); any red regression in the chain routes here

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
