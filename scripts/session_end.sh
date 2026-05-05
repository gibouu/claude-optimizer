#!/usr/bin/env bash
set -euo pipefail
ROOT="${CLAUDE_PROJECT_DIR:-$PWD}"
rm -f "$ROOT/.claude/state/.edit_count" \
      "$ROOT/.claude/state/.last_directive_count" \
      "$ROOT/.claude/state/.last_stop_block_count" \
      "$ROOT/.claude/state/.session_start_marker"
