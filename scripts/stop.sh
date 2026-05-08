#!/usr/bin/env bash
# Stop hook. Blocks the turn end if the working tree has uncommitted changes,
# meaningful work has accumulated, and no model-driven state file has been
# touched since session start. Otherwise advisory only.
#
# Safeguards: never blocks twice at the same edit-count value, never blocks
# during git mid-operation states, respects per-project opt-out.
set -euo pipefail

ROOT="${CLAUDE_PROJECT_DIR:-$PWD}"
STATE_DIR="$ROOT/.claude/state"
cd "$ROOT" 2>/dev/null || exit 0

[ -f "$ROOT/.claude/optimizer-disabled" ] && exit 0
command -v git >/dev/null 2>&1 || exit 0
git rev-parse --git-dir >/dev/null 2>&1 || exit 0
GIT_DIR="$(git rev-parse --git-dir 2>/dev/null)"

# Skip during mid-operation git states.
for marker in rebase-merge rebase-apply MERGE_HEAD CHERRY_PICK_HEAD BISECT_LOG REVERT_HEAD; do
  [ -e "$GIT_DIR/$marker" ] && exit 0
done

# Clean tree → nothing to do.
if git diff --quiet && git diff --cached --quiet; then
  exit 0
fi

DIRTY_MSG="[claude-optimizer] Uncommitted changes. Run cm-quality-gate before declaring done."

[ -d "$STATE_DIR" ] || { echo "$DIRTY_MSG" >&2; exit 0; }

read_int() {
  local v
  v="$(cat "$1" 2>/dev/null || echo 0)"
  case "$v" in ''|*[!0-9]*) echo 0 ;; *) echo "$v" ;; esac
}

COUNT="$(read_int "$STATE_DIR/.edit_count")"
LAST_BLOCK="$(read_int "$STATE_DIR/.last_stop_block_count")"

if [ "$COUNT" -lt 5 ]; then
  echo "$DIRTY_MSG" >&2
  exit 0
fi

MARKER="$STATE_DIR/.session_start_marker"
[ -f "$MARKER" ] || { echo "$DIRTY_MSG" >&2; exit 0; }

state_is_fresh() {
  local f
  for f in "$STATE_DIR/TASKS.md" "$STATE_DIR/DECISIONS.md" "$STATE_DIR/MEMORY.md"; do
    [ -f "$f" ] || continue
    if [ "$f" -nt "$MARKER" ]; then return 0; fi
  done
  return 1
}

if state_is_fresh; then
  echo "$DIRTY_MSG" >&2
  exit 0
fi

# Loop guard: only block once per edit-count value.
if [ "$LAST_BLOCK" -eq "$COUNT" ]; then
  echo "$DIRTY_MSG (already blocked at this edit count, advisory only)" >&2
  exit 0
fi

echo "$COUNT" > "$STATE_DIR/.last_stop_block_count" || true

# Record for prompt_submit's retry-context (R3-write).
record_block_file="$STATE_DIR/.recent_blocks"
printf '%s: %s\n' "stop" "${COUNT} edits + dirty tree, no state write since session start" >> "$record_block_file" 2>/dev/null || true
if [ -f "$record_block_file" ]; then
  tail -3 "$record_block_file" > "${record_block_file}.tmp" 2>/dev/null && mv "${record_block_file}.tmp" "$record_block_file" 2>/dev/null || true
fi

cat >&2 <<EOF
[claude-optimizer] Stop blocked.
${COUNT} edits + dirty tree + no state write since session start. Run cm-checkpoint, commit, or set .claude/optimizer-disabled.
EOF
exit 2
