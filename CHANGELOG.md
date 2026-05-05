# Changelog

## v0.5.0 — 2026-05-05

- **`cm-issue-driven-workflow` skill (#18 / closes #17).** Codifies the user's preferred development flow as an auto-invoking skill: refine via brainstorming → file GitHub issue → branch → fix → test → PR with `Closes #<N>` → self-review → merge --squash --delete-branch → pull main. Triggers on conversational problem-language ("I want to…", "we should…", "this is broken", etc.) and includes explicit off-ramps for trivial work (precise file:line instructions, "just X", ≤10-line single-file changes, no GitHub remote). Plugin is always-on across repos, so this becomes a portable SOP without per-project setup. Banner Skills line updated.

## v0.4.0 — 2026-05-05

Closes the Tier 2/3 follow-ups from #1.

- **Bundled `cm-checkpoint` skill (#13 / #1 option E).** Single auto-invoking skill that atomically writes to PROGRESS / DECISIONS / TASKS / MEMORY in one pass. Removes the "which-skill-now" ambiguity that suppressed cm-* invocations. PromptSubmit and Stop messages now name `cm-checkpoint` as the primary action with the granular skills as alternatives.
- **SessionStart "last meaningful state write" counter (#14 / #1 option F).** Banner now surfaces the youngest mtime among TASKS / DECISIONS / MEMORY beyond their init seed, formatted as "just now" / "N minutes ago" / "N hours ago" / "N days ago" / "never". `cm-checkpoint` added to the banner's Skills line. PROGRESS deliberately excluded from the freshness check (it's auto-touched on every edit).
- **`/optimizer-audit` slash command (#15 / #1 option H).** Read-only compliance dashboard: edits, commits, state-file touches, harness firings, derived compliance percentage. Backed by `scripts/optimizer_audit.sh`; cross-platform (BSD/GNU stat + date).

## v0.3.0 — 2026-05-05

Closes the "plugin is theater" gap reported in #1: state files now actually accrue, the harness enforces the contract, and skill triggers are observable events rather than fuzzy moments.

- **Auto-progress logging (#2 / #1 option C).** `post_edit.sh` parses the PostToolUse payload and inserts a one-line `[YYYY-MM-DD HH:MM] tool: path` entry at the top of `PROGRESS.md` after every Write/Edit/MultiEdit. Eliminates the "state files stay empty" symptom without depending on model discipline.
- **PromptSubmit directive injection (#6 / #1 option A).** `prompt_submit.sh` is no longer a no-op. Every 5 edits, the next user prompt receives an additional-context block instructing Claude to invoke `cm-task-tracker` and `cm-memory` before responding. UserPromptSubmit stdout is surfaced as inline context — much harder to ignore than stderr nags.
- **Stop hook is a real gate (#7 / #1 option B).** `stop.sh` now exits 2 (blocks) when the working tree is dirty, edit count ≥ 5, and no model-driven state file has been touched since session start. Loop guard prevents repeat-blocking at the same edit count; mid-rebase / mid-merge / mid-cherry-pick states skip the gate; per-project opt-out remains.
- **Concrete observable cm-* triggers (#8 / #1 option D).** All six `cm-*` skill descriptions now lead with deterministic events (post-`git commit`, pre-`git push`, pre-`gh pr create`, completion phrases, decision phrases, hook events) instead of fuzzy ones. Each skill lists ≥3 concrete triggers; existing fuzzy guidance is preserved as fallback.
- **Plumbing.** `session_start.sh` writes `.session_start_marker` for the Stop gate's freshness check; `session_end.sh` cleans up `.session_start_marker`, `.last_directive_count`, and `.last_stop_block_count` alongside `.edit_count`.

## v0.2.1 — 2026-04-30

- Register repo as a plugin marketplace (`.claude-plugin/marketplace.json`) so `/plugin marketplace add` and `/plugin install` work end-to-end.

## v0.2.0 — 2026-04-30

- Per-project opt-out flag (`.claude/optimizer-disabled`)
- `install_to_project.sh` helper for the gitignore snippet

## v0.1.0 — 2026-04-30

- Initial release
