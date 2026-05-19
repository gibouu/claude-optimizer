---
name: cm-checkpoint
description: Use after a commit, before push/PR, on user completion signals ("done", "ship it"), when a multi-step task starts or changes state, after a non-obvious decision or gotcha, when the user references prior work, or when prompt_submit/stop hooks report stale state. Owns the .claude/state/ files and writes PROGRESS / TASKS / DECISIONS / MEMORY atomically in one pass.
---

# Checkpoint — the project state protocol

Claude has no memory between sessions by default. This skill enforces a lightweight, file-based memory that survives context resets, branch switches, and Claude Code restarts. No daemon, no database, no network — just plain markdown files in `.claude/state/`.

It is the single write-side entry point. Earlier the plugin split this across `cm-memory` and `cm-task-tracker`; the model invoked them inconsistently because the moments were slightly different and the choice of which-skill-now was ambiguous. This skill collapses the choice: when *any* trigger fires, invoke this one skill, which writes everything that's warranted, atomically. (`cm-session-resume` is the read-side counterpart, run once at SessionStart.)

## The four files

| File | Purpose | Owner |
|---|---|---|
| `.claude/state/PROGRESS.md` | Rolling work log, newest first | Claude appends |
| `.claude/state/TASKS.md` | Explicit task ledger, one section per task | Claude appends/updates |
| `.claude/state/DECISIONS.md` | One-line architectural decisions with date + reason | Claude appends |
| `.claude/state/MEMORY.md` | Stable project facts: stack, conventions, quirks, gotchas | Claude appends; user edits |

If any file is missing, `cm-session-resume` / `init_state.sh` creates it. Don't hand-create them here.

## When this skill fires

The frontmatter `description:` is the contract. Concretely:

- **Post-commit:** immediately after a successful `git commit` returns 0.
- **Pre-push / pre-PR:** before invoking `git push` or `gh pr create`. Run before, not after — the push should reflect the checkpointed state.
- **Completion phrases from the user:** "done", "ship it", "looks good", "push it", "merge it", "we're good", "lgtm".
- **Multi-step work starting or changing state:** the moment the user describes work with more than one obvious sub-step, or a task transitions (started, blocked, done). Don't ask permission — create the TASKS entry, then start step 1.
- **A non-obvious decision or gotcha:** an architectural choice made/reversed, or a fact that would burn a future session.
- **Harness directives:** when `prompt_submit.sh` injects a `[claude-optimizer] … Invoke cm-checkpoint` block, or `stop.sh` exits with the stale-state message — those name this skill as the primary action.

## What this skill writes

Atomic four-file pass. Skip any file where there's nothing meaningful to add — *don't* write filler. The point is real continuity, not box-checking.

| File | Write when… | Format |
|---|---|---|
| `PROGRESS.md` | Any non-trivial work this turn; a task transitions; a non-obvious bug is fixed (capture root cause, not symptom); a test suite is added/changed materially | `[YYYY-MM-DD HH:MM] <area>: <what shipped or progressed>. Why: <reason ≤10 words>.` Newest first. |
| `TASKS.md` | A task transitioned state, completed, or new sub-steps emerged | Tick boxes, update the status header, add sub-steps under the parent. Don't rewrite history. |
| `DECISIONS.md` | An architectural choice was made or reversed (library picked, pattern chosen, tradeoff accepted) | `[YYYY-MM-DD] <area>: <decision>. Why: <reason>.` One line. |
| `MEMORY.md` | A project-wide convention is established/discovered, or a non-obvious gotcha would burn a future session | One line. Stable facts only — no per-task notes. |

Entry shape (PROGRESS / DECISIONS / MEMORY):

```
[2026-04-30] <area>: <fact, decision, or progress note>. Why: <reason in <=10 words>.
```

Bad: a paragraph explaining the auth refactor.
Good: `[2026-04-30] auth: switched to JWT refresh rotation. Why: revoke-on-logout impossible with stateless tokens.`

`PROGRESS.md` is auto-touched by the post-edit hook with `[time] tool: path` lines. Those are mechanical and don't replace meaningful summaries — write one human-meaningful entry on top of each session's `[auto]` accumulation.

## Order of writes

PROGRESS → DECISIONS → TASKS → MEMORY. PROGRESS is highest-frequency and lowest-stakes; MEMORY is rarest and most permanent. Writing in this order ensures partial failures still produce the most useful state.

## The task ledger — TASKS.md

One section per task. Keep it short.

```
## <task title>
status: TODO | IN_PROGRESS | BLOCKED | DONE
opened: 2026-04-30
steps:
  - [x] step that's done
  - [ ] step still to do
  - [ ] next step
notes:
  - any blocker, decision, or surprise (one line each)
```

Discipline:

- Create the entry the moment the user describes work with more than one obvious sub-step. Don't ask permission. Create it, then start step 1.
- Update status the moment it changes — not at the end of the session. Tick boxes as steps complete. Do not retroactively reconstruct the list.
- If a step reveals a new sub-task, add it under the parent. Don't silently expand the original step.
- **If you're about to start something not in the steps list, stop and ask** whether to add it or whether the user wants the original task finished first. This is the single most important rule for staying focused.

**Done means done.** A task is `DONE` only when: all steps are checked; tests pass (or there are none and the user confirmed that's fine); the change is committed or explicitly handed back to the user. Not before. "I think it's done" is `IN_PROGRESS` with a note.

**Pruning.** When a task hits `DONE`, leave it for one session, then move it to `.claude/state/archive/TASKS-<YYYY-MM>.md`. Keeps the active ledger short. Same principle for any state file that grows past ~500 lines — archive old entries.

## Privacy & secret handling

State files may end up in git. Treat them like code, not like a scratchpad.

**Never write to any state file:**
- API keys, tokens, passwords, or credentials of any kind
- Database connection strings (even read-only ones)
- Internal URLs, hostnames, or IP addresses (use a placeholder like `<internal-host>`)
- Customer or user-identifying information from real data
- Anything wrapped in `<private>...</private>` tags in the user's message

If an entry would naturally include any of the above, rewrite it to capture the *fact* without the *value*:

- Bad: `[2026-04-30] api: switched to key sk_live_abc123...`
- Good: `[2026-04-30] api: rotated production key. Stored in 1Password.`

If you're unsure whether something is sensitive, leave it out — the user can always add it themselves. This complements `cm-secret-hygiene` (which governs which *files* Claude may read); this section governs what may be *written into state*.

**On read:** if a state file already contains something that looks like a secret (long random string, recognisable token prefix), do not echo it back, do not include it in tool calls, and surface a one-line warning that the file should be reviewed.

## Reading discipline

When the user asks "what did we do about X", do not re-read every state file end to end. `grep` (via bash) on the keyword first, then read only the matching sections. Files grow; cost grows with them.

## What not to do

- Don't dump checkpoint contents back into the chat. Confirm with one sentence ("checkpoint written: progress + 1 decision") plus the next pending step.
- Don't invoke this skill speculatively when nothing meaningful has changed since the last checkpoint. The auto-PROGRESS log already covers "something happened"; this skill is for "something *meaningful* happened."
- Don't write secrets, credentials, customer data, or anything matching the patterns above — even paraphrased.
