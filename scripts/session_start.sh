#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
"$SCRIPT_DIR/init_state.sh" >/dev/null 2>&1 || true

ROOT="${CLAUDE_PROJECT_DIR:-$PWD}"
STATE_DIR="$ROOT/.claude/state"

# Per-project opt-out — silent pass-through.
[ -f "$ROOT/.claude/optimizer-disabled" ] && exit 0

# Drop a session-start mtime marker so the Stop hook can tell whether any
# model-driven state files have been touched during this session.
if [ -d "$STATE_DIR" ]; then
  touch "$STATE_DIR/.session_start_marker" 2>/dev/null || true
  rm -f "$STATE_DIR/.last_stop_block_count" 2>/dev/null || true
fi

# Run the secret scanner once at session start.
"$SCRIPT_DIR/scan_secrets.sh" || true

# Compute "last meaningful state write" — youngest mtime among TASKS /
# DECISIONS / MEMORY that has been written beyond its init seed. PROGRESS is
# excluded (post_edit.sh auto-touches it on every edit; not a signal of
# intentional checkpointing).
seed_lines_for() {
  case "$1" in
    TASKS.md)     echo 2 ;;
    DECISIONS.md) echo 2 ;;
    MEMORY.md)    echo 3 ;;
    *)            echo 0 ;;
  esac
}

mtime_of() {
  stat -f %m "$1" 2>/dev/null || stat -c %Y "$1" 2>/dev/null || true
}

youngest_meaningful_mtime() {
  local best="" f path lines seed m
  for f in TASKS.md DECISIONS.md MEMORY.md; do
    path="$STATE_DIR/$f"
    [ -f "$path" ] || continue
    lines=$(wc -l < "$path" 2>/dev/null | tr -d ' ' || echo 0)
    seed=$(seed_lines_for "$f")
    [ "${lines:-0}" -gt "$seed" ] || continue
    m=$(mtime_of "$path")
    [ -n "$m" ] || continue
    if [ -z "$best" ] || [ "$m" -gt "$best" ]; then
      best="$m"
    fi
  done
  echo "${best:-}"
}

format_ago() {
  local now diff
  now=$(date +%s)
  diff=$(( now - $1 ))
  if   [ "$diff" -lt 60 ];     then echo "just now"
  elif [ "$diff" -lt 3600 ];   then echo "$((diff/60))m ago"
  elif [ "$diff" -lt 86400 ];  then echo "$((diff/3600))h ago"
  else                              echo "$((diff/86400))d ago"
  fi
}

# Single-line banner — the skill list is already in the available-skills
# system message; rules are in CLAUDE.md and skill bodies.
last_write="never"
if [ -d "$STATE_DIR" ]; then
  ts=$(youngest_meaningful_mtime)
  [ -n "$ts" ] && last_write=$(format_ago "$ts")
fi

echo "[claude-optimizer active] last state write: ${last_write} | state: .claude/state/"
