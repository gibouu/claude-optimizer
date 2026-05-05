#!/usr/bin/env bash
# Runs when Claude is about to stop a turn.
#
# Behaviour: when the working tree has uncommitted changes AND meaningful
# work has accumulated this session AND none of the model-driven state
# files (TASKS/DECISIONS/MEMORY) has been touched since session start,
# block the stop with exit 2 so the harness re-prompts the model. This
# converts the contract "checkpoint state before declaring done" from
# advisory to enforced.
#
# When conditions don't meet the bar for blocking but the tree is still
# dirty, fall back to the prior advisory message.
#
# Safeguards: never blocks twice at the same edit-count value (avoids
# loops), never blocks during git mid-operation states (rebase, merge,
# cherry-pick, bisect), respects the per-project opt-out.
set -euo pipefail

ROOT="${CLAUDE_PROJECT_DIR:-$PWD}"
STATE_DIR="$ROOT/.claude/state"
cd "$ROOT" 2>/dev/null || exit 0

# Per-project opt-out — silent pass-through.
[ -f "$ROOT/.claude/optimizer-disabled" ] && exit 0

# Need git to do anything useful.
command -v git >/dev/null 2>&1 || exit 0
git rev-parse --git-dir >/dev/null 2>&1 || exit 0
GIT_DIR="$(git rev-parse --git-dir 2>/dev/null)"

# Skip during mid-operation git states — uncommitted-by-design.
for marker in rebase-merge rebase-apply MERGE_HEAD CHERRY_PICK_HEAD BISECT_LOG REVERT_HEAD; do
  if [ -e "$GIT_DIR/$marker" ]; then
    exit 0
  fi
done

# Clean tree → nothing to do.
if git diff --quiet && git diff --cached --quiet; then
  exit 0
fi

DIRTY_MSG="[claude-optimizer] Uncommitted changes present. Apply cm-quality-gate before declaring done."

# State must be initialised for the gate to make sense.
[ -d "$STATE_DIR" ] || { echo "$DIRTY_MSG" >&2; exit 0; }

read_int() {
  local v
  v="$(cat "$1" 2>/dev/null || echo 0)"
  case "$v" in ''|*[!0-9]*) echo 0 ;; *) echo "$v" ;; esac
}

COUNT="$(read_int "$STATE_DIR/.edit_count")"
LAST_BLOCK="$(read_int "$STATE_DIR/.last_stop_block_count")"

# Need meaningful accumulated work before the gate has standing.
if [ "$COUNT" -lt 5 ]; then
  echo "$DIRTY_MSG" >&2
  exit 0
fi

MARKER="$STATE_DIR/.session_start_marker"
# Without a session marker we can't reason about staleness; advisory only.
[ -f "$MARKER" ] || { echo "$DIRTY_MSG" >&2; exit 0; }

# State is fresh if any model-driven file has been touched since session start.
state_is_fresh() {
  local f
  for f in "$STATE_DIR/TASKS.md" "$STATE_DIR/DECISIONS.md" "$STATE_DIR/MEMORY.md"; do
    [ -f "$f" ] || continue
    if [ "$f" -nt "$MARKER" ]; then
      return 0
    fi
  done
  return 1
}

if state_is_fresh; then
  echo "$DIRTY_MSG" >&2
  exit 0
fi

# Loop guard: only block once per edit-count value.
if [ "$LAST_BLOCK" -eq "$COUNT" ]; then
  echo "$DIRTY_MSG (already blocked once at this edit count — proceeding advisory only)" >&2
  exit 0
fi

echo "$COUNT" > "$STATE_DIR/.last_stop_block_count" || true

cat >&2 <<EOF
[claude-optimizer] Stop blocked.
Reason: $COUNT edits this session, working tree is dirty, and no model-driven state file (TASKS.md / DECISIONS.md / MEMORY.md) has been touched since session start.

Before stopping again, do at least one of:
  - Invoke cm-task-tracker and append/close entries in TASKS.md.
  - Invoke cm-memory to record any decisions in DECISIONS.md or stable facts in MEMORY.md.
  - Commit the working tree (clean tree exits this gate).
  - If this gate is wrong for your workflow, set CLAUDE_PROJECT_DIR/.claude/optimizer-disabled to opt out.

This is the project's claude-optimizer contract: state writes precede "done".
EOF
exit 2
