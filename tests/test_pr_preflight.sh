#!/usr/bin/env bash
# Test runner for scripts/pr_preflight.sh — the PR-creation gate.
#
# Each fixture provides a synthetic PreToolUse(Bash) JSON payload, optional
# setup, and asserts on exit code + optional stderr substring.
#
# Usage: bash tests/test_pr_preflight.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
HOOK="$REPO_ROOT/scripts/pr_preflight.sh"
FIXTURES="$SCRIPT_DIR/fixtures/pr_preflight"

[ -d "$FIXTURES" ] || { echo "fixtures dir missing: $FIXTURES" >&2; exit 1; }
[ -f "$HOOK" ] || { echo "hook script missing: $HOOK" >&2; exit 1; }

passed=0
failed=0
fail_names=()

# Save baseline env so we can restore between cases.
saved_off="${PR_PREFLIGHT_OFF:-__UNSET__}"
saved_lines="${PR_PREFLIGHT_TEST_LINES:-__UNSET__}"
saved_files="${PR_PREFLIGHT_TEST_FILES:-__UNSET__}"
saved_states="${PR_PREFLIGHT_ISSUE_STATES:-__UNSET__}"

restore_env() {
  for pair in "PR_PREFLIGHT_OFF:$saved_off" "PR_PREFLIGHT_TEST_LINES:$saved_lines" "PR_PREFLIGHT_TEST_FILES:$saved_files" "PR_PREFLIGHT_ISSUE_STATES:$saved_states"; do
    var="${pair%%:*}"
    val="${pair#*:}"
    if [ "$val" = "__UNSET__" ]; then
      unset "$var"
    else
      export "$var"="$val"
    fi
  done
}

reset_env() {
  unset PR_PREFLIGHT_OFF PR_PREFLIGHT_TEST_LINES PR_PREFLIGHT_TEST_FILES PR_PREFLIGHT_ISSUE_STATES
}

echo "Running pr_preflight fixtures from: $FIXTURES"
echo

for case_dir in "$FIXTURES"/*/; do
  [ -d "$case_dir" ] || continue
  case_dir="${case_dir%/}"
  name="$(basename "$case_dir")"
  input="$case_dir/input.json"
  expected_exit_file="$case_dir/expected_exit"
  expected_stderr_file="$case_dir/expected_stderr_contains"
  setup="$case_dir/setup.sh"

  if [ ! -f "$input" ] || [ ! -f "$expected_exit_file" ]; then
    printf '  SKIP %s (missing fixture files)\n' "$name"
    continue
  fi

  tmpdir=$(mktemp -d)
  reset_env

  if [ -f "$setup" ]; then
    # shellcheck disable=SC1090
    CASE_DIR="$case_dir" PROJ_DIR="$tmpdir" . "$setup"
  fi

  stderr_capture=$(mktemp)
  set +e
  CLAUDE_PROJECT_DIR="$tmpdir" bash "$HOOK" < "$input" 2>"$stderr_capture" >/dev/null
  actual_exit=$?
  set -e
  actual_stderr=$(cat "$stderr_capture")
  rm -f "$stderr_capture"

  expected_exit=$(cat "$expected_exit_file" | tr -d '[:space:]')
  ok=1
  if [ "$actual_exit" != "$expected_exit" ]; then
    ok=0
  fi
  if [ -f "$expected_stderr_file" ]; then
    expected_substr=$(cat "$expected_stderr_file")
    if ! printf '%s' "$actual_stderr" | grep -qF -- "$expected_substr"; then
      ok=0
    fi
  fi

  if [ "$ok" = "1" ]; then
    passed=$((passed + 1))
    printf '  PASS %s\n' "$name"
  else
    failed=$((failed + 1))
    fail_names+=("$name")
    printf '  FAIL %s (expected exit=%s, got=%s)\n' "$name" "$expected_exit" "$actual_exit"
    if [ -n "$actual_stderr" ]; then
      printf '    --- stderr ---\n'
      printf '%s\n' "$actual_stderr" | head -c 500 | sed 's/^/    /'
    fi
  fi

  rm -rf "$tmpdir"
done

restore_env

echo
printf 'passed: %d   failed: %d\n' "$passed" "$failed"
if [ "$failed" -gt 0 ]; then
  printf 'failed cases: %s\n' "${fail_names[*]}"
  exit 1
fi
