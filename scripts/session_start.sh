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

cat <<'EOF'
[claude-optimizer active]
Skills available: cm-session-resume, cm-memory, cm-task-tracker,
                  cm-token-discipline, cm-quality-gate, cm-secret-hygiene.
State: .claude/state/{MEMORY,DECISIONS,PROGRESS,TASKS}.md
Rules:
  - Resume IN_PROGRESS work in one line if any.
  - Never write secrets/credentials/PII to state files.
  - Run quality gate before saying "done".
EOF
