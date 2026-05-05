# Issue — claude-optimizer is theater: state files don't get written

**Filed:** 2026-05-05
**Severity:** High — the plugin's headline value (continuity, memory, discipline) does not actually accrue in practice.

---

## TL;DR

The plugin advertises itself as an optimizer that maintains `MEMORY.md`, `DECISIONS.md`, `PROGRESS.md`, and `TASKS.md` to give Claude continuity across sessions. In practice, **across every repo and session**, those files stay empty or near-empty because Claude rarely invokes the `cm-*` skills mid-session. The plugin's hooks only *print reminders* — they do no writing. As a result, the user pays the install cost (banner noise, hook latency, skills cluttering the skill list) and gets none of the promised continuity.

This is not a bug in any one script. It is a **design gap**: the contract says "Claude will keep state for you" but nothing actually enforces that contract.

---

## Symptom (user-reported, reproducible)

Across multiple repos and sessions:

- `.claude/state/MEMORY.md`, `DECISIONS.md`, `PROGRESS.md`, `TASKS.md` contain only their seed headers from `init_state.sh`. No entries are appended, even after long, complex sessions involving multi-step refactors, decisions, and bug fixes.
- The user expected the plugin to "do the work of optimizing" — i.e., maintain these files automatically. It does not.
- Concrete example session (2026-05-05, `coleaseum-onepager` repo): a multi-turn rebrand task involving 5+ edits to `index.html`, a new `CLAUDE.md`, `.gitignore` update, two commits, a push, and several decisions (which domain to lead with, which sections to keep, removing carousel JS). After all of that, every state file was still in its seed state.

---

## What the plugin actually does

I traced every hook script and skill definition. Here is the ground truth:

### Hooks (`hooks/hooks.json` → `scripts/*.sh`)

| Hook | Script | Behavior |
|---|---|---|
| `SessionStart` | `session_start.sh` | Calls `init_state.sh` to seed empty files; prints the "[claude-optimizer active]" banner with the rule list. **Writes nothing to state.** |
| `UserPromptSubmit` | `prompt_submit.sh` | **No-op placeholder.** Comment says "Reserved for future redaction / prompt-shaping logic." |
| `PostToolUse` (Write/Edit/MultiEdit) | `post_edit.sh` | Runs secret scan, increments an `.edit_count` file. Every 10 edits prints to stderr: *"X edits this session — append to PROGRESS.md and tick TASKS.md before continuing."* **Writes nothing to state files themselves.** |
| `Stop` | `stop.sh` | If `git diff` is dirty, prints to stderr: *"Uncommitted changes present. Apply cm-quality-gate before declaring done."* **Does not block.** Exits 0. |
| `SessionEnd` | `session_end.sh` | Deletes `.edit_count`. Cleanup only. |

### Skills (`skills/cm-*/SKILL.md`)

These are **definitions**, not behavior. Claude has to choose to invoke them via the `Skill` tool. The descriptions tell Claude *when* to invoke (e.g., `cm-task-tracker`: "use whenever the user describes a multi-step task"), but invocation is at the model's discretion.

### Net effect

The plugin produces:
- One stderr banner at session start.
- One stderr nudge every 10 edits.
- One stderr nudge on Stop if git is dirty.
- A populated `.claude/state/` skeleton.

It does **not** produce:
- Any content in state files.
- Any forced behavior change in Claude.
- Any blocking gate.

---

## Why this fails in practice

The plugin's effectiveness rests on a single load-bearing assumption: **"Claude will reliably notice the trigger conditions in each `cm-*` skill description and invoke the corresponding skill."**

That assumption is wrong, and predictably so, for these reasons:

### 1. Skills compete with dozens of other skills

