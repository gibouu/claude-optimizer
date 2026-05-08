# Changelog

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
