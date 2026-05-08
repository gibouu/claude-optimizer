# Contributing

## Verifying changes

The plugin ships small bash test harnesses for the logic-heavy hooks:

```sh
bash tests/test_prompt_submit.sh    # 12 cases — UserPromptSubmit directive logic
bash tests/test_pre_exit_plan.sh    # 14 cases — cm-research-first + cm-multi-plan gates
bash tests/test_pr_preflight.sh     # 12 cases — gh pr create gate (Closes #N + scope)
```

The runner is dependency-free — pure bash, no BATS or other test frameworks. Each fixture directory under `tests/fixtures/prompt_submit/` holds:

- `input.json` — the JSON payload piped to the hook on stdin (UserPromptSubmit shape).
- `expected.txt` — the exact stdout the hook should emit (may be empty).
- `setup.sh` (optional) — sourced before the hook runs; can seed state files in the per-case `$PROJ_DIR/.claude/state/` sandbox or export environment variables (e.g. PATH manipulation to mask `jq`).

To add a new fixture, create a new numbered directory and drop in the three files. The runner picks them up automatically in lexical order.

## Live verification

For end-to-end verification of hook behaviour, install the plugin locally and use Claude Code's debug output:

```sh
# Reinstall after a version bump so the new code is loaded.
/plugin uninstall claude-optimizer
/plugin install claude-optimizer

# In a new session, watch hook stdout/stderr:
claude --debug
```

Source edits to `scripts/*.sh` do not affect the running plugin — Claude Code resolves hook commands against the installed plugin version, not the working tree. Bump `.claude-plugin/plugin.json` and reinstall to exercise changes.

## Conventions

- Hook scripts must never crash the prompt path. Wrap risky ops in `... || true` and `exit 0` at the bottom.
- State files in `.claude/state/` are seeded idempotently by `scripts/init_state.sh` (called from `session_start.sh`); never assume they exist without that bootstrap.
- New cleanup files (counters, fingerprints, markers) must be added to `scripts/session_end.sh`'s `rm -f` list so they don't leak across sessions.
- Bump `.claude-plugin/plugin.json` and prepend a CHANGELOG entry on every user-visible change.
