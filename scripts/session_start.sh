#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
"$SCRIPT_DIR/init_state.sh" >/dev/null 2>&1 || true

# Drop a session-start mtime marker so the Stop hook can tell whether any
# model-driven state files have been touched during this session.
ROOT="${CLAUDE_PROJECT_DIR:-$PWD}"
STATE_DIR="$ROOT/.claude/state"
if [ -d "$STATE_DIR" ] && [ ! -f "$ROOT/.claude/optimizer-disabled" ]; then
  touch "$STATE_DIR/.session_start_marker" 2>/dev/null || true
  rm -f "$STATE_DIR/.last_stop_block_count" 2>/dev/null || true
fi

# Run the secret scanner once at session start in case state files were
# edited externally between sessions.
"$SCRIPT_DIR/scan_secrets.sh" || true

# Compute "Last meaningful state write" — youngest mtime among TASKS /
# DECISIONS / MEMORY that has been written beyond its init seed. PROGRESS
# is deliberately excluded; post_edit.sh auto-touches it on every edit so
# its mtime is not a signal of intentional checkpointing.
seed_lines_for() {
  case "$1" in
    TASKS.md)     echo 2 ;;
    DECISIONS.md) echo 2 ;;
    MEMORY.md)    echo 3 ;;
    *)            echo 0 ;;
  esac
}

mtime_of() {
  # Cross-platform mtime as epoch seconds. Returns empty on missing/error.
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
  elif [ "$diff" -lt 3600 ];   then echo "$((diff/60)) minutes ago"
  elif [ "$diff" -lt 86400 ];  then echo "$((diff/3600)) hours ago"
  else                              echo "$((diff/86400)) days ago"
  fi
}

LAST_WRITE_LINE=""
if [ -d "$STATE_DIR" ] && [ ! -f "$ROOT/.claude/optimizer-disabled" ]; then
  TS="$(youngest_meaningful_mtime)"
  if [ -n "$TS" ]; then
    LAST_WRITE_LINE="Last meaningful state write: $(format_ago "$TS")"
  else
    LAST_WRITE_LINE="Last meaningful state write: never (project just initialised)"
  fi
fi

cat <<EOF | sed '/^$/d'
[claude-optimizer active]
Skills available: cm-session-resume, cm-memory, cm-task-tracker,
                  cm-token-discipline, cm-quality-gate, cm-secret-hygiene,
                  cm-checkpoint, cm-issue-driven-workflow.
State: .claude/state/{MEMORY,DECISIONS,PROGRESS,TASKS}.md
${LAST_WRITE_LINE}
Rules:
  - Resume IN_PROGRESS work in one line if any.
  - Never write secrets/credentials/PII to state files.
  - Run quality gate before saying "done".
EOF
