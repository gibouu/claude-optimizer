---
name: cm-secret-hygiene
description: Use before any Read/Write/Edit on files matching `.env*`, `*.pem`, `*.key`, `id_rsa*`, `~/.aws/`, `~/.ssh/`, or paths containing `secret`/`credential`/`token`/`password`; before any Write/Edit to `.claude/state/*.md`; and whenever scan_secrets.sh emits a warning to stderr. Also auto-active on every session alongside cm-token-discipline. Defines what Claude must never read, never write to state, and never include in tool calls.
---

# Secret Hygiene

The state files this plugin maintains (`MEMORY.md`, `DECISIONS.md`, `PROGRESS.md`, `TASKS.md`) get committed to git in most setups. So does anything Claude pastes into chat that the user later copies. This skill prevents secrets from getting into either path.

## Files Claude must never read unprompted

Even if a search or glob would naturally include them. Read these only if the user explicitly names the file by path *and* there's a clear, legitimate need.

- `.env`, `.env.*`, `.envrc` — environment files
- `*.pem`, `*.key`, `*.p12`, `*.pfx`, `id_rsa*`, `id_ed25519*` — private keys
- `~/.aws/credentials`, `~/.aws/config`
- `~/.ssh/` — anything in here
- `~/.netrc`, `~/.docker/config.json`, `~/.kube/config`
- `*.sqlite`, `*.db` — application databases (often contain user data)
- Anything matching `*secret*`, `*credential*`, `*token*`, `*password*` in the filename, unless the user explicitly asked

If a tool call would touch one of these, stop and ask first: *"This would read `<path>`, which usually contains secrets. Continue?"*

## Things Claude must never write to state files

Even paraphrased, even partial. Even if the user typed it.

- API keys, OAuth tokens, JWTs, session cookies
- Passwords or password hashes
- Database connection strings *with credentials embedded*
- Private keys, certificates, signing keys
- Real customer email addresses, phone numbers, or names
- Internal hostnames, IP addresses, or URL paths to admin endpoints
- Anything wrapped in `<private>...</private>` tags

If a memory entry would naturally contain any of the above, capture the *fact* without the *value*:

| Bad | Good |
|---|---|
| `[2026-04-30] api: rotated key sk-abc123def456...` | `[2026-04-30] api: rotated production key. Stored in 1Password.` |
| `[2026-04-30] db: connection postgres://user:pw@10.0.1.5/prod` | `[2026-04-30] db: prod connection string moved to env var DB_URL.` |
| `[2026-04-30] auth: customer alice@acme.com hit the bug` | `[2026-04-30] auth: a real-customer report reproduced the bug.` |

## What to do if a secret is already in a state file

The post-edit hook runs a secret scanner. If it warns:

1. Tell the user immediately. One line, no panic.
2. Don't auto-edit the state file to remove the secret — the user might have already committed it, in which case rotation matters more than redaction.
3. Recommend: rotate the credential, then clean the file, then if it's already committed, run `git filter-repo` or contact GitHub support.
4. Add one line to `DECISIONS.md`: `[YYYY-MM-DD] secret-rotation: <which credential type, no value>. Why: leaked into state file.`

## Reading discipline for non-state files

When grepping or globbing across the repo:

- Skip `node_modules/`, `vendor/`, `.git/`, `dist/`, `build/`, `coverage/` by default
- Skip files larger than ~1MB unless the task requires them — they're usually generated, vendored, or binary
- If a file's content includes anything matching the patterns the secret scanner uses, don't paste it back to the user verbatim — summarise

## What this skill is not

This is not a sandbox. Claude Code can technically read any file the OS lets it read. This skill makes the policy explicit and forces a stop-and-ask before crossing the line. The scanner in `scripts/scan_secrets.sh` is the second layer.
