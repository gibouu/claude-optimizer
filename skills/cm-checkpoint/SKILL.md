---
name: cm-checkpoint
description: Use after every successful `git commit`, before any `git push`, before any `gh pr create`, when the user signals completion ("done", "ship it", "looks good", "push it", "merge it"), and whenever the harness PromptSubmit or Stop hook reports stale state. The single bundled "save progress" skill — atomically writes to all four .claude/state/ files in one pass, so the model has one obvious checkpoint moment instead of remembering to invoke cm-task-tracker, cm-memory, and others separately.
---

# Bundled Checkpoint

The `cm-task-tracker`, `cm-memory`, and `cm-quality-gate` skills each describe what to write and when. Empirically, the model invokes them inconsistently because the moments are slightly different and the choice of which-skill-now is ambiguous. This skill collapses the choice: when *any* of the trigger events fire, invoke this one skill, which then writes everything that's warranted, atomically.

## When this skill fires

The frontmatter `description:` is the contract. Concretely:

- **Post-commit:** Immediately after a successful `git commit` returns 0.
- **Pre-push / pre-PR:** Before invoking `git push` or `gh pr create`. Run before, not after — the push should reflect the checkpointed state.
- **Completion phrases from the user:** "done", "ship it", "looks good", "push it", "merge it", "we're good", "lgtm".
- **Harness directives:** When `prompt_submit.sh` injects a `[claude-optimizer] State checkpoint required.` block, or when `stop.sh` exits 2 with the stale-state message — those messages name this skill as the primary action.

## What this skill writes

Atomic four-file pass. Skip any file where there's nothing meaningful to add — *don't* write filler. The point is real continuity, not box-checking.

| File | Write when… | Format |
|---|---|---|
| `PROGRESS.md` | Always (on any non-trivial work this turn) | `[YYYY-MM-DD HH:MM] <area>: <what shipped or progressed>. Why: <reason ≤10 words>.` |
| `TASKS.md` | A task transitioned state, completed, or new sub-steps emerged | Tick boxes, update status header, add sub-steps under the parent. Don't rewrite history. |
| `DECISIONS.md` | An architectural choice was made or reversed | `[YYYY-MM-DD] <area>: <decision>. Why: <reason>.` One line. |
| `MEMORY.md` | A non-obvious project fact or gotcha was learned | One line. Stable facts only — no per-task notes. |

PROGRESS.md is auto-touched by the post-edit hook with `[time] tool: path` lines. Those are mechanical and don't replace meaningful summaries — overwrite each session's `[auto]` accumulation by writing one human-meaningful entry on top.

## Order of writes

PROGRESS first → DECISIONS → TASKS → MEMORY. PROGRESS is highest-frequency and lowest-stakes; MEMORY is rarest and most permanent. Writing in this order ensures partial failures still produce the most useful state.

## What not to do

- Don't dump checkpoint contents back into the chat. Confirm the checkpoint with one sentence ("checkpoint written: progress + 1 decision") plus the next pending step.
- Don't invoke this skill speculatively when nothing has changed since the last checkpoint. The auto-PROGRESS log already covers "something happened"; this skill is for "something *meaningful* happened."
- Don't write secrets, credentials, customer data, or anything matching the patterns in `cm-secret-hygiene` — even paraphrased. If a checkpoint entry would naturally contain sensitive data, capture the *fact* without the *value*.

## Relationship to the granular skills

This skill *delegates* to `cm-task-tracker` and `cm-memory` for the writing rules — see those skill files for entry format details and pruning behaviour. The value-add of `cm-checkpoint` is the bundling and the unambiguous trigger surface, not new write logic.

If a session needs only a TASKS.md update (e.g., ticking one box), invoking `cm-task-tracker` directly is fine — `cm-checkpoint` is the right call when the work spans multiple state files or when triggered by a harness event that doesn't specify which file is stale.
