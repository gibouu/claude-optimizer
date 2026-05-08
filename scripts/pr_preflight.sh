#!/usr/bin/env bash
# Runs before every Bash tool use. The plugin's PreToolUse(Bash) gate that
# enforces the issue-driven workflow at PR-creation time:
#
#   1. The command must contain `gh pr create` to be in scope. All other
#      Bash commands pass through immediately.
#   2. For non-trivial diffs (≥ 50 lines OR ≥ 2 files changed vs. main),
#      the command body must include `Closes #N` or `Refs #N` referencing
#      a real OPEN GitHub issue. Missing reference → block. Closed or
#      missing issue → block.
#   3. Scope-bloat heuristic: > 300 lines OR > 5 files → emit a warning
#      to stderr but allow the command (advisory, not enforcing).
#
# Block path: exit 2 + stderr message naming the rule and the bypass.
# Allow path: exit 0 (possibly with a stderr warning).
#
# Bypasses:
#   - $ROOT/.claude/optimizer-disabled        whole-plugin opt-out
#   - PR_PREFLIGHT_OFF=1                       one-off bypass
#
# Test escape hatches (not for production use):
#   - PR_PREFLIGHT_TEST_LINES=N                override diff line count
#   - PR_PREFLIGHT_TEST_FILES=N                override diff file count
#   - PR_PREFLIGHT_ISSUE_STATES="20:OPEN,..."  mock issue states (skip gh)
set -euo pipefail

ROOT="${CLAUDE_PROJECT_DIR:-$PWD}"

# Whole-plugin opt-out.
[ -f "$ROOT/.claude/optimizer-disabled" ] && exit 0

# One-off bypass.
[ "${PR_PREFLIGHT_OFF:-}" = "1" ] && exit 0

# Read the PreToolUse(Bash) JSON payload from stdin and extract the command.
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

# Filter: only `gh pr create` is in scope. Match the literal substring; the
# command may have any leading wrappers (env vars, cd, etc.).
case "$command_str" in
  *"gh pr create"*) ;;
  *) exit 0 ;;
esac

# ── Diff size measurement ───────────────────────────────────────────────
# Test escape hatch overrides win. Otherwise, query git for changes between
# the current branch and origin's default branch. Default to main if the
# default-branch query fails.
diff_lines=0
diff_files=0

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
  if command -v git >/dev/null 2>&1 && [ -n "${shortstat:-}" ]; then
    diff_files=$(printf '%s' "$shortstat" | { grep -oE '[0-9]+ files? changed' || true; } | head -1 | { grep -oE '[0-9]+' || true; })
    diff_files=${diff_files:-0}
  fi
fi

# Trivial-diff bypass: < 50 lines AND < 2 files → don't enforce Closes #N.
if [ "${diff_lines:-0}" -lt 50 ] && [ "${diff_files:-0}" -lt 2 ]; then
  exit 0
fi

# ── Closes/Refs reference parse ─────────────────────────────────────────
# Match `Closes #N` or `Refs #N` (case-insensitive) anywhere in the command
# (which includes any heredoc body). Issue numbers are 1+ digits.
issue_refs=$(printf '%s' "$command_str" | { grep -oiE '(closes|refs)[[:space:]]+#[0-9]+' || true; })

if [ -z "$issue_refs" ]; then
  cat >&2 <<EOF
[claude-optimizer] gh pr create blocked by pr-preflight.
Diff has ${diff_lines} insertions across ${diff_files} files (≥ trivial threshold) but the PR body has no \`Closes #N\` or \`Refs #N\` reference.

Required: every non-trivial PR closes (or refers to) a GitHub issue. The issue-driven workflow:
  1. file the issue first (\`gh issue create ...\`)
  2. branch off main
  3. fix
  4. PR with \`Closes #<N>\` (full closure) or \`Refs #<N>\` (partial)

Bypasses (use sparingly, mention to the user):
- Set PR_PREFLIGHT_OFF=1 for the next gh pr create call.
- Touch \`$ROOT/.claude/optimizer-disabled\` to disable the whole plugin.

This is a hard requirement under this project's claude-optimizer plugin contract.
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
    printf 'UNKNOWN'  # can't verify without gh; allow
  fi
}

# Iterate the matched references. For each, confirm the issue exists and is
# OPEN. Closed or missing → block.
seen_issues=""
for ref in $issue_refs; do
  num=$(printf '%s' "$ref" | { grep -oE '[0-9]+' || true; })
  [ -n "$num" ] || continue
  case " $seen_issues " in *" $num "*) continue ;; esac  # de-dup
  seen_issues="$seen_issues $num"
  state=$(issue_state "$num")
  case "$state" in
    OPEN|UNKNOWN) ;;
    CLOSED)
      cat >&2 <<EOF
[claude-optimizer] gh pr create blocked by pr-preflight.
The PR references issue #${num}, but it's already CLOSED. Either:
- File a new issue and update the PR body, or
- Bypass with PR_PREFLIGHT_OFF=1 if you genuinely want to reference a closed issue.
EOF
      exit 2
      ;;
    MISSING|*)
      cat >&2 <<EOF
[claude-optimizer] gh pr create blocked by pr-preflight.
The PR references issue #${num}, but no such issue exists in this repo. Either:
- Fix the typo in the PR body, or
- File the issue first (\`gh issue create\`).
EOF
      exit 2
      ;;
  esac
done

# ── Scope-bloat warning (advisory, not blocking) ────────────────────────
if [ "${diff_lines:-0}" -gt 300 ] || [ "${diff_files:-0}" -gt 5 ]; then
  cat >&2 <<EOF
[claude-optimizer] pr-preflight scope warning (allowing PR).
Diff is ${diff_lines} insertions across ${diff_files} files — wider than the typical single-issue PR (>300 lines / >5 files). Consider splitting if the changes touch unrelated subsystems.
EOF
fi

exit 0
