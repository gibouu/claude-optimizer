#!/usr/bin/env bash
# Runs after every Write/Edit/MultiEdit tool use.
# Three jobs: (1) scan state files for secrets, (2) auto-append a one-line
# entry to PROGRESS.md so state actually accrues without depending on the
# model invoking cm-checkpoint, (3) nudge Claude to checkpoint every 10 edits.
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
    tool=$(printf '%s' "$PAYLOAD" | grep -o '"tool_name"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | sed 's/.*:[[:space:]]*"\([^"]*\)".*/\1/')
    file=$(printf '%s' "$PAYLOAD" | grep -o '"file_path"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | sed 's/.*:[[:space:]]*"\([^"]*\)".*/\1/')
  fi

  [ -n "$file" ] || return 0
  [ -n "$tool" ] || tool="edit"

  local rel="$file"
  case "$file" in
    "$ROOT"/*) rel="${file#"$ROOT"/}" ;;
  esac
  rel=$(printf '%s' "$rel" | tr -d '\000-\037')
  tool=$(printf '%s' "$tool" | tr -d '\000-\037')

  local entry
  entry="[$(date '+%Y-%m-%d %H:%M')] ${tool}: ${rel}"

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

# R6: prune PROGRESS.md when it grows past header + 100 entries. Archive
# overflow into .claude/state/archive/PROGRESS-YYYYMM.md so older entries
# are retrievable but don't bloat the active file (which cm-session-resume
# reads on every session).
prune_progress() {
  local progress="$STATE_DIR/PROGRESS.md"
  [ -f "$progress" ] || return 0

  local lines
  lines=$(wc -l < "$progress" 2>/dev/null | tr -d ' ' || echo 0)
  # Header is 2 lines; keep the 100 newest entries.
  [ "${lines:-0}" -le 102 ] && return 0

  local archive_dir="$STATE_DIR/archive"
  mkdir -p "$archive_dir" 2>/dev/null || return 0
  local month archive_file
  month=$(date '+%Y%m' 2>/dev/null || echo "unknown")
  archive_file="$archive_dir/PROGRESS-${month}.md"

  # Append overflow (oldest entries — lines 103 onwards) to the archive.
  {
    [ -f "$archive_file" ] && cat "$archive_file"
    printf '\n## Archived %s\n' "$(date '+%Y-%m-%d %H:%M' 2>/dev/null || echo unknown)"
    tail -n +103 "$progress"
  } > "${archive_file}.tmp" 2>/dev/null && mv "${archive_file}.tmp" "$archive_file" 2>/dev/null

  # Truncate PROGRESS.md to header + 100 newest.
  head -n 102 "$progress" > "${progress}.tmp" 2>/dev/null && mv "${progress}.tmp" "$progress" 2>/dev/null
}
prune_progress || true

# 3) Edit-counter reminder.
COUNT_FILE="$STATE_DIR/.edit_count"
COUNT=$(cat "$COUNT_FILE" 2>/dev/null || echo 0)
COUNT=$((COUNT + 1))
echo "$COUNT" > "$COUNT_FILE"

if (( COUNT % 10 == 0 )); then
  echo "[claude-optimizer] $COUNT edits this session — append to PROGRESS.md and tick TASKS.md before continuing."
fi
