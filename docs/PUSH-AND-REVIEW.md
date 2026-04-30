# Push to GitHub from Claude Code

You don't need to upload anything from this conversation. Download the zip, unzip it, and have Claude Code in your terminal handle the rest.

## One-time prerequisites

```bash
# macOS
brew install gh
gh auth login        # follow the prompts, pick HTTPS, log in via browser

# Linux (Debian/Ubuntu)
sudo apt install gh
gh auth login
```

You only do this once per machine.

## In Claude Code, paste this prompt

Open Claude Code in any directory (it doesn't matter where), then ask:

> I have a folder at `~/Downloads/claude-optimizer` containing a Claude Code plugin I built.
>
> Please:
> 1. `cd` into it
> 2. Initialise a git repo
> 3. Run `git status` and confirm `.gitignore` is doing its job (no `.claude/state/` dirs, no `.edit_count`, no `archive/`)
> 4. Make the initial commit with message `initial commit: claude-optimizer v0.1.0`
> 5. Use `gh repo create claude-optimizer --public --source=. --push` to create the GitHub repo and push
> 6. Confirm by printing the URL of the new repo
>
> Do not push anything until I see the output of `git status` and approve.

The `--public` flag is what you want for a marketplace-installable plugin. If you want it private at first, swap to `--private` and push it public later.

## After it's pushed, install it from any project

```
/plugin marketplace add <your-github-username>/claude-optimizer
/plugin install claude-optimizer@claude-optimizer
```

That's the whole loop.

## How to update it later

Two patterns, depending on the size of the change:

**Small change** (a typo, one new pattern in `scan_secrets.sh`, a tweak to a skill):
```bash
cd ~/Downloads/claude-optimizer
# edit
git add -A && git commit -m "<one-line description>"
git push
```
Users running the plugin pick it up next time their Claude Code refreshes the marketplace.

**Bigger change** (a new skill, a new hook, a breaking change to file format):
1. Bump the version in `.claude-plugin/plugin.json` (e.g. `0.1.0` → `0.2.0`).
2. Add a one-line entry to a `CHANGELOG.md` (create it on first version bump).
3. Tag the release: `git tag v0.2.0 && git push --tags`.

---

# Bi-Weekly Review

Set a calendar reminder for every other Monday. The review takes about 20 minutes and looks like this.

## 1. Read the upstream digest (5 min)

If you set up the GitHub Action from `docs/UPSTREAM.md`, you'll have a `upstream-digest.txt` artifact each week. Open the most recent two weeks. Scan release titles for any of these magic words:

- "skill", "hook", "memory", "compression", "context"
- "breaking", "deprecate", "rename"
- numbers (token counts, CPU savings, percentage improvements)

If nothing pings, close the tab. You're done with this section.

## 2. Spot-check your own state files (5 min)

Pick one project where you've been using the optimizer for at least a week. Open:

- `.claude/state/MEMORY.md` — does it have anything you'd be embarrassed to commit? Anything that looks like a credential? Anything that's now wrong?
- `.claude/state/PROGRESS.md` — is it growing? More than ~200 lines means time to archive the older entries.
- `.claude/state/TASKS.md` — any tasks stuck in `IN_PROGRESS` for two weeks? They're either dead or actively haunting you. Decide.

## 3. Note what hurt (5 min)

Open `claude-optimizer/docs/BACKLOG.md` (create it if it doesn't exist) and jot down things you wished the kit did differently in the last two weeks. One line each. Don't fix anything yet.

Examples:
- "cm-quality-gate took too long on the big monorepo — needs a fast-mode flag"
- "Claude keeps re-explaining what just happened despite cm-token-discipline — tighten the rules"
- "TASKS.md got noisy with single-step tickets — raise the threshold for creating an entry"

## 4. Decide what to ship (5 min)

From the backlog plus the upstream digest, pick **at most one** thing to ship this fortnight. The whole point of staying small is not chasing every shiny improvement. If everything in the backlog is "would be nice" and nothing is "this is hurting me", ship nothing.

If you do ship something, the small-change git workflow above takes 5 minutes.

## What to do when we revisit this together

Every two weeks, paste me:

1. The contents of `BACKLOG.md` since last review
2. The latest upstream digest (or the URLs of any release you found interesting)
3. One sentence about what's working well
4. One sentence about what's bugging you

I'll suggest concrete edits. Then either you or your Claude Code commits them.

---

# What to never automate

Even though most of this is scriptable, **don't auto-merge upstream changes into your kit**. Reading the diff is the whole quality-control step. The moment that step disappears, the kit will start growing features you don't want and breaking things you depend on.

The bi-weekly review is the safeguard. Skip it when you're busy; never replace it with a cron job.
