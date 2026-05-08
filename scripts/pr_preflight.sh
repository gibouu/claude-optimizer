#!/usr/bin/env bash
# PreToolUse(Bash) gate. Enforces the issue-driven workflow at PR-creation
# time. Fires on every Bash command but exits silently unless the command
# contains `gh pr create`.
#
# Bypasses:
#   $ROOT/.claude/optimizer-disabled        whole-plugin opt-out
#   PR_PREFLIGHT_OFF=1                       one-off bypass
#
# Test escape hatches (not for production):
#   PR_PREFLIGHT_TEST_LINES, PR_PREFLIGHT_TEST_FILES, PR_PREFLIGHT_ISSUE_STATES
set -euo pipefail

ROOT="${CLAUDE_PROJECT_DIR:-$PWD}"
STATE_DIR="$ROOT/.claude/state"

[ -f "$ROOT/.claude/optimizer-disabled" ] && exit 0
[ "${PR_PREFLIGHT_OFF:-}" = "1" ] && exit 0

PAYLOAD="$(cat 2>/dev/null || true)"
[ -n "$PAYLOAD" ] || exit 0

command_str=""
if command -v jq >/dev/null 2>&1; then
  command_str=$(printf '%s' "$PAYLOAD" | jq -r '.tool_input.command // empty' 2>/dev/null || true)
fi
if [ -z "$command_str" ]; then
  command_str=$(printf '%s' "$PAYLOAD" | sed -n 's/.*"command"[[:space:]]*:[[:space:]]*"\(.*\)".*/\1/p' | head -1)
fi
[ -n "$command_str" ] || exit 0

case "$command_str" in
  *"gh pr create"*) ;;
  *) exit 0 ;;
esac

# R3-write helper: record blocks for prompt_submit's retry-context injection.
record_block() {
  [ -d "$STATE_DIR" ] || return 0
  local file="$STATE_DIR/.recent_blocks"
  printf '%s: %s\n' "$1" "$2" >> "$file" 2>/dev/null || true
  if [ -f "$file" ]; then
    tail -3 "$file" > "${file}.tmp" 2>/dev/null && mv "${file}.tmp" "$file" 2>/dev/null || true
  fi
}

# ── Diff size measurement ───────────────────────────────────────────────
diff_lines=0
diff_files=0
shortstat=""

if [ -n "${PR_PREFLIGHT_TEST_LINES:-}" ]; then
  diff_lines="$PR_PREFLIGHT_TEST_LINES"
else
  if command -v git >/dev/null 2>&1; then
    main_branch=$(git -C "$ROOT" symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@' || true)
    [ -n "$main_branch" ] || main_branch="main"
    shortstat=$(git -C "$ROOT" diff --shortstat "${main_branch}...HEAD" 2>/dev/null || true)
    if [ -n "$shortstat" ]; then
      diff_lines=$(printf '%s' "$shortstat" | { grep -oE '[0-9]+ insertion' || true; } | head -1 | { grep -oE '[0-9]+' || true; })
      diff_lines=${diff_lines:-0}
    fi
  fi
fi

if [ -n "${PR_PREFLIGHT_TEST_FILES:-}" ]; then
  diff_files="$PR_PREFLIGHT_TEST_FILES"
else
  if [ -n "$shortstat" ]; then
    diff_files=$(printf '%s' "$shortstat" | { grep -oE '[0-9]+ files? changed' || true; } | head -1 | { grep -oE '[0-9]+' || true; })
    diff_files=${diff_files:-0}
  fi
fi

# Trivial-diff bypass.
if [ "${diff_lines:-0}" -lt 50 ] && [ "${diff_files:-0}" -lt 2 ]; then
  exit 0
fi

# ── Closes/Refs reference parse ─────────────────────────────────────────
issue_refs=$(printf '%s' "$command_str" | { grep -oiE '(closes|refs)[[:space:]]+#[0-9]+' || true; })

if [ -z "$issue_refs" ]; then
  record_block "pr_preflight" "no Closes #N on ${diff_lines}-line / ${diff_files}-file diff"
  cat >&2 <<EOF
[claude-optimizer] gh pr create blocked: pr-preflight.
${diff_lines} insertions / ${diff_files} files but no \`Closes #N\` or \`Refs #N\` in PR body. File the issue first, then add Closes #N.
Bypass: PR_PREFLIGHT_OFF=1 or .claude/optimizer-disabled.
EOF
  exit 2
fi

# ── Issue existence + state check ───────────────────────────────────────
issue_state() {
  local n="$1"
  if [ -n "${PR_PREFLIGHT_ISSUE_STATES:-}" ]; then
    local entry
    for entry in $(printf '%s' "$PR_PREFLIGHT_ISSUE_STATES" | tr ',' ' '); do
      case "$entry" in
        "$n:"*) printf '%s' "${entry#*:}"; return 0 ;;
      esac
    done
    printf 'MISSING'
    return 0
  fi
  if command -v gh >/dev/null 2>&1; then
    gh issue view "$n" --json state -q '.state' 2>/dev/null || printf 'MISSING'
  else
    printf 'UNKNOWN'
  fi
}

seen_issues=""
for ref in $issue_refs; do
  num=$(printf '%s' "$ref" | { grep -oE '[0-9]+' || true; })
  [ -n "$num" ] || continue
  case " $seen_issues " in *" $num "*) continue ;; esac
  seen_issues="$seen_issues $num"
  state=$(issue_state "$num")
  case "$state" in
    OPEN|UNKNOWN) ;;
    CLOSED)
      record_block "pr_preflight" "referenced issue #${num} is CLOSED"
      cat >&2 <<EOF
[claude-optimizer] gh pr create blocked: issue #${num} is already CLOSED. File a new issue or set PR_PREFLIGHT_OFF=1.
EOF
      exit 2
      ;;
    MISSING|*)
      record_block "pr_preflight" "referenced issue #${num} not found"
      cat >&2 <<EOF
[claude-optimizer] gh pr create blocked: issue #${num} doesn't exist. Fix the typo or file the issue first.
EOF
      exit 2
      ;;
  esac
done

# Scope-bloat warning (advisory).
if [ "${diff_lines:-0}" -gt 300 ] || [ "${diff_files:-0}" -gt 5 ]; then
  echo "[claude-optimizer] pr-preflight scope warning: ${diff_lines} insertions / ${diff_files} files. Consider splitting." >&2
fi

exit 0
