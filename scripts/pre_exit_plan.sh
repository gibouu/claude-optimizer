#!/usr/bin/env bash
# Runs before every ExitPlanMode tool use.
#
# Single job: enforce cm-research-first. When the most recent triggering
# prompt was classified `[complexity: complex]` AND no WebSearch tool was
# called during the current turn, block ExitPlanMode. The user's stated
# workflow: complex tasks deserve a quick best-practices search before any
# plan is finalised.
#
# Block path: exit 2 + stderr message — Claude Code surfaces stderr to the
# model and refuses the tool call.
# Allow path: exit 0.
#
# Bypasses (in priority order):
#   - $ROOT/.claude/optimizer-disabled  (whole-plugin opt-out)
#   - RESEARCH_FIRST_OFF=1 env var      (one-off bypass)
#   - .last_prompt_complexity missing or != "complex"  (no enforcement)
#   - .websearch_this_turn present       (research was performed)
set -euo pipefail

ROOT="${CLAUDE_PROJECT_DIR:-$PWD}"
STATE_DIR="$ROOT/.claude/state"

# Whole-plugin opt-out.
[ -f "$ROOT/.claude/optimizer-disabled" ] && exit 0

# One-off bypass.
[ "${RESEARCH_FIRST_OFF:-}" = "1" ] && exit 0

# State must exist; otherwise nothing to enforce.
[ -d "$STATE_DIR" ] || exit 0

COMPLEXITY_FILE="$STATE_DIR/.last_prompt_complexity"
WEBSEARCH_MARKER="$STATE_DIR/.websearch_this_turn"

# No complexity tag → no enforcement (off-ramp / ambient prompt / no prior trigger).
[ -f "$COMPLEXITY_FILE" ] || exit 0

complexity="$(cat "$COMPLEXITY_FILE" 2>/dev/null || echo)"
case "$complexity" in
  complex) ;;
  *) exit 0 ;;  # only enforce on complex tasks
esac

# WebSearch was performed this turn → allow.
[ -f "$WEBSEARCH_MARKER" ] && exit 0

# Otherwise block.
cat >&2 <<EOF
[claude-optimizer] ExitPlanMode blocked by cm-research-first.
The current task was tagged \`[complexity: complex]\` but no WebSearch tool was called this turn.

Required: invoke cm-research-first to do a quick best-practices search before finalising the plan.
- Issue 1–2 WebSearch calls with the problem framing + a recency hint (e.g. "<topic> best practices 2026").
- Read 2–3 results and cite findings as a "Research notes" line in the plan.
- Then call ExitPlanMode again.

Bypasses (use sparingly, mention to the user):
- Set RESEARCH_FIRST_OFF=1 for the next ExitPlanMode call.
- Touch \`$STATE_DIR/.claude/optimizer-disabled\` to disable the whole plugin.

This is a hard requirement under this project's claude-optimizer plugin contract.
EOF
exit 2
