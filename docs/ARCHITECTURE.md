# Architecture

```
session start
    │
    ▼
SessionStart hook ──► init_state.sh (idempotent)
                          │
                          ▼
              .claude/state/{MEMORY,DECISIONS,PROGRESS,TASKS}.md
                          │
                          ▼
       skills auto-activate based on description match
                          │
              ┌───────────┴───────────┐
              ▼                       ▼
       cm-session-resume         cm-memory
              │                       │
              ▼                       ▼
        Claude reads state    Claude maintains state

user prompt ──► UserPromptSubmit hook (currently no-op)

tool use:
   Edit/Write ──► PostToolUse hook ──► reminder every 10 edits

turn ends ──► Stop hook ──► reminds about quality gate if dirty git tree

session end ──► SessionEnd hook ──► reset edit counter
```

## Why files, not a database

Three reasons:

1. **Diff-able.** A junior teammate can see what Claude decided in a PR review. SQLite blobs cannot.
2. **Editable.** When Claude gets something wrong in `MEMORY.md`, you fix it with your editor in 5 seconds. Same with a database means writing SQL or building a UI.
3. **Portable.** It works in dev containers, on Windows, on locked-down corporate laptops, and in CI. No port allocation, no daemon lifecycle, no migration scripts.

The trade-off is search at scale. If your `PROGRESS.md` ever exceeds ~5MB, switch to the upstream `cavemem` or `claude-mem` approach. Until then, `grep` is faster and simpler.

## Why five skills, not fifty

Skill descriptions are loaded into context on every prompt so Claude can decide whether to activate them. Each one has a small token cost and a small cognitive cost (Claude has to filter it past). Five well-scoped skills beat fifty narrow ones.

If a skill description starts with "Use this skill when…" and you can't finish the sentence in 15 words, the skill is wrong.

## Extending

To add a skill:

1. Create `skills/<name>/SKILL.md`.
2. Frontmatter must have `name` and `description`. The description is what Claude reads to decide when to activate — write it carefully.
3. Restart Claude Code or run `/plugin reload` (depending on version).

To add a hook:

1. Edit `hooks/hooks.json`. Use `${CLAUDE_PLUGIN_ROOT}` for any path inside the plugin.
2. Drop the script in `scripts/`. `chmod +x` it.
3. Test with `claude --debug` to see hook output.

To add a slash command:

1. Create `commands/<name>.md` with frontmatter `description:`.
2. The body is the prompt Claude executes when the user types `/cm:<name>` (the prefix is the plugin name).
