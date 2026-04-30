#!/usr/bin/env bash
# claude-optimizer: append the gitignore snippet to a project's .gitignore.
# Idempotent. Refuses unsafe targets. Run once per project.
set -euo pipefail

target="${1:-$PWD}"

# Resolve to absolute path if it's a real directory, so the safety check
# below catches "." or relative paths that point at $HOME or /.
if [ -d "$target" ]; then
  target="$(cd "$target" && pwd)"
fi

case "$target" in
  "" | "/" | "$HOME")
    echo "claude-optimizer: refusing to install into '$target'" >&2
    exit 1
    ;;
esac

if [ ! -d "$target" ]; then
  echo "claude-optimizer: '$target' is not a directory" >&2
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SNIPPET="$SCRIPT_DIR/../templates/gitignore-snippet.txt"

if [ ! -f "$SNIPPET" ]; then
  echo "claude-optimizer: snippet not found at $SNIPPET" >&2
  exit 1
fi

GITIGNORE="$target/.gitignore"
MARKER="# --- claude-optimizer ---"

if [ -f "$GITIGNORE" ] && grep -qF "$MARKER" "$GITIGNORE"; then
  echo "claude-optimizer: snippet already present in $GITIGNORE — nothing to do"
  exit 0
fi

# Separate from any existing content with a blank line.
if [ -s "$GITIGNORE" ]; then
  printf '\n' >> "$GITIGNORE"
fi
cat "$SNIPPET" >> "$GITIGNORE"
echo "claude-optimizer: appended snippet to $GITIGNORE"
