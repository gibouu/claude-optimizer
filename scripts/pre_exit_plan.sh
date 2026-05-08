#!/usr/bin/env bash
# Runs before every ExitPlanMode tool use. The single PreToolUse(ExitPlanMode)
# gate that runs all of the plugin's plan-finalisation checks in sequence.
#
# Checks (in order — first to block wins):
#   1. cm-research-first  — complex prompt + no WebSearch this turn → block.
#   2. cm-multi-plan      — moderate/complex prompt + plan file lacks any
#                            "alternatives / tradeoffs / decisions / options /
#                            approaches / comparison / considered" heading
#                            → block.
#
# Block path: exit 2 + stderr message — Claude Code surfaces stderr to the
# model and refuses the tool call. Allow path: exit 0.
#
# Top-level bypasses (skip ALL checks):
#   - $ROOT/.claude/optimizer-disabled  (whole-plugin opt-out)
#
# Per-check bypasses (skip just that check):
#   - RESEARCH_FIRST_OFF=1   skips check 1.
#   - MULTI_PLAN_OFF=1       skips check 2.
set -euo pipefail

ROOT="${CLAUDE_PROJECT_DIR:-$PWD}"
STATE_DIR="$ROOT/.claude/state"

# Whole-plugin opt-out.
[ -f "$ROOT/.claude/optimizer-disabled" ] && exit 0

# State must exist; otherwise nothing to enforce.
[ -d "$STATE_DIR" ] || exit 0

COMPLEXITY_FILE="$STATE_DIR/.last_prompt_complexity"
WEBSEARCH_MARKER="$STATE_DIR/.websearch_this_turn"

# No complexity tag → no enforcement (off-ramp / ambient prompt / no prior trigger).
[ -f "$COMPLEXITY_FILE" ] || exit 0

complexity="$(cat "$COMPLEXITY_FILE" 2>/dev/null || echo)"

# ── Check 1: cm-research-first ──────────────────────────────────────────
check_research_first() {
  [ "${RESEARCH_FIRST_OFF:-}" = "1" ] && return 0
  case "$complexity" in
    complex) ;;
    *) return 0 ;;  # only enforce on complex
  esac

  [ -f "$WEBSEARCH_MARKER" ] && return 0  # research was performed

  cat >&2 <<EOF
[claude-optimizer] ExitPlanMode blocked by cm-research-first.
The current task was tagged \`[complexity: complex]\` but no WebSearch tool was called this turn.

Required: invoke cm-research-first to do a quick best-practices search before finalising the plan.
- Issue 1–2 WebSearch calls with the problem framing + a recency hint (e.g. "<topic> best practices 2026").
- Read 2–3 results and cite findings as a "Research notes" line in the plan.
- Then call ExitPlanMode again.

Bypasses (use sparingly, mention to the user):
- Set RESEARCH_FIRST_OFF=1 for the next ExitPlanMode call.
- Touch \`$ROOT/.claude/optimizer-disabled\` to disable the whole plugin.

This is a hard requirement under this project's claude-optimizer plugin contract.
EOF
  exit 2
}

# ── Check 2: cm-multi-plan ──────────────────────────────────────────────
# Locate the most recently modified plan file under ~/.claude/plans/ and
# verify it contains an "alternatives / tradeoffs / decisions / options /
# approaches / comparison / considered" heading. Trivial plans (under 30
# lines) bypass.
check_multi_plan() {
  [ "${MULTI_PLAN_OFF:-}" = "1" ] && return 0
  case "$complexity" in
    moderate|complex) ;;
    *) return 0 ;;  # simple / unknown → no enforcement
  esac

  local plans_dir="$HOME/.claude/plans"
  [ -d "$plans_dir" ] || return 0

  # Pick the most recently modified plan file. Use a glob safely.
  local plan_file=""
  local f mtime now newest_mtime=0
  now=$(date +%s 2>/dev/null || echo 0)
  for f in "$plans_dir"/*.md; do
    [ -f "$f" ] || continue
    mtime=$(stat -f %m "$f" 2>/dev/null || stat -c %Y "$f" 2>/dev/null || echo 0)
    if [ "$mtime" -gt "$newest_mtime" ]; then
      newest_mtime=$mtime
      plan_file=$f
    fi
  done
  [ -n "$plan_file" ] || return 0

  # Stale-plan guard: if the most recent plan file is older than an hour,
  # we're probably not actually in plan mode for that plan — fall through.
  if [ "$now" -gt 0 ] && [ "$newest_mtime" -gt 0 ]; then
    if [ $((now - newest_mtime)) -gt 3600 ]; then
      return 0
    fi
  fi

  # Trivial-plan bypass.
  local lines
  lines=$(wc -l < "$plan_file" 2>/dev/null | tr -d ' ' || echo 0)
  [ "${lines:-0}" -lt 30 ] && return 0

  # Look for any canonical alternatives-keyword anywhere on a heading line.
  # POSIX ERE, case-insensitive. The pattern allows compound headings like
  # "## Design decisions" or "### Approaches considered".
  if grep -qiE '^#{1,3}[[:space:]]+.*(alternatives?|options|approaches|tradeoffs?|decisions?|considered|comparison)' "$plan_file" 2>/dev/null; then
    return 0
  fi

  cat >&2 <<EOF
[claude-optimizer] ExitPlanMode blocked by cm-multi-plan.
The current task was tagged \`[complexity: $complexity]\` but the plan file does not surface alternatives.
Plan file: $plan_file

Required: add a section with one of these canonical headings (case-insensitive, ##/### level):
  alternatives, options, approaches, tradeoffs, decisions, considered, comparison

Inside that section, list 2–3 distinct approaches with explicit pros/cons and mark the chosen one. The user's workflow: "show me two or three plans... we could pick and choose the best portions of each."

Then call ExitPlanMode again.

Bypasses (use sparingly, mention to the user):
- Set MULTI_PLAN_OFF=1 for the next ExitPlanMode call.
- Touch \`$ROOT/.claude/optimizer-disabled\` to disable the whole plugin.

This is a hard requirement under this project's claude-optimizer plugin contract.
EOF
  exit 2
}

check_research_first
check_multi_plan
exit 0
