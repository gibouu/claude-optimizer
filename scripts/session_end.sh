#!/usr/bin/env bash
set -euo pipefail
ROOT="${CLAUDE_PROJECT_DIR:-$PWD}"
rm -f "$ROOT/.claude/state/.edit_count"