In a typical session the model sees 30–60 skills listed in the available-skills reminder (`vercel:*`, `supabase:*`, `superpowers:*`, plus the six `cm-*`). The `cm-*` triggers are general ("multi-step task", "non-obvious bug fix") and overlap with other process skills (`superpowers:writing-plans`, `superpowers:executing-plans`, etc.). When the model picks one process skill, it usually doesn't *also* pick a memory-writing skill — there's no notion of "always-on alongside whatever else."

### 2. The triggers are too vague to fire reliably

`cm-memory` says to write "when finishing a unit of work." What is a unit of work? A commit? A task in TASKS.md? A user turn? A whole session? In a flowing back-and-forth conversation, no single moment feels like *the* moment. The result is that the trigger is rarely satisfied with high confidence, so the skill is rarely invoked.

`cm-task-tracker` is slightly better ("more than three turns"), but the model defaults to the built-in `TaskCreate`/in-context plan instead of writing a markdown ledger. In this very session, after multiple system reminders to use `TaskCreate`, I still didn't open `cm-task-tracker`.

### 3. stderr reminders are low-priority context

The "10 edits" reminder and the Stop reminder land as text the model can choose to read or ignore. They compete with the user's actual prompt for attention. In long sessions with high context pressure, they get triaged out — exactly when you most need them to fire.

### 4. The `Stop` hook fires too late and too softly

By the time `Stop` runs, the model has already decided what to say and is committing the turn. A stderr message at that point is a regret, not a checkpoint. And because the script exits 0, nothing actually pauses or rewinds.

### 5. The plugin solves the wrong problem

The plugin's framing is "Claude has no memory between sessions, so we'll give it one." But the actual failure mode is "Claude has the *capability* to write memory and routinely chooses not to." Adding a file-based persistence layer doesn't address that — it just makes the choice-not-to-write more visible.

### 6. The "discipline" framing punts the work to the model

`cm-token-discipline` is illustrative: it tells the model not to ramble, not to re-read files, etc. These are real wins *if obeyed*, but they require the model to remember to apply them on every turn. Hooks could enforce some of this (e.g., reject `Read` on a file already read this turn) — they don't.

---

## Evidence from this session (verbatim)

- **Hooks fired correctly.** The SessionStart banner appeared. `init_state.sh` ran and seeded the files.
- **`post_edit.sh` printed three "task tools haven't been used recently" reminders** during this session (these are visible as `<system-reminder>` blocks in the trace). Each one I noted but did not action.
- **Skills invoked: zero `cm-*` skills.** Across the entire session — file edits, decisions, two commits, one push — I did not call `cm-memory`, `cm-task-tracker`, `cm-quality-gate`, `cm-session-resume`, `cm-token-discipline`, or `cm-secret-hygiene` even once.
- **State files at session end:** identical to their seeded state from `init_state.sh`. Header lines only.
- **What *should* have been written, if the contract were enforced:**
  - `DECISIONS.md`: `[2026-05-05] branding: Coleaseum → Colet, primary domain colet.ai. Why: rebuild from scratch, sharper focus.`
  - `PROGRESS.md`: `[2026-05-05] rebrand shipped to main (commits 9aedd08, 6466a3c, 348153e); .claude/ gitignored.`
  - `MEMORY.md`: `static GH-Pages site; no build step; SCSS compiles manual; main_free.css is the live stylesheet.`
  - `TASKS.md`: a DONE entry for the rebrand task.

None of those were written. The next session in this repo will start from zero.

---

## Fix options, ranked by impact ÷ effort

### Tier 1 — actually solve it

**(A) PromptSubmit hook injects an enforced state-write directive every N turns.**
Replace the no-op `prompt_submit.sh` with a script that:
1. Reads the current `.edit_count`.
2. If `count % 5 == 0` (or files are stale by mtime), prepends an *additional output* to stdout that the harness will surface as a high-priority system message: `"BEFORE responding to this prompt, invoke cm-task-tracker to update TASKS.md with current state. This is a hard requirement."`
3. The model treats `additionalContext` from `UserPromptSubmit` hooks as inline instructions — much harder to ignore than stderr noise.

