---
description: Decompose the most recent Plan-mode plan file into a GitHub umbrella issue + sub-issues with crossreferences. Reads ~/.claude/plans/, parses discrete deliverables, asks the user to confirm, then runs gh issue create for each.
---

Apply the `cm-decompose` skill.

## 1. Locate the plan file

If the user passed a path argument, use that. Otherwise find the most recently modified `*.md` under `~/.claude/plans/`. If none exists or the file's mtime is more than an hour old, reply with "no recent plan found under ~/.claude/plans/ — pass a path explicitly: `/decompose-plan path/to/plan.md`" and stop.

## 2. Parse for discrete deliverables

Read the plan file. Look for these structural signals (any one is sufficient — pick the most prominent):

- `## Tier N` headings (e.g. "## Tier 1", "## Tier 2"…)
- Top-level `## N.` numbered sections (e.g. "## 1.", "## 2.")
- A `## Deliverables`, `## Phases`, `## Issues`, or `## Milestones` section with ≥2 bulleted/numbered items
- A `## Out of scope` / `## Follow-ups` section listing future tickets
- Multiple `### Issue N` markers

Extract: each deliverable's one-line title (under 70 chars), and a 2–3 sentence description pulled from the section body. Strip markdown formatting from the title.

If fewer than 2 deliverables found, reply with "plan has only one deliverable; decomposition not needed — proceed with a single issue/PR via cm-issue-driven-workflow" and stop.

## 3. Verify GitHub remote

Run `gh repo view --json owner,name -q '.owner.login + "/" + .name'`. If the command errors, reply with "no GitHub remote configured — decomposition skipped" and stop.

## 4. Propose the decomposition

Show the user a compact preview:

```
Umbrella: <umbrella title>
  - <sub 1 title>
  - <sub 2 title>
  - …
```

The umbrella title should be a concise framing of the overall plan (e.g. "Hook-enforced workflow series" rather than the plan's own filename).

Ask exactly: **"File these N+1 issues (1 umbrella + N sub-issues)? [yes/no]"**

If the user says no or anything other than yes, drop the proposal without filing.

## 5. File the issues

If the user confirms:

1. Run `gh issue create --title "<umbrella title>" --body "<umbrella body>"` first. The body should contain a placeholder checklist:

   ```
   ## Sub-issues

   - [ ] <sub 1 title>
   - [ ] <sub 2 title>
   - …

   ## Plan reference

   Decomposed from `~/.claude/plans/<plan-filename>.md` via `/decompose-plan`.

   — Claude + gib
   ```

2. Capture the umbrella issue number from the returned URL.

3. For each sub-issue, run:

   ```
   gh issue create --title "<sub title>" --body "<sub body>"
   ```

   Where `<sub body>` includes:

   ```
   <2-3 sentence description from the plan>

   Refs #<umbrella>

   — Claude + gib
   ```

4. After all sub-issues are filed, edit the umbrella body to replace the placeholder checklist with real `#<N>` references:

   ```
   gh issue edit <umbrella> --body "<updated body>"
   ```

   Updated checklist format: `- [ ] #<sub_N>: <sub title>`.

## 6. Confirm

Reply with:

```
Filed:
- umbrella #<U>: <umbrella title>
- subs: #<S1>, #<S2>, …
```

Then suggest the next step: "Branch off main for #<S1> with `git checkout -b feat/<S1>-<slug>` and start there. The umbrella tracks progress automatically as sub-PRs merge."

## Edge cases

- If `gh issue create` fails (network, auth, etc.), report the failure and stop. Do NOT continue filing — partial filing leaves the user with orphan issues.
- If the user passes a path argument that doesn't exist, report "no plan file at <path>" and stop.
- If the plan has more than 8 deliverables, ask the user to confirm — that's a lot of issues, and the decomposition is probably too fine-grained.
