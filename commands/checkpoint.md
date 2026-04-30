---
description: Force a memory checkpoint — append progress, update task statuses, log any new decisions, before context gets crowded.
---

Apply the `cm-memory` and `cm-task-tracker` skills now.

1. For each `IN_PROGRESS` task in `.claude/state/TASKS.md`, tick any newly-completed steps and add any new sub-steps discovered this turn.
2. Append one line to `.claude/state/PROGRESS.md` summarising what happened since the last entry. Newest first.
3. If any architectural decision was made this turn (library choice, pattern, tradeoff), append one line to `.claude/state/DECISIONS.md`.
4. Reply with one sentence confirming the checkpoint, plus the next pending step. Do not dump file contents.
