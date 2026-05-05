#!/usr/bin/env bash
# Runs after every Write/Edit/MultiEdit tool use.
# Three jobs: (1) scan state files for secrets, (2) auto-append a one-line
# entry to PROGRESS.md so state actually accrues without depending on the
# model invoking cm-memory, (3) nudge Claude to checkpoint every 10 edits.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="${CLAUDE_PROJECT_DIR:-$PWD}"
STATE_DIR="$ROOT/.claude/state"
mkdir -p "$STATE_DIR"

# Capture stdin first — the hook payload (tool_name, tool_input, ...) is on
# stdin and we want it for the progress log. cat won't fail on empty input.
PAYLOAD="$(cat 2>/dev/null || true)"

# 1) Secret scan — non-blocking, prints warnings if anything looks bad.
"$SCRIPT_DIR/scan_secrets.sh" || true

# 2) Auto-append a progress entry. Best-effort: never fail the hook, since a
#    logging glitch must not block the user's edit flow.
append_progress_entry() {
  local progress="$STATE_DIR/PROGRESS.md"
  [ -f "$progress" ] || return 0
  [ -n "$PAYLOAD" ] || return 0

  local tool="" file=""
  if command -v jq >/dev/null 2>&1; then
    tool=$(printf '%s' "$PAYLOAD" | jq -r '.tool_name // empty' 2>/dev/null || true)
    file=$(printf '%s' "$PAYLOAD" | jq -r '.tool_input.file_path // empty' 2>/dev/null || true)
  else
    # Fallback parser. Adequate for typical paths; gives up on weird escapes.
    tool=$(printf '%s' "$PAYLOAD" | grep -o '"tool_name"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | sed 's/.*:[[:space:]]*"\([^"]*\)".*/\1/')
    file=$(printf '%s' "$PAYLOAD" | grep -o '"file_path"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | sed 's/.*:[[:space:]]*"\([^"]*\)".*/\1/')
  fi

  [ -n "$file" ] || return 0
  [ -n "$tool" ] || tool="edit"

  # Make path relative to project root when possible.
  local rel="$file"
  case "$file" in
    "$ROOT"/*) rel="${file#"$ROOT"/}" ;;
  esac

  # Strip control characters from the components we splice into the file.
  rel=$(printf '%s' "$rel" | tr -d '\000-\037')
  tool=$(printf '%s' "$tool" | tr -d '\000-\037')

  local entry
  entry="[$(date '+%Y-%m-%d %H:%M')] ${tool}: ${rel}"

  # Insert as line 3 — newest first, just below the two-line header. If the
  # file is shorter than the seed, just append.
  local lines
  lines=$(wc -l < "$progress" | tr -d ' ')
  local tmp="$progress.tmp.$$"
  if [ "${lines:-0}" -ge 2 ]; then
    {
      head -n 2 "$progress"
      printf '%s\n' "$entry"
      tail -n +3 "$progress"
    } > "$tmp" && mv "$tmp" "$progress"
  else
    printf '%s\n' "$entry" >> "$progress"
  fi
}
append_progress_entry || true

# 3) Edit-counter reminder.
COUNT_FILE="$STATE_DIR/.edit_count"
COUNT=$(cat "$COUNT_FILE" 2>/dev/null || echo 0)
COUNT=$((COUNT + 1))
echo "$COUNT" > "$COUNT_FILE"

if (( COUNT % 10 == 0 )); then
  echo "[claude-optimizer] $COUNT edits this session — append to PROGRESS.md and tick TASKS.md before continuing."
fi
