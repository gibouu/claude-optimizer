#!/usr/bin/env bash
# Test runner for scripts/prompt_submit.sh.
#
# Pipes fixture JSON through the hook and diffs stdout against expected.txt.
# No BATS dependency — pure bash, runs anywhere the plugin runs.
#
# Usage:
#   bash tests/test_prompt_submit.sh
#
# Fixture layout: tests/fixtures/prompt_submit/<case>/
#   input.json     JSON payload for UserPromptSubmit (e.g. {"prompt": "..."})
#   expected.txt   exact stdout the hook should emit (may be empty)
#   setup.sh       optional; sourced before the hook runs. Receives:
#                    PROJ_DIR  the per-case CLAUDE_PROJECT_DIR sandbox
#                    CASE_DIR  the fixture directory (for reading aux files)
#                  setup.sh may write state files into $PROJ_DIR/.claude/state/
#                  and `export` env vars (e.g. PATH manipulation for jq masking).
#
# Exit: 0 if all cases pass, 1 otherwise.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
HOOK="$REPO_ROOT/scripts/prompt_submit.sh"
FIXTURES="$SCRIPT_DIR/fixtures/prompt_submit"

[ -d "$FIXTURES" ] || { echo "fixtures dir missing: $FIXTURES" >&2; exit 1; }
[ -f "$HOOK" ] || { echo "hook script missing: $HOOK" >&2; exit 1; }

passed=0
failed=0
fail_names=()

echo "Running prompt_submit fixtures from: $FIXTURES"
echo

for case_dir in "$FIXTURES"/*/; do
  [ -d "$case_dir" ] || continue
  case_dir="${case_dir%/}"
  name="$(basename "$case_dir")"
  input="$case_dir/input.json"
  expected="$case_dir/expected.txt"
  setup="$case_dir/setup.sh"

  if [ ! -f "$input" ] || [ ! -f "$expected" ]; then
    printf '  SKIP %s (missing fixture files)\n' "$name"
    continue
  fi

  tmpdir=$(mktemp -d)
  mkdir -p "$tmpdir/.claude/state"

  saved_path="$PATH"

  if [ -f "$setup" ]; then
    # shellcheck disable=SC1090
    CASE_DIR="$case_dir" PROJ_DIR="$tmpdir" . "$setup"
  fi

  actual=$(CLAUDE_PROJECT_DIR="$tmpdir" bash "$HOOK" < "$input" 2>/dev/null || true)
  expected_content=$(cat "$expected")

  PATH="$saved_path"

  if [ "$actual" = "$expected_content" ]; then
    passed=$((passed + 1))
    printf '  PASS %s\n' "$name"
  else
    failed=$((failed + 1))
    fail_names+=("$name")
    printf '  FAIL %s\n' "$name"
    diff <(printf '%s\n' "$expected_content") <(printf '%s\n' "$actual") | sed 's/^/      /' || true
  fi

  rm -rf "$tmpdir"
done

echo
printf 'passed: %d   failed: %d\n' "$passed" "$failed"
if [ "$failed" -gt 0 ]; then
  printf 'failed cases: %s\n' "${fail_names[*]}"
  exit 1
fi
