---
name: cm-session-resume
description: Use once per session at SessionStart, before any response to the user's first message in a new conversation, and after any /clear or /compact event that resets in-context history. Reads .claude/state/{MEMORY,DECISIONS,TASKS,PROGRESS}.md, surfaces any IN_PROGRESS or BLOCKED task in one line, and otherwise stays silent. Primes the session with the minimum context needed.
---

# Session Resume

Triggered automatically by SessionStart. Runs once.

## Steps

1. Check that `.claude/state/` exists. If not, run `${CLAUDE_PLUGIN_ROOT}/scripts/init_state.sh` to create it with empty templates, then exit silently.
2. Read `MEMORY.md` (project facts), `DECISIONS.md` (last 10 entries only), `TASKS.md` (only `IN_PROGRESS` and `BLOCKED` sections), `PROGRESS.md` (last 5 entries only).
3. **If** there's an `IN_PROGRESS` task, prepend a single line to your first reply:
   > *Resuming "<task title>" — next step: <first unchecked step>. Continue, or switch?*
4. **If** there's a `BLOCKED` task, surface the blocker before doing anything else.
5. **If** neither exists, say nothing about state. Just answer the user's first message.

## What not to do

- Do not dump the contents of any state file to the user.
- Do not summarise prior decisions unprompted.
- Do not announce that the memory system is loaded. Silence is the success state.

## Cost

This whole flow should be 4 file reads max, all small. If a state file has grown past ~500 lines, the file is wrong — archive old entries (see `cm-task-tracker` and `cm-memory`).
