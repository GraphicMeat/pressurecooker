---
name: secure-data-handling
description: Use whenever code, debugging, tests, logs, or artifacts touch credentials, API keys, tokens, passwords, PII, payment data, or other secure data - secrets must never surface in output, logs, commits, fixtures, prompts, or documents
---

# Secure Data Handling

## Overview

Secrets and secure data must **never surface**: not in chat output, not in logs, not in commits, not in test fixtures, not in error messages, not in plan/spec/map artifacts, not in subagent prompts, not in memory files. A leaked secret is a second incident on top of whatever you were fixing — with mandatory rotation and possibly disclosure.

**Announce at start:** "I'm using the secure-data-handling skill."

**Core principle:** you can almost always get the diagnostic value of a secret without the secret — fingerprint it, don't print it.

## The Iron Law

```
A SECRET THAT REACHES ANY PERSISTED OR SHARED SURFACE IS COMPROMISED
```

Persisted/shared surfaces: log pipelines, git history (any commit, ever — history survives deletion), chat transcripts, tickets, Slack, screenshots, artifacts, fixtures, environment dumps, subagent prompt text, memory files.

## Never-Surface Rules

- **Never print or log secret values** — not "temporarily", not truncated-by-hand, not at debug level. Debug-level logs ship to the same pipeline.
- **Never commit secrets** — no keys in fixtures ("we'll clean it up later" = history rewrite or rotation later), no `.env` in git (gitignore it; commit `.env.example` with placeholder names only), no secrets in code defaults.
- **Never echo secrets in errors** — exception messages and stack traces flow to logs and users.
- **Never put secrets in URLs/query strings** — they land in access logs, proxies, browser history.
- **Never paste secret values into subagent prompts, plans, specs, maps, or memory.** Chain artifacts are committed documents. Reference by NAME (`ACME_PAY_KEY`, "the staging key"), never by value.
- **Already-exposed secret (pasted in chat/Slack/ticket) = compromised.** Say so, use it from the environment not by re-pasting, and flag rotation as a required follow-up. Exposure is not undone by deleting the message.

## Diagnostic Patterns (get the signal without the secret)

| Need | Pattern |
|------|---------|
| Which key is in use? | Log `sha256(key)[:12]` fingerprint + non-secret prefix (`sk_test_` vs `sk_live_`) + length. Compare fingerprint against the secret manager. |
| Is the signed payload right? | Log `sha256(canonical_string)` and compare against the same hash computed locally / from docs' worked example. |
| Are headers right? | Log header NAMES + redacted values: `<redacted len=N sha256:abc123>`. Structure visible, values not. |
| Reproduce signing/crypto locally | Plaintext debugging goes to your local terminal only — never the log pipeline. |
| Test against a real environment | Key from env var / CI masked secret; test skips cleanly when unset. |
| Test the algorithm itself | Vector test with the provider's DOCUMENTED example key + expected output — dummy data, runs everywhere, catches drift. |

## Storage Patterns (where secure data lives)

- **Secrets (keys, tokens, credentials):** environment variables injected from a secret manager (Vault, AWS/GCP secret manager, CI masked secrets). Never in code, config files in git, or client-side storage. No fallback defaults — missing secret = fail at startup with the NAME of what's missing, never a baked-in value.
- **Passwords:** slow adaptive hash (argon2id / bcrypt), never reversible encryption, never plaintext.
- **PII:** minimize first (don't store what you don't need), then field-level encryption at rest for what remains (keys in KMS, not next to the data); mask by default in UI/logs (`***-**-1234`); define retention/TTL.
- **Payment data:** don't touch raw PAN if avoidable — use the provider's tokenization; you store their token, they carry the PCI scope.
- **Browser/client:** session tokens in httpOnly+Secure cookies, not localStorage; native apps use the OS keychain.
- **Comparison of secrets:** constant-time compare, never `==`.
- **Rotation-friendly by construction:** secrets referenced by name/lookup so rotation is a config change, not a code change.

## Secure-Data Fields in the Chain

Like reference-only paths, secure data propagates through the whole chain:

- **brainstorming:** spec lists a `Secure-data fields:` line — which fields/flows carry secrets, PII, payment data.
- **writing-plans:** copies it into Global Constraints; Impact Assessment asks "does this change touch secure data?" — if yes, affected tasks carry the handling pattern (this skill) in their text.
- **executing-plans:** subagent prompts name secure fields and the rule; implementers never hardcode, log, or fixture them; reviewers treat a surfaced secret as Critical.
- **analyzing-codebase:** the MAP must never contain secret values. A hardcoded secret found during analysis → Risks entry saying WHERE (file:line) and WHAT KIND — never the value — flagged Critical (rotation + relocation needed).
- **systematic-debugging:** evidence and error text get redacted before appearing in reports; the evidence-gatherer fingerprints, never prints.

## Common Rationalizations

| Excuse | Reality |
|--------|---------|
| "Just log it temporarily, we'll remove it after" | Logs are retained, indexed, forwarded. Removal doesn't un-ship it. Fingerprint instead. |
| "Hardcode the key in the fixture for now, clean up later" | Git history is forever. Env var + skip-if-unset costs 60 seconds. |
| "It's only the staging/test key" | Staging keys open staging data and often production-adjacent scope. Same rules. |
| "The lead told me to dump the full headers" | Redacted headers answer the same diagnostic question. Deliver the signal, not the secret — and say why in one line. |
| "It's already in Slack anyway" | Then it's compromised — use it from env, flag rotation. Don't spread it further. |

## Red Flags — STOP

- A secret value about to appear in: log call, error message, commit, fixture, chat output, subagent prompt, plan/spec/map/memory file
- `.env` not in `.gitignore`; secret with a hardcoded default; token in a URL
- "Temporarily" + any persisted surface in the same sentence

## Integration

- Applies ON TOP of any active skill: quick-task, executing-plans implementers, systematic-debugging evidence, analyzing-codebase mapping
- Exposure discovered → treat as incident: flag rotation, log location (never value) — and if it's a bug's root cause, route `pressurecooker:systematic-debugging`
