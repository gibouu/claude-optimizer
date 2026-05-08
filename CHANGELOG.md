# Changelog

## v0.12.0 — 2026-05-08

Token-efficiency calibration (#33 / closes #32). Restores conversational feel after the v0.6.0–v0.11.0 series accumulated ~6.2 KB of skill descriptions and a per-prompt directive that fired on ~70% of natural debugging chatter. Symptom: model loops on the same fix because every retry triggers full ceremony. The architecture is unchanged; only the calibration moved.

- **R1. Tighter trigger / wider off-ramp** in `scripts/prompt_submit.sh`. Trigger regex now requires "to <verb>" or "(a|an|the) <noun>" structure, dropping casual matches like "can you check that" or "we need to debug this". Off-ramp regex catches debug-mode chatter ("still broken", "doesn't work", "didn't work", "tried this", "same issue", "again", "debug", "test it", "check the", "look at"). Estimated false-positive reduction on natural conversation: 70% → ~15%.
- **R2. Mutually exclusive directive blocks.** When the edit-count cadence and the issue-workflow trigger would both fire on the same turn, only the issue-workflow block emits. Worst-case per-prompt cost: 1,261 B → ~210 B.
- **R3. `.recent_blocks` rolling buffer.** Each gate (`pre_exit_plan.sh`, `pr_preflight.sh`, `stop.sh`) appends a one-line record to `.claude/state/.recent_blocks` (FIFO, last 3) when it blocks. `prompt_submit.sh` injects this content as additional context only when the user's prompt looks like a retry ("still", "again", "didn't work", "doesn't work", "tried", "same issue/problem"). Closes the cross-turn no-learning-loop gap that produced the "fixing same problem 5 times in a row" symptom.
- **R4. Compressed skill descriptions.** All 11 `skills/*/SKILL.md` frontmatter `description:` fields trimmed to ≤200 B each. Total dropped from ~6.2 KB → ~1.7 KB. SOP detail moved to skill bodies where it belongs.
- **R5. Single-line SessionStart banner.** Skill list and rules removed (skills already loaded via system message; rules in CLAUDE.md). New banner: `[claude-optimizer active] last state write: 2h ago | state: .claude/state/`. Saves ~400 B/session.
- **R6. PROGRESS.md auto-pruning.** When PROGRESS.md exceeds header + 100 entries (102 lines), `post_edit.sh` archives oldest entries to `.claude/state/archive/PROGRESS-YYYYMM.md` and truncates the active file. Prevents week-over-week bloat from leaking into every cm-session-resume read.
- **R7. Compressed gate stderr blocks.** Each block message in `pre_exit_plan.sh`, `pr_preflight.sh`, `stop.sh` shrunk from 660–863 B to ~220 B. Drops the redundant "hard requirement under this project's claude-optimizer plugin contract" footer (already established at session start).
- **R8. 3-deep ring-buffer cooldown.** Replaced single-fingerprint `.last_intent_fingerprint` with `.recent_fingerprints` (FIFO, last 3). If the new prompt's fp matches any of the last 3, the directive is suppressed — debug-loop sentinel that lets iterative fixes proceed without ceremony interrupting every turn.

### State surface changes

- `.last_intent_fingerprint` — removed (replaced by `.recent_fingerprints`).
- `.recent_fingerprints` — new (3-deep ring of recent prompt fingerprints).
- `.recent_blocks` — new (3-deep ring of recent gate-block records).
- `.claude/state/archive/` — new (auto-created when PROGRESS.md is pruned).

`session_end.sh` cleans up the new files alongside the existing ones.

### Tests

- 13/13 `test_prompt_submit.sh` (was 12; +1 for retry-context injection).
- 14/14 `test_pre_exit_plan.sh` (unchanged count; stderr expectations updated).
- 12/12 `test_pr_preflight.sh` (unchanged count; stderr expectations updated).

## v0.11.0 — 2026-05-08

Closes the Tier 4 polish bundle from #20's plan (last in the issue-driven-workflow series).

- **`/research <topic>` slash command (#31 / closes #26).** Wraps the cm-research-first SOP into a reusable command for moments when the user wants quick best-practices research without going through the full conversational flow. Body parses the topic from `$1`, issues 1–2 WebSearch calls with recency hints, synthesises 2–3 approaches with pros/cons + recommendation, and writes the output as an Architecture Decision Record at `docs/adr/<NNNN>-<slug>.md`. Auto-numbers from the highest existing `NNNN-*.md` (starts at `0001`).
- **ADR generator.** Built into `/research` rather than a separate hook — keeps the surface area small. Every research call captures a permanent record. Establishes a long-term decision log without manual bookkeeping.
- **Structured GitHub issue templates (`.github/ISSUE_TEMPLATE/`).** `feature_request.md` and `bug_report.md` provide the canonical sections: TL;DR · Problem/Repro · Acceptance · Out of scope · Risk · Alternatives considered. Picked up automatically by the GitHub UI; referenced in `cm-issue-driven-workflow` SKILL.md so model-driven `gh issue create` calls follow the same shape.
- **No regression.** All 38 tests across the three suites still green.

## v0.10.0 — 2026-05-08

- **PR pre-flight gate (#30 / closes #25).** New `scripts/pr_preflight.sh` PreToolUse(Bash) hook wired in `hooks/hooks.json`. Fires on every Bash command but exits silently unless the command contains `gh pr create`. For non-trivial diffs (≥ 50 lines OR ≥ 2 files vs. main), the command body must include `Closes #N` or `Refs #N` referencing a real OPEN GitHub issue. Closed or missing issue → block. Scope-bloat warning at > 300 lines / > 5 files (advisory, not blocking).
- **Diff-size detection.** Uses `git diff --shortstat <main-branch>...HEAD` to count insertions and changed files. Auto-detects the main branch name via `origin/HEAD`; defaults to `main` if that fails.
- **Bypasses.** `PR_PREFLIGHT_OFF=1` env (one-off), `.claude/optimizer-disabled` (whole plugin), trivial-diff bypass below the threshold.
- **Test escape hatches** (documented; not for production): `PR_PREFLIGHT_TEST_LINES`, `PR_PREFLIGHT_TEST_FILES` override the diff measurement; `PR_PREFLIGHT_ISSUE_STATES="20:OPEN,42:CLOSED"` mocks issue states without calling `gh`.
- **New test harness.** `tests/test_pr_preflight.sh` with 12 cases: open-issue allows, no-closes blocks, closed-issue blocks, missing-issue blocks, trivial-diff allows, refs-partial-close allows, non-gh command passes through, gh-issue-list (different subcommand) passes through, env bypass, plugin-disabled bypass, scope-bloat warning, multiple-closes one-closed blocks. No regression in `test_prompt_submit.sh` (12) or `test_pre_exit_plan.sh` (14).

## v0.9.0 — 2026-05-08

- **`cm-decompose` skill + `/decompose-plan` slash command (#29 / closes #24).** Bridges Plan-mode → backlog. After a plan is approved, the skill nudges the model to suggest decomposition when the plan has ≥2 discrete deliverables (`## Tier N`, `## N.`, "Deliverables" / "Phases" / "Issues" / "Out of scope" sections). The slash command parses the plan, drafts an umbrella issue + sub-issues with `Refs #<umbrella>` cross-references, asks the user to confirm, then runs `gh issue create` for each. Umbrella body has a `- [ ] #<sub>: <title>` checklist that auto-ticks as sub-PRs merge via `Closes #<sub>`. Reflects the user's stated workflow: "create a list of issues to be able to fix them one by one... break it down in smaller bite-size products."
- **No hook gate.** Auto-creating GitHub issues from a hook would be too aggressive; the slash command is purely user-invoked. The skill description gets the model to suggest it at the right moment.
- **Session banner.** `cm-decompose` added to the SessionStart skills list.
- **No regression.** `tests/test_prompt_submit.sh` (12 cases) and `tests/test_pre_exit_plan.sh` (14 cases) still green.

## v0.8.0 — 2026-05-08

- **`cm-multi-plan` skill + alternatives gate (#28 / closes #23).** Required for moderate or complex tasks: the plan file must include an "Alternatives" / "Tradeoffs" / "Decisions" / etc. section listing 2–3 distinct approaches with explicit pros/cons before settling on a recommendation. Mirrors the user's stated workflow: "show me two or three plans... we could pick and choose."
- **`pre_exit_plan.sh` extended with a second check.** The PreToolUse(ExitPlanMode) gate now runs both `cm-research-first` and `cm-multi-plan` checks in sequence. Multi-plan looks at the most recently modified plan file under `~/.claude/plans/` (within the last hour) and greps for any canonical heading: `alternatives`, `options`, `approaches`, `tradeoffs`, `decisions`, `considered`, `comparison` (case-insensitive, anywhere on a `^#{1,3}` line — so compound headings like "## Design decisions" satisfy the gate).
- **Bypasses.** `MULTI_PLAN_OFF=1` env for one-off bypass; trivial plans (under 30 lines) auto-bypass; simple-complexity prompts skip enforcement; `.claude/optimizer-disabled` disables both checks.
- **Test harness extended.** `tests/test_pre_exit_plan.sh` now covers 14 cases (was 7) — adds 7 new fixtures for the multi-plan check (block on no-alternatives at moderate and complex, allow with `## Alternatives`, allow with `## Design decisions`, simple-complexity bypass, trivial-plan bypass, env bypass). Test runner now isolates `$HOME` per case so the gate's `~/.claude/plans/` lookup hits a sandbox.
- **Session banner.** `cm-multi-plan` added to the SessionStart skills list.

## v0.7.0 — 2026-05-08

- **`cm-research-first` skill + hook-enforced gate (#27 / closes #22).** Required before invoking ExitPlanMode on a complex task: a quick WebSearch on current best practices. The skill's frontmatter description triggers when the previous turn's directive contained `[complexity: complex]`, instructing Claude to issue 1–2 WebSearch calls (problem framing + recency hint) and cite findings in the plan.
- **PreToolUse(ExitPlanMode) gate (`scripts/pre_exit_plan.sh`).** Reads `$STATE_DIR/.last_prompt_complexity` and `$STATE_DIR/.websearch_this_turn`. If complexity is `complex` and no WebSearch was performed during the current turn, blocks the call with exit 2 and a stderr message naming the rule and bypasses (`RESEARCH_FIRST_OFF=1`, `.claude/optimizer-disabled`).
- **PostToolUse(WebSearch) marker (`scripts/post_websearch.sh`).** Touches `.websearch_this_turn` so the gate can tell whether research was performed in the current turn. The marker is cleared at the start of every UserPromptSubmit (so each new turn re-arms the gate).
- **`prompt_submit.sh` persists `[complexity]`.** The classifier output is now written to `.last_prompt_complexity` on every triggered prompt; cleared on off-ramp / non-trigger paths so the gate doesn't enforce on precise instructions. Sticky across cooldown matches.
- **`hooks/hooks.json`.** New PreToolUse(matcher: `ExitPlanMode`) entry. New PostToolUse entry for matcher `WebSearch` alongside the existing `Write|Edit|MultiEdit` entry.
- **Session banner.** `cm-research-first` added to the SessionStart skills list.
- **Cleanup.** `session_end.sh` removes `.last_prompt_complexity` and `.websearch_this_turn` between sessions.
- **New test harness.** `tests/test_pre_exit_plan.sh` covers 7 cases: complex+no-websearch blocks; complex+websearch allows; moderate/simple/no-tag allow; `.claude/optimizer-disabled` and `RESEARCH_FIRST_OFF=1` bypasses. The existing `tests/test_prompt_submit.sh` (12 cases) continues to pass — no regression.

## v0.6.0 — 2026-05-08

- **Hook-enforced `cm-issue-driven-workflow` (#21 / closes #20).** `prompt_submit.sh` now inspects the user's prompt (jq + sed fallback for stdin JSON) and injects a directive when it detects conversational request phrasing. Off-ramp regex (precise file:line, "just X", "quick fix", direct rename/delete imperatives, "skip the issue") suppresses the directive on precise instructions. Heuristic complexity classifier rides `[complexity: simple|moderate|complex]` into the directive based on prompt length, keyword density, and file mentions. SHA-1 fingerprint cooldown via `.last_intent_fingerprint` prevents repeat-firing on identical prompts; cleared by `session_end.sh`. Promotes the SOP from model-judgment invocation to hook-level enforcement, mirroring the pattern of the existing edit-count state-checkpoint directive. Both blocks concatenate naturally when they fire on the same prompt.
- **First test harness (`tests/test_prompt_submit.sh`).** Hand-rolled bash runner over fixture directories — no BATS dependency. Twelve cases cover trigger phrases (basic / complex / simple), four off-ramps (just, quick fix, file:line, skip), cooldown repeat/re-arm, concurrent state-checkpoint emission, no-jq fallback, and empty stdin. Documented in the new `CONTRIBUTING.md` as the verification command.

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
