#!/usr/bin/env bash
# Runs after every Write/Edit/MultiEdit tool use.
# Two jobs: (1) scan state files for secrets, (2) nudge Claude to checkpoint
# every 10 edits.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="${CLAUDE_PROJECT_DIR:-$PWD}"
STATE_DIR="$ROOT/.claude/state"
mkdir -p "$STATE_DIR"

# 1) Secret scan — non-blocking, prints warnings if anything looks bad.
"$SCRIPT_DIR/scan_secrets.sh" || true

# 2) Edit-counter reminder.
COUNT_FILE="$STATE_DIR/.edit_count"
COUNT=$(cat "$COUNT_FILE" 2>/dev/null || echo 0)
COUNT=$((COUNT + 1))
echo "$COUNT" > "$COUNT_FILE"

if (( COUNT % 10 == 0 )); then
  echo "[claude-optimizer] $COUNT edits this session — append to PROGRESS.md and tick TASKS.md before continuing."
fi
