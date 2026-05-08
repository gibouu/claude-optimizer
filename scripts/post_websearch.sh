#!/usr/bin/env bash
# Runs after every WebSearch tool use.
#
# Single job: touch the .websearch_this_turn marker so pre_exit_plan.sh can
# tell whether research was performed during the current turn. The marker
# is cleared by prompt_submit.sh at the start of every new prompt.
#
# Never blocks. Failure is silent.
set -euo pipefail

ROOT="${CLAUDE_PROJECT_DIR:-$PWD}"
STATE_DIR="$ROOT/.claude/state"

[ -f "$ROOT/.claude/optimizer-disabled" ] && exit 0
[ -d "$STATE_DIR" ] || exit 0

touch "$STATE_DIR/.websearch_this_turn" 2>/dev/null || true
exit 0
