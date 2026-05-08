#!/usr/bin/env bash
# PreToolUse(ExitPlanMode) gate. Runs the plugin's plan-finalisation checks
# in sequence; first to block wins.
#
# Checks:
#   1. cm-research-first  — complex prompt + no WebSearch this turn → block.
#   2. cm-multi-plan      — moderate/complex prompt + plan file lacks
#                            alternatives heading → block.
#
# Bypasses:
#   $ROOT/.claude/optimizer-disabled  whole-plugin opt-out
#   RESEARCH_FIRST_OFF=1               skips check 1
#   MULTI_PLAN_OFF=1                   skips check 2
set -euo pipefail

ROOT="${CLAUDE_PROJECT_DIR:-$PWD}"
STATE_DIR="$ROOT/.claude/state"

[ -f "$ROOT/.claude/optimizer-disabled" ] && exit 0
[ -d "$STATE_DIR" ] || exit 0

COMPLEXITY_FILE="$STATE_DIR/.last_prompt_complexity"
WEBSEARCH_MARKER="$STATE_DIR/.websearch_this_turn"

[ -f "$COMPLEXITY_FILE" ] || exit 0
complexity="$(cat "$COMPLEXITY_FILE" 2>/dev/null || echo)"

# Append a one-line block record (FIFO last 3) so prompt_submit.sh can
# surface it when the user retries.
record_block() {
  local file="$STATE_DIR/.recent_blocks"
  printf '%s: %s\n' "$1" "$2" >> "$file" 2>/dev/null || true
  if [ -f "$file" ]; then
    tail -3 "$file" > "${file}.tmp" 2>/dev/null && mv "${file}.tmp" "$file" 2>/dev/null || true
  fi
}

check_research_first() {
  [ "${RESEARCH_FIRST_OFF:-}" = "1" ] && return 0
  case "$complexity" in
    complex) ;;
    *) return 0 ;;
  esac
  [ -f "$WEBSEARCH_MARKER" ] && return 0

  record_block "research-first" "complex task with no WebSearch this turn"
  cat >&2 <<EOF
[claude-optimizer] ExitPlanMode blocked: cm-research-first.
Complex task without WebSearch this turn. Run WebSearch (topic + "best practices 2026"), cite in plan, retry.
Bypass: RESEARCH_FIRST_OFF=1 or .claude/optimizer-disabled.
EOF
  exit 2
}

check_multi_plan() {
  [ "${MULTI_PLAN_OFF:-}" = "1" ] && return 0
  case "$complexity" in
    moderate|complex) ;;
    *) return 0 ;;
  esac

  local plans_dir="$HOME/.claude/plans"
  [ -d "$plans_dir" ] || return 0

  local plan_file="" f mtime now newest_mtime=0
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

  if [ "$now" -gt 0 ] && [ "$newest_mtime" -gt 0 ]; then
    [ $((now - newest_mtime)) -gt 3600 ] && return 0
  fi

  local lines
  lines=$(wc -l < "$plan_file" 2>/dev/null | tr -d ' ' || echo 0)
  [ "${lines:-0}" -lt 30 ] && return 0

  if grep -qiE '^#{1,3}[[:space:]]+.*(alternatives?|options|approaches|tradeoffs?|decisions?|considered|comparison)' "$plan_file" 2>/dev/null; then
    return 0
  fi

  record_block "multi-plan" "plan lacks alternatives/tradeoffs/decisions section"
  cat >&2 <<EOF
[claude-optimizer] ExitPlanMode blocked: cm-multi-plan.
Plan lacks an Alternatives/Tradeoffs/Decisions/Approaches heading. Add 2-3 approaches with pros/cons, mark chosen, retry.
Plan: $plan_file
Bypass: MULTI_PLAN_OFF=1 or .claude/optimizer-disabled.
EOF
  exit 2
}

check_research_first
check_multi_plan
exit 0
