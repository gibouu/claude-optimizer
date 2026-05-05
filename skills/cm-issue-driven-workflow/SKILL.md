---
name: cm-issue-driven-workflow
description: Use whenever the user describes a problem, idea, feature, or fix in conversational language without giving a precise file:line instruction. Concrete trigger phrases include "I want to…", "we should…", "let's add", "we need", "how do I…", "why doesn't…", "can you…", "this is broken/annoying/slow", "feature request", or any restating of a desired capability or pain point. Also use when the user references "the proper way" or "standard practice" for handling work. Refines the request via brainstorming, files a GitHub issue, branches, fixes, opens a PR with `Closes #N`, self-reviews, and merges — the user's standing operating procedure for non-trivial work across all repos.
---

# Issue-Driven Workflow (SOP)

This is the user's preferred development flow for non-trivial work. It eliminates the need to re-explain "do it the proper way" on every new repo. The plugin is always on; this skill applies in every project where it ships.

## When to fire

The frontmatter `description:` is the contract. In short: **fire when the user describes a problem in chat without a precise code instruction.**

Examples that fire:
- "I want to add a dark mode toggle."
- "We should refactor the auth middleware."
- "This pagination component is broken."
- "Why doesn't the cache invalidate?"
- "Can you make the dashboard load faster?"

Examples that **don't** fire (use the off-ramps below):
- "Rename `foo` to `bar` in `x.ts:42`." (precise instruction)
- "Just fix this typo." (explicit "just")
- "Quick fix: change line 14 to use `===`." (explicit "quick fix")
- "Skip the issue, just push it." (explicit override)

## Off-ramps — when to skip the workflow

Do the edit directly, commit if the user wants, and move on. **Do not** invoke this skill when:

- The user says "just X" / "quick fix" / "small thing" / "skip the issue" / "no PR needed".
- The user gives a precise file:line instruction.
- The change is ≤10 lines, confined to a single file, and reversible.
- No GitHub remote configured, or `gh` CLI not available, or repo isn't a git repo.
- The user is asking a question that doesn't imply a change (explaining code, debugging without a fix, planning).

When skipping, *say so once* — "I'll do this directly without the issue/PR ceremony since it's a small fix" — so the user knows the workflow was considered and bypassed deliberately.

## The 9-step SOP

For non-trivial work that doesn't hit an off-ramp:

### 1. Refine the request
Invoke `superpowers:brainstorming` (or its substitute) to ask 1-2 sharp clarifying questions. Restate the problem in user-confirmable form. **Don't write code yet.** Get explicit user confirmation before proceeding.

### 2. File the GitHub issue
```
gh issue create --title "<short imperative>" --body "<repro + acceptance>"
```
- Title: under 70 characters, sentence form.
- Body sections: TL;DR, repro / current behaviour, acceptance criteria. Skip sections that don't apply for small features.
- Capture the issue number from the returned URL.

### 3. Branch off `main`
```
git checkout main
git pull
git checkout -b feat/<N>-<slug>          # for features
git checkout -b fix/<N>-<slug>           # for bug fixes
git checkout -b chore/<N>-<slug>         # for non-functional work
```
Branch name references the issue number so PRs are traceable.

### 4. Fix
Implement the change. While doing so, honour the project's other auto-active skills:
- `cm-token-discipline` — terse responses, no preamble/postamble.
- `cm-secret-hygiene` — never read or write sensitive files / values.
- `cm-checkpoint` — write meaningful state entries when crossing milestones.

For multi-step features, use `cm-task-tracker` to keep `TASKS.md` current.

### 5. Test
Run real verification before claiming done — see `cm-quality-gate`. The literal word "done" should not appear in your response without evidence (tests passed, manual exercise succeeded, output verified).

### 6. Open the PR
```
git push -u origin <branch>
gh pr create --title "<title>" --body "<body containing 'Closes #<N>'>"
```
- `Closes #<N>` auto-closes the issue when the PR merges.
- `Refs #<N>` if the PR partially addresses the issue — the issue stays open for the remaining scope.
- PR description must include a brief Test Plan checklist.

### 7. Self-review
Open the PR in the GitHub UI (or `gh pr view <N> --web`) and read the diff. The browser surfaces things `git diff` in the terminal misses (line wrapping, file structure, missing files).

### 8. Merge
```
gh pr merge <N> --squash --delete-branch
```
Use `--squash` unless the project's PR template specifies otherwise. `--delete-branch` keeps the remote tidy.

### 9. Pull main and resume
```
git checkout main
git pull
```
Now the next task can branch from a clean updated `main`.

## Filing follow-up issues

If during the work you identify out-of-scope items ("we should also fix Y", "this exposes a related bug Z"), **file each as its own GitHub issue immediately** rather than only listing them in the PR description. Reference the parent issue in the new issues. This keeps the backlog actionable and matches the user's stated preference for "keep moving forward."

## What this skill is not

- This is **not** a replacement for `superpowers:brainstorming`, `cm-checkpoint`, or `cm-quality-gate`. It orchestrates them.
- This is **not** for one-off tasks the user explicitly framed as quick. The off-ramps exist precisely to keep the workflow from becoming bureaucratic theatre.
- This is **not** for repos without a GitHub remote. The skill degrades gracefully — if `gh` can't reach a remote, fall back to local branch + commit, and tell the user the issue/PR steps were skipped.

## Failure modes and recovery

- **Branch protection blocks direct push to `main`:** good — that's the user's setup. Always branch first.
- **PR fails CI:** treat as a quality-gate failure (see `cm-quality-gate`). Fix on the same branch with a new commit, push, let CI re-run. Don't merge red.
- **User changes the requirements mid-flow:** stop, restate the new shape, ask whether to update the existing issue or close it and open a new one. Don't silently expand scope.
- **Issue already exists for this work:** find it (`gh issue list --search`), reference it instead of filing a duplicate. The branch and PR still proceed normally with `Closes #<existing>`.
