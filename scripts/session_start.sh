#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
"$SCRIPT_DIR/init_state.sh" >/dev/null 2>&1 || true

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
