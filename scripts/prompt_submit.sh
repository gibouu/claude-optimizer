#!/usr/bin/env bash
# Runs before each user prompt is dispatched to the model.
#
# Job: when the project's edit counter shows accumulated work without a
# corresponding state checkpoint, emit an "additional context" block that
# instructs Claude to invoke the cm-* skills BEFORE responding to the
# prompt. UserPromptSubmit hooks send stdout to the model as inline
# context, which is much harder to ignore than stderr nags.
#
# Never blocks. Logging-only failure modes are swallowed.
set -euo pipefail

ROOT="${CLAUDE_PROJECT_DIR:-$PWD}"
STATE_DIR="$ROOT/.claude/state"

# Per-project opt-out — silent pass-through.
[ -f "$ROOT/.claude/optimizer-disabled" ] && exit 0

# State must exist; if not, session_start.sh hasn't seeded yet.
[ -d "$STATE_DIR" ] || exit 0

COUNT_FILE="$STATE_DIR/.edit_count"
LAST_FILE="$STATE_DIR/.last_directive_count"

read_int() {
  local v
  v="$(cat "$1" 2>/dev/null || echo 0)"
  case "$v" in ''|*[!0-9]*) echo 0 ;; *) echo "$v" ;; esac
}

COUNT="$(read_int "$COUNT_FILE")"
LAST="$(read_int "$LAST_FILE")"

# Defensive rollover: if LAST is somehow ahead of COUNT (e.g. stale file
# survived a session reset), treat as fresh.
if [ "$LAST" -gt "$COUNT" ]; then
  LAST=0
fi

# Cadence: fire on each new positive multiple of 5 edits. The LAST<COUNT
# guard prevents repeat-firing on prompts that arrive without intervening
# edits.
if [ "$COUNT" -ge 5 ] && [ $((COUNT % 5)) -eq 0 ] && [ "$LAST" -lt "$COUNT" ]; then
  echo "$COUNT" > "$LAST_FILE" || true
  cat <<EOF
[claude-optimizer] State checkpoint required.
You have made $COUNT edits this session without a state write. Before responding to the user's prompt:
- Invoke cm-checkpoint to atomically update PROGRESS.md / TASKS.md / DECISIONS.md / MEMORY.md as warranted (the bundled skill — preferred).
- Or, if you only need to touch one file, invoke cm-task-tracker (TASKS.md) or cm-memory (PROGRESS / DECISIONS / MEMORY) directly.
This is a hard requirement under this project's claude-optimizer plugin contract. Do this BEFORE addressing the user's prompt; do not skip or defer.
EOF
fi

exit 0
