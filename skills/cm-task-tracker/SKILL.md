---
name: cm-task-tracker
description: Use this skill whenever the user describes a multi-step task, a feature, a refactor, or anything that will take more than three turns. Maintains an explicit task ledger in .claude/state/TASKS.md so context drift cannot lose work. Also use when resuming, when blocked, and before declaring something done.
---

# Task Tracker

Twenty messages into a session, Claude often forgets what step 2 was. This skill prevents that by externalising the plan to disk.

## The ledger

`.claude/state/TASKS.md`. One section per task. Keep it short.

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

## When to create an entry

The moment the user describes work that has more than one obvious sub-step. Don't ask permission. Create it, then start step 1.

## Discipline

- Update status the moment it changes — not at the end of the session.
- Tick boxes as steps complete. Do not retroactively reconstruct the list.
- If a step reveals a new sub-task, add it under the parent. Don't silently expand the original step.
- If you're about to start something not in the steps list, **stop and ask** whether to add it or whether the user wants the original task finished first. This is the single most important rule for staying focused.

## Done means done

A task is `DONE` when:
- All steps are checked
- Tests pass (or there are none and the user has confirmed that's fine)
- The change is committed or explicitly handed back to the user

Not before. "I think it's done" is `IN_PROGRESS` with a note.

## Resuming

On session start, if `TASKS.md` has an `IN_PROGRESS` entry, read it, surface a one-line resume offer, and pick up at the next unchecked step. Do not re-plan from scratch.

## Pruning

When a task hits `DONE`, leave it for one session, then move to `.claude/state/archive/TASKS-<YYYY-MM>.md`. Keeps the active ledger short.
