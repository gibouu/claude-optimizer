# Security

## Threat model

This plugin is designed for individual developers and small teams. It does not run a network service, does not call out to any third-party API, and does not store credentials. Everything it touches is under `.claude/` in your project.

That said, four things can still go wrong, and you should know about them.

## 1. Secrets ending up in state files

Claude writes to `MEMORY.md`, `DECISIONS.md`, `PROGRESS.md`, and `TASKS.md`. If you ever paste an API key, a database connection string, a customer name, or an internal URL into a Claude Code session, Claude *might* summarise it into one of these files. If you commit those files, the secret is now in your git history.

**Mitigations:**

- The `cm-memory` skill explicitly tells Claude to strip anything wrapped in `<private>...</private>` tags before writing. Use this when you have to share something sensitive: `<private>db connection: postgres://...</private>`.
- The recommended `.gitignore` snippet (see `templates/gitignore-snippet.txt`) shows how to keep state files local to each developer's machine if your repo is public or your sessions cover sensitive material.
- Run `git diff .claude/state/` before any commit that touches state. Treat it like reviewing a `.env` change.

If a secret does leak: rotate the credential immediately, then `git filter-repo` or `git filter-branch` to scrub history. GitHub's secret scanning will catch common token formats, but not customer data or internal hostnames.

## 2. Hook scripts running on installer machines

When someone installs your plugin from the marketplace, the hook scripts in `scripts/` run on their machine on every Claude Code session. This is by design, but it means your scripts must be:

- **Readable.** Anyone reviewing the repo before installing should be able to skim a script in 10 seconds and know what it does.
- **Minimal-privilege.** No `curl | sh`. No `sudo`. No writing outside `${CLAUDE_PROJECT_DIR}/.claude/state/`.
- **Idempotent.** Running them twice should be the same as running them once.
- **Non-blocking.** A hook that hangs blocks the user's session. Use timeouts.

The shipped scripts follow these rules. If you fork or modify, hold the bar.

## 3. Plugin manifest tampering

`plugin.json` and `hooks/hooks.json` define what runs. Treat them like CI config — review every change in a PR. Don't accept PRs that add hooks pointing to scripts you haven't read.

## 4. Cross-platform foot-guns

- The `.sh` scripts assume bash. On Windows they need WSL, Git Bash, or the PowerShell equivalents (shipped in `scripts-pwsh/`).
- File paths in scripts use `/`. The `${CLAUDE_PROJECT_DIR}` and `${CLAUDE_PLUGIN_ROOT}` variables are normalised by Claude Code, but if you write your own scripts, prefer Node.js helpers over raw shell for portability.
- Permissions: on Unix you must `chmod +x scripts/*.sh` after install. The README documents this.

## What this plugin does NOT do

- Send data anywhere. No telemetry, no analytics, no "phone home."
- Read environment variables containing secrets.
- Parse or alter your `.env` files, `.aws/`, `.ssh/`, or password managers.
- Invoke any binary not already on your `PATH`.

If a future version of this plugin adds any of those, it will be in a major version bump with a prominent warning in the changelog.

## Reporting issues

If you find a security issue, email me directly rather than opening a public issue. Replace `me@example.com` below with your actual contact:

> Security contact: me@example.com

## Audit log

| Version | Date | Reviewer | Notes |
|---|---|---|---|
| 0.1.0 | 2026-04-30 | self | Initial release. No external network calls. No secret access. |
