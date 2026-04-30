# claude-optimizer

A small, opinionated Claude Code plugin that fixes the four things that go wrong in long sessions:

1. **Lost context** — Claude forgets what was decided 20 messages ago.
2. **Token bloat** — boilerplate preamble/postamble eats budget without adding value.
3. **Drift** — Claude wanders off the original task into related-but-unrequested work.
4. **False completions** — "done" before tests, types, or lints pass.

It does this with six skills, five hook scripts, two slash commands, and four plain-text state files. Local-only. No daemon, no database, no network calls.

## What's inside

```
claude-optimizer/
├── .claude-plugin/plugin.json
├── skills/
│   ├── cm-memory/                 # MEMORY/DECISIONS/PROGRESS protocol
│   ├── cm-token-discipline/       # output-bloat rules
│   ├── cm-task-tracker/           # explicit task ledger
│   ├── cm-session-resume/         # what to do at session start
│   ├── cm-quality-gate/           # checks before "done"
│   └── cm-secret-hygiene/         # what files Claude must never read or log
├── hooks/hooks.json               # SessionStart, PostToolUse, Stop, SessionEnd
├── scripts/
│   ├── init_state.sh              # creates .claude/state/ safely
│   ├── scan_secrets.sh            # detects leaked credentials in state files
│   ├── session_start.sh, post_edit.sh, stop.sh, session_end.sh
├── commands/                      # /cm:status, /cm:checkpoint
├── templates/gitignore-snippet.txt
├── docs/
│   ├── ARCHITECTURE.md
│   └── UPSTREAM.md
├── LICENSE                        # MIT
├── SECURITY.md
└── .gitignore
```

## State files (created on first session)

```
your-project/.claude/state/
├── MEMORY.md       # stable project facts
├── DECISIONS.md    # one-liner architectural decisions, dated
├── PROGRESS.md     # rolling work log, newest first
├── TASKS.md        # explicit task ledger with status + steps
├── archive/        # auto-rotated old TASKS-YYYY-MM.md
└── .gitignore      # auto-created, keeps .edit_count and archive/ out of git
```

These live **inside the project**. They never leave the repo. They're meant to be diff-able, human-editable, and committable — except the bits the auto-`.gitignore` excludes.

## Local-first guarantees

- All state lives under `<your-project>/.claude/state/`. Nothing in `~/`, nothing in `/tmp` permanently, nothing on a network.
- The `init_state.sh` script refuses to run if the project root resolves to `/`, `$HOME`, or empty — so it can't accidentally scribble into your home dir.
- No script in this kit ever calls `curl`, `wget`, or any network tool.
- No telemetry. No analytics. No "phone home" of any kind.

## Install

### Option A — drop into a single project (no GitHub needed)

```bash
cd your-project
git clone https://github.com/<you>/claude-optimizer .claude-optimizer-tmp
mkdir -p .claude
cp -r .claude-optimizer-tmp/skills .claude/
cp -r .claude-optimizer-tmp/hooks  .claude/
cp -r .claude-optimizer-tmp/scripts .claude/
cp -r .claude-optimizer-tmp/commands .claude/
chmod +x .claude/scripts/*.sh
rm -rf .claude-optimizer-tmp

# IMPORTANT: edit .claude/hooks/hooks.json and replace ${CLAUDE_PLUGIN_ROOT}
# with ${CLAUDE_PROJECT_DIR}/.claude  (the plugin-root variable only exists
# when installed via the plugin marketplace).
```

Then add the suggested lines from `templates/gitignore-snippet.txt` to your project's top-level `.gitignore` if you want extra paranoia.

### Option B — install as a plugin (recommended once you've pushed to GitHub)

```
/plugin marketplace add <your-username>/claude-optimizer
/plugin install claude-optimizer@claude-optimizer
```

No edits needed — `${CLAUDE_PLUGIN_ROOT}` resolves correctly when installed this way. Active in every project automatically.

## Per-project setup (one-time)

To keep the per-session counter and archive folder out of commits, run the bundled helper from any project once:

```bash
# in any project where you want optimizer state out of commits
bash ~/path/to/claude-optimizer/scripts/install_to_project.sh
```

It appends the lines from `templates/gitignore-snippet.txt` to that project's `.gitignore`. Idempotent — re-running does nothing if the snippet is already there.

## Disabling per-project

Some repos shouldn't accumulate memory or progress logs. To opt out:

```bash
touch .claude/optimizer-disabled
```

`init_state.sh` exits silently when that file is present, so no `.claude/state/` directory is created and no hooks write anything for that project.

## What you'll notice

- Claude reads state silently at session start; only speaks up if there's in-progress work.
- Multi-step tasks create a `TASKS.md` entry without asking.
- Replies are noticeably shorter — no preamble, no postamble.
- Before saying "done", Claude runs your project's tests/lint/typecheck.
- After every Write/Edit, the secret scanner runs against state files. If it sees something resembling an API key, it warns immediately.

## Safety summary

| Risk | Mitigation |
|---|---|
| Secrets written to state files | `cm-secret-hygiene` skill + `scan_secrets.sh` runs after every edit |
| State files committed with secrets | Per-state `.gitignore` auto-created; recommended snippet for project root |
| Hooks running outside project | `init_state.sh` refuses unsafe roots; all paths use `$CLAUDE_PROJECT_DIR` |
| Claude reading `.env` or keys | `cm-secret-hygiene` skill explicitly forbids it; stop-and-ask required |
| Plugin reaching the network | No script invokes `curl`, `wget`, or any remote call |

Full details in [`SECURITY.md`](SECURITY.md).

## Two slash commands

- `/cm:status` — compact dashboard of open tasks + recent decisions/progress.
- `/cm:checkpoint` — force a memory write before context fills up.

## Comparison with the kit's inspirations

| Project | What it does | What this borrows | What this skips |
|---|---|---|---|
| [thedotmack/claude-mem](https://github.com/thedotmack/claude-mem) | SQLite + ChromaDB + worker daemon | the "session-boundary memory" idea | the daemon, DB, embeddings |
| [JuliusBrussee/cavemem](https://github.com/JuliusBrussee/cavemem) | local SQLite + FTS5 via MCP | local-first, file-first storage | MCP server requirement |
| [JuliusBrussee/caveman](https://github.com/JuliusBrussee/caveman) | "talk like caveman" output compression | discipline of cutting prose padding | the grammar gimmick |
| [JuliusBrussee/cavekit](https://github.com/JuliusBrussee/cavekit) | spec-driven loop with peer review | spec-as-source-of-truth (`MEMORY.md`) | the orchestration layer |
| [affaan-m/everything-claude-code](https://github.com/affaan-m/everything-claude-code) | 48 agents + 184 skills + 79 commands | rules-per-language idea | 99% of the catalog |

This plugin deliberately stays small. Six skills you can read in 15 minutes beats 184 you'll never open.

## Updating from upstream

See [`docs/UPSTREAM.md`](docs/UPSTREAM.md) for the strategy on watching the source repos and selectively pulling improvements without inheriting bloat.

## License

MIT — see [`LICENSE`](LICENSE).
