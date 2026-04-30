#!/usr/bin/env bash
# claude-optimizer: initialise .claude/state/ with empty templates.
# Idempotent. Refuses to run outside a project directory. Never writes
# anywhere except $CLAUDE_PROJECT_DIR/.claude/state/.
set -euo pipefail

# Resolve project root. Prefer the env var Claude Code provides; fall back to PWD.
ROOT="${CLAUDE_PROJECT_DIR:-$PWD}"

# Refuse to run if ROOT is empty, the filesystem root, or $HOME itself.
case "$ROOT" in
  "" | "/" | "$HOME") echo "claude-optimizer: refusing to init in '$ROOT'" >&2; exit 1 ;;
esac

# Per-project opt-out: if the user dropped a sentinel file, skip everything silently.
if [ -f "$ROOT/.claude/optimizer-disabled" ]; then
  exit 0
fi

STATE="$ROOT/.claude/state"
mkdir -p "$STATE/archive"

write_if_missing() {
  local path="$1" header="$2"
  [ -f "$path" ] && return 0
  printf '%s\n' "$header" > "$path"
}

write_if_missing "$STATE/MEMORY.md"    "# Project Memory
Stable facts, conventions, and gotchas. Append-only. One line per entry.
Never write secrets, credentials, internal URLs, or customer data here."

write_if_missing "$STATE/DECISIONS.md" "# Decisions
One line per decision. Format: [YYYY-MM-DD] area: decision. Why: reason."

write_if_missing "$STATE/PROGRESS.md"  "# Progress Log
Newest first. One line per entry."

write_if_missing "$STATE/TASKS.md"     "# Tasks
One H2 section per task."

# Belt-and-braces: drop a .gitignore inside .claude/state itself, so the
# per-session counter and archive folder stay out of git even if the user
# forgets to update their top-level .gitignore.
if [ ! -f "$STATE/.gitignore" ]; then
  cat > "$STATE/.gitignore" <<'EOF'
# Per-session noise — never commit
.edit_count
archive/
EOF
fi

echo "claude-optimizer: state ready at $STATE" >&2
