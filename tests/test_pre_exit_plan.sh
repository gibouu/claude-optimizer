#!/usr/bin/env bash
# Test runner for scripts/pre_exit_plan.sh — the cm-research-first gate.
#
# Each fixture seeds state files (via setup.sh), runs the hook with empty
# stdin, and asserts on exit code and optional stderr substring.
#
# Usage: bash tests/test_pre_exit_plan.sh
#
# Fixture layout: tests/fixtures/pre_exit_plan/<case>/
#   expected_exit              required — "0" (allow) or "2" (block)
#   expected_stderr_contains   optional — substring that must appear in stderr
#   setup.sh                   optional — sourced before the hook runs.
#                              Receives PROJ_DIR (tmpdir = CLAUDE_PROJECT_DIR)
#                              and CASE_DIR.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
HOOK="$REPO_ROOT/scripts/pre_exit_plan.sh"
FIXTURES="$SCRIPT_DIR/fixtures/pre_exit_plan"

[ -d "$FIXTURES" ] || { echo "fixtures dir missing: $FIXTURES" >&2; exit 1; }
[ -f "$HOOK" ] || { echo "hook script missing: $HOOK" >&2; exit 1; }

passed=0
failed=0
fail_names=()

echo "Running pre_exit_plan fixtures from: $FIXTURES"
echo

for case_dir in "$FIXTURES"/*/; do
  [ -d "$case_dir" ] || continue
  case_dir="${case_dir%/}"
  name="$(basename "$case_dir")"
  setup="$case_dir/setup.sh"
  expected_exit_file="$case_dir/expected_exit"
  expected_stderr_file="$case_dir/expected_stderr_contains"

  [ -f "$expected_exit_file" ] || { printf '  SKIP %s (no expected_exit)\n' "$name"; continue; }

  tmpdir=$(mktemp -d)
  mkdir -p "$tmpdir/.claude/state" "$tmpdir/.claude/plans"

  saved_path="$PATH"
  saved_home="$HOME"
  saved_research_off="${RESEARCH_FIRST_OFF:-__UNSET__}"
  saved_multi_plan_off="${MULTI_PLAN_OFF:-__UNSET__}"

  # Isolate $HOME so the multi-plan gate's $HOME/.claude/plans lookup hits
  # the tmpdir, not the developer's real plans directory.
  export HOME="$tmpdir"

  if [ -f "$setup" ]; then
    # shellcheck disable=SC1090
    CASE_DIR="$case_dir" PROJ_DIR="$tmpdir" . "$setup"
  fi

  stderr_capture=$(mktemp)
  set +e
  CLAUDE_PROJECT_DIR="$tmpdir" HOME="$tmpdir" bash "$HOOK" </dev/null 2>"$stderr_capture" >/dev/null
  actual_exit=$?
  set -e
  actual_stderr=$(cat "$stderr_capture")
  rm -f "$stderr_capture"

  PATH="$saved_path"
  export HOME="$saved_home"
  if [ "$saved_research_off" = "__UNSET__" ]; then
    unset RESEARCH_FIRST_OFF
  else
    export RESEARCH_FIRST_OFF="$saved_research_off"
  fi
  if [ "$saved_multi_plan_off" = "__UNSET__" ]; then
    unset MULTI_PLAN_OFF
  else
    export MULTI_PLAN_OFF="$saved_multi_plan_off"
  fi

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
      printf '%s\n' "$actual_stderr" | head -c 400 | sed 's/^/    /'
    fi
  fi

  rm -rf "$tmpdir"
done

echo
printf 'passed: %d   failed: %d\n' "$passed" "$failed"
if [ "$failed" -gt 0 ]; then
  printf 'failed cases: %s\n' "${fail_names[*]}"
  exit 1
fi
