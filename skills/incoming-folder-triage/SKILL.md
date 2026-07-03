---
name: incoming-folder-triage
description: Use when the user drags, drops, adds, copies, or references a new folder/directory into the project - disambiguate whether it is a sample/reference or the target for changes BEFORE reading deeply or editing anything.
---

# Incoming Folder Triage

A new folder just entered the project (dragged in, dropped, copied, or referenced by path). Its role is ambiguous: it could be a **sample to learn from** or the **target you're meant to change**. Guessing wrong wastes work or edits the wrong files.

**Announce at start:** "I'm using the incoming-folder-triage skill to determine this folder's role."

<HARD-GATE>
Do NOT read the folder deeply, refactor it, or make any edits inside it until you have asked which role it plays and the user has answered. A one-line `ls` to see what it is, is fine; anything more waits for the answer.
</HARD-GATE>

## Step 1: Ask

Ask exactly one disambiguating question. Keep it concise:

> "You added `<folder>`. How should I treat it?
> 1. **Sample / reference** — read-only, I learn its patterns and DON'T modify it
> 2. **Target for changes** — this is where the work goes
> 3. **Something else** — tell me"

If a single folder's role is obvious from the user's own words in the same message ("here's an example of…", "apply the fix to `<folder>`"), skip the question and confirm your read in one line instead of asking.

## Step 2: Act on the answer

**Sample / reference:**
- Treat it as read-only. Never edit files inside it.
- Record the path as **reference-only**. This role must survive the handoff: brainstorming writes it into the spec's `Reference-only paths` line, writing-plans copies it into Global Constraints, and executing-plans' subagents receive it — so no downstream worker ever modifies the sample.
- If the folder sits inside the repo and is untracked, add it to `.gitignore` and commit — sample content must not pollute `git status` or sneak into commits.
- Extract what's useful — patterns, conventions, structure, a design to mirror.
- State back what you took from it, then ask what to build or apply elsewhere using it.
- Hand off to `pressurecooker:brainstorming` for the actual work (the sample informs the design; it is not the deliverable).

**Target for changes:**
- Confirm the exact scope before editing: which paths change, and what the change is.
- Then hand off to `pressurecooker:brainstorming` — the folder is now the project context to explore.

**Something else / ambiguous (e.g. "use part of it"):**
- Clarify which parts are reference and which are target. Don't proceed until each folder/path has one clear role.

## Multiple folders

If several folders arrive at once, triage each — they may play different roles (one sample, one target). Don't assume they share a role.

## Key Principle

Role before action. A sample edited by mistake is corrupted reference; a target mistaken for a sample is work not done. One question up front prevents both.
