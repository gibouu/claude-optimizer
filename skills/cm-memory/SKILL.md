---
name: cm-memory
description: Use this skill at the start of every coding session and whenever the user references past work, prior decisions, "what we did", "last time", "where we left off", or asks for context. Reads MEMORY.md, DECISIONS.md, and PROGRESS.md from .claude/state/ and surfaces only the relevant slices. Also use this skill when finishing a unit of work to append a structured memory entry.
---

# Project Memory Protocol

Claude has no memory between sessions by default. This skill enforces a lightweight, file-based memory that survives context resets, branch switches, and Claude Code restarts. No daemon, no database, no network — just three markdown files in `.claude/state/`.

## The three files

| File | Purpose | Owner |
|---|---|---|
| `.claude/state/MEMORY.md` | Stable project facts: stack, conventions, quirks, gotchas | Claude appends; user edits |
| `.claude/state/DECISIONS.md` | One-line architectural decisions with date + reason | Claude appends |
| `.claude/state/PROGRESS.md` | Rolling work log, newest first | Claude appends |

If any file is missing, create it with the header from `templates/` in this skill.

## On session start

1. Read all three files in one batch (single `view` call per file).
2. **Do not** dump them back to the user. Hold them as background context.
3. If `PROGRESS.md` shows an open task with status `IN_PROGRESS`, surface a one-line resume offer: *"Last session ended mid-way through X. Resume?"*

## When to write

Append to `PROGRESS.md` when:
- A task transitions state (started, blocked, done)
- A non-obvious bug is fixed (capture root cause, not the symptom)
- A test suite is added or changed materially

Append to `DECISIONS.md` when:
- An architectural choice is made (library picked, pattern chosen, tradeoff accepted)
- A previous decision is reversed

Append to `MEMORY.md` when:
- A project-wide convention is established or discovered
- A non-obvious gotcha would burn a future session ("the auth middleware silently swallows errors before v3")

## Entry format

Keep entries terse. One line is fine. Use this shape:

```
[2026-04-30] <area>: <fact, decision, or progress note>. Why: <reason in <=10 words>.
```

Bad: a paragraph explaining the auth refactor.
Good: `[2026-04-30] auth: switched to JWT refresh rotation. Why: revoke-on-logout was impossible with stateless tokens.`

## Privacy & secret handling

State files may end up in git. Treat them like code, not like a scratchpad.

**Never write to any state file:**
- API keys, tokens, passwords, or credentials of any kind
- Database connection strings (even read-only ones)
- Internal URLs, hostnames, or IP addresses (use a placeholder like `<internal-host>`)
- Customer or user-identifying information from real data
- Anything wrapped in `<private>...</private>` tags in the user's message

If a memory entry would naturally include any of the above, rewrite the entry to capture the *fact* without the *value*. For example:

- Bad: `[2026-04-30] api: switched to key sk_live_abc123...`
- Good: `[2026-04-30] api: rotated production key. Stored in 1Password.`

If you're unsure whether something is sensitive, leave it out. The user can always add it themselves.

**On read:** if a state file already contains something that looks like a secret (long random string, recognisable token prefix, etc.), do not echo it back to the user, do not include it in tool calls, and surface a one-line warning that the file should be reviewed.

## Reading discipline

When the user asks "what did we do about X", do not re-read all three files end to end. Use `grep` (via bash) on the keyword first, then read only the matching sections. Files grow; cost grows with them.