This is the single highest-leverage change. It moves enforcement from "model discipline" to "harness instruction."

**(B) `Stop` hook becomes a real gate.**
Change `stop.sh` to `exit 2` (block) when:
- `git diff` is dirty AND
- `PROGRESS.md` mtime is older than the most recent edited file.

The blocking exit forces the model to either run the gate, write to state, or explicitly handle the failure. Today the same script just nags. The cost is one extra turn occasionally; the gain is the contract being enforceable.

**(C) `PostToolUse` writes a one-line edit log itself.**
The hook already runs after every Write/Edit/MultiEdit and has access to the tool input. It can append a single line to `PROGRESS.md` automatically:

```
[2026-05-05 14:22] edit: index.html (+39/-67)
```

Not as good as a human-meaningful "what changed and why," but infinitely better than silence, and it removes the "files are still empty" symptom immediately. The model can then *enrich* those auto-entries via `cm-memory` instead of bootstrapping from blank.

### Tier 2 — improve the model's odds of doing the right thing

**(D) Tighten skill descriptions to single-fire triggers.**
`cm-memory`'s "when finishing a unit of work" is too vague. Replace with concrete, machine-detectable triggers:
- "After every successful `git commit` in this session." (Detectable; commits are observable events.)
- "After the user says 'done', 'ship it', 'looks good', 'push it', or similar."
- "Before any `git push`."

Adding three or four narrow, observable triggers gives the model unambiguous moments to act, instead of one fuzzy moment that's easy to defer forever.

**(E) Add a `cm-checkpoint` skill that bundles the writes.**
A single skill that, when invoked, atomically reads context and writes to all four files. The model is more likely to invoke one obvious "save progress" skill than to remember to invoke three separate ones at slightly different moments. Wire it to the same triggers in (D).

**(F) Surface a hard counter in the SessionStart banner.**
Show `Last write to state: N edits ago / N hours ago` in the banner. If the number is large, the model will see the gap and self-correct. Today the banner is decorative.

### Tier 3 — strategic / positioning

**(G) Drop the "optimizer" framing if you can't enforce it.**
If Tier 1 fixes are out of scope, rename the plugin to `claude-discipline-skills` or similar — a *library* of skills the user invokes deliberately, not a system that runs in the background. The current framing ("active", "optimizer", autopopulating state) sets an expectation the implementation can't meet, which is what produced this report.

**(H) Add a self-test command.**
Ship a `/optimizer-audit` slash command that:
- Counts skill invocations vs edits vs commits this session.
- Reports *"You've done 14 edits and 2 commits. cm-* skills invoked: 0. State writes: 0. Compliance: 0%."*
- This makes the failure visible in real time, not just at session-end retrospect.

---

## Recommended path

If you do one thing, do **(A)** — PromptSubmit injection of a hard directive when state is stale. It is ~30 lines of bash and it converts the plugin from advisory to enforced.

If you do two things, add **(C)** — auto-append one line per edit to `PROGRESS.md`. This eliminates the "files are empty" symptom on day one, regardless of model discipline.

If you do three, add **(D)** — rewrite the skill descriptions with concrete, observable triggers (post-commit, pre-push, on user "done"). This costs nothing and the cumulative effect over a year of sessions is large.

Tier 2/3 items are genuine improvements but optional. The Tier 1 items address the actual root cause: **enforcement currently depends on the model, and the model is exactly the wrong place to put it.**

---

## What I'd want to verify before closing the issue

A clear acceptance test for the fix:

1. Run a 30-edit session in a fresh repo with no manual prompting about state.
2. At session end, `.claude/state/PROGRESS.md` should have ≥10 entries, `TASKS.md` should reflect actual work, and `DECISIONS.md` should capture any branching choices.
3. If the user says "are we done" with uncommitted changes, the model must be physically unable to say "yes" without either committing or invoking `cm-quality-gate`.

Until those three are true, the plugin's stated value isn't being delivered.
