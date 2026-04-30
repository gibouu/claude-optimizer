#!/usr/bin/env bash
# Runs when Claude is about to stop a turn. Reminds it to apply the quality gate
# if there are uncommitted changes in tracked files.
set -euo pipefail
ROOT="${CLAUDE_PROJECT_DIR:-$PWD}"
cd "$ROOT" 2>/dev/null || exit 0

if command -v git >/dev/null 2>&1 && git rev-parse --git-dir >/dev/null 2>&1; then
  if ! git diff --quiet || ! git diff --cached --quiet; then
    echo "[claude-optimizer] Uncommitted changes present. Apply cm-quality-gate before declaring done."
  fi
fi
