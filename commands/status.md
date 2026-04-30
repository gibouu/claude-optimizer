---
description: Show current optimizer state — open tasks, last 5 decisions, last 5 progress entries.
---

Read these files and print a compact dashboard. Do not dump full contents.

1. `.claude/state/TASKS.md` — show only `IN_PROGRESS` and `BLOCKED` sections.
2. `.claude/state/DECISIONS.md` — show last 5 lines.
3. `.claude/state/PROGRESS.md` — show last 5 lines.

Output format:

```
ACTIVE
- <task>: <next unchecked step>
BLOCKED
- <task>: <reason>
RECENT DECISIONS
- <line>
RECENT PROGRESS
- <line>
```

If a section is empty, omit it.
