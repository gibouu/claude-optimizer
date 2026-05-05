#!/usr/bin/env bash
# Read-only compliance audit. Surfaces this session's edit count, commits,
# state writes, harness firings, and a derived compliance percentage.
#
# Output format is fixed and machine-checkable. Do not modify state.
set -euo pipefail

ROOT="${CLAUDE_PROJECT_DIR:-$PWD}"
STATE_DIR="$ROOT/.claude/state"
MARKER="$STATE_DIR/.session_start_marker"

if [ ! -f "$MARKER" ]; then
  echo "[claude-optimizer audit] state not initialised — nothing to audit"
  exit 0
fi

read_int() {
  local v
  v="$(cat "$1" 2>/dev/null || echo 0)"
  case "$v" in ''|*[!0-9]*) echo 0 ;; *) echo "$v" ;; esac
}

mtime_of() {
  stat -f %m "$1" 2>/dev/null || stat -c %Y "$1" 2>/dev/null || echo 0
}

EDITS="$(read_int "$STATE_DIR/.edit_count")"
DIRECTIVES="$(read_int "$STATE_DIR/.last_directive_count")"
DIRECTIVE_FIRES=$(( DIRECTIVES / 5 ))                          # one fire per multiple-of-5
STOP_BLOCKS_FIRED=0
[ "$(read_int "$STATE_DIR/.last_stop_block_count")" -gt 0 ] && STOP_BLOCKS_FIRED=1

MARKER_TS="$(mtime_of "$MARKER")"

touched_since_marker() {
  local f="$STATE_DIR/$1"
  [ -f "$f" ] || { echo "absent"; return; }
  local ts
  ts="$(mtime_of "$f")"
  if [ "$ts" -gt "$MARKER_TS" ]; then
    echo "touched"
  else
    echo "not touched"
  fi
}

TASKS_STATE="$(touched_since_marker TASKS.md)"
DECISIONS_STATE="$(touched_since_marker DECISIONS.md)"
MEMORY_STATE="$(touched_since_marker MEMORY.md)"

count_touched() {
  local n=0
  for s in "$@"; do [ "$s" = "touched" ] && n=$((n+1)); done
  echo "$n"
}
MEANINGFUL_WRITES="$(count_touched "$TASKS_STATE" "$DECISIONS_STATE" "$MEMORY_STATE")"

# Commits since session start. Use git log with --since=<ISO timestamp>.
COMMITS=0
if command -v git >/dev/null 2>&1 && git -C "$ROOT" rev-parse --git-dir >/dev/null 2>&1; then
  SINCE="$(date -r "$MARKER_TS" '+%Y-%m-%d %H:%M:%S' 2>/dev/null || date -d "@$MARKER_TS" '+%Y-%m-%d %H:%M:%S' 2>/dev/null || true)"
  if [ -n "$SINCE" ]; then
    COMMITS=$(git -C "$ROOT" log --since="$SINCE" --oneline 2>/dev/null | wc -l | tr -d ' ')
  fi
fi

# PROGRESS entries this session = total lines minus the 2-line seed header,
# capped at 0.
PROGRESS_ENTRIES=0
if [ -f "$STATE_DIR/PROGRESS.md" ]; then
  L=$(wc -l < "$STATE_DIR/PROGRESS.md" 2>/dev/null | tr -d ' ' || echo 0)
  PROGRESS_ENTRIES=$(( L > 2 ? L - 2 : 0 ))
fi

EXPECTED=$(( EDITS / 5 ))
if [ "$EXPECTED" -lt 1 ]; then
  COMPLIANCE_PCT=100
else
  PCT=$(( MEANINGFUL_WRITES * 100 / EXPECTED ))
  [ "$PCT" -gt 100 ] && PCT=100
  COMPLIANCE_PCT="$PCT"
fi

cat <<EOF
[claude-optimizer audit]
Session activity:
  Edits:                  $EDITS
  Commits:                $COMMITS
  PROGRESS entries:       $PROGRESS_ENTRIES (auto + manual mixed)
State writes since session start:
  TASKS.md:               $TASKS_STATE
  DECISIONS.md:           $DECISIONS_STATE
  MEMORY.md:              $MEMORY_STATE
Harness signals:
  PromptSubmit directives fired: $DIRECTIVE_FIRES
  Stop-gate blocks:              $STOP_BLOCKS_FIRED
Compliance:
  Expected checkpoints (1 per 5 edits): $EXPECTED
  Meaningful state writes detected:     $MEANINGFUL_WRITES
  Compliance: ${COMPLIANCE_PCT}%   (target: cm-checkpoint or equivalent every 5 edits)

Note: per-skill invocation counts are not natively tracked. Compliance is
inferred from TASKS/DECISIONS/MEMORY mtimes against the session marker.
EOF
