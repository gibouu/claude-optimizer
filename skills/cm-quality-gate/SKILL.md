---
name: cm-quality-gate
description: Use before any `git commit`, before any `git push`, before any `gh pr create`, before marking a TASKS.md entry as DONE, and before the literal word "done" appears in a response to the user. Runs the project's actual test/lint/typecheck/build commands and refuses to mark work done if any fail. Also use when the user asks "is this ready" or "are we done", and before handing control back to the user after a batch of edits.
---

# Quality Gate

The single biggest source of regret in long sessions is "I think it works" turning into "it doesn't compile". This skill makes the check explicit and non-skippable.

## The gate

Before a task is marked `DONE` in `TASKS.md` or before saying the word "done" in chat, run **all** of the following that apply to the project:

| Check | Trigger |
|---|---|
| Type check | `tsconfig.json`, `pyrightconfig.json`, `mypy.ini`, or similar present |
| Lint | `eslint`, `ruff`, `golangci-lint`, etc. configured |
| Tests | A test runner is configured and the changed files have tests |
| Build | A `build` script exists in `package.json`/`Makefile`/etc. |

The exact commands live in `.claude/state/CHECKS.md` if it exists; otherwise infer from the project. If you infer, write what you ran into `CHECKS.md` so the next session doesn't have to re-infer.

## Failures

If any check fails:
1. Do **not** say "done".
2. Update the task status to `IN_PROGRESS` with a note: `quality gate failed: <which check>`.
3. Fix the failure. Don't suppress, comment out, or skip the failing test or rule unless the user explicitly approves.
4. Re-run the full gate. Partial re-runs hide regressions in unrelated checks.

## When the user wants to skip

If the user says "just ship it" or "don't run the tests", honour it but record one line in `DECISIONS.md`:
`[YYYY-MM-DD] gate-skip: skipped <check> per user request on <task>`.

## Edge cases

- **No tests exist for the changed code.** Run the broader suite anyway. Surface the coverage gap as a one-line note, don't lecture.
- **Tests pass but linter fails on unrelated files.** Do not auto-fix unrelated files. Mention the pre-existing issue once and move on.
- **Long-running test suites.** Run only the affected test files first; full suite at the end of the session.

## What this is not

This is not a CI replacement and not a "fix every warning" mandate. It's a refusal to lie about completion.
