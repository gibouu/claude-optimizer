#!/usr/bin/env bash
# claude-optimizer: scan state files for likely secrets.
# Output goes to stdout (visible to Claude); exit code is always 0 so we
# never block a session. Conservative on purpose — false positives are fine,
# a leaked secret is not.
set -euo pipefail

ROOT="${CLAUDE_PROJECT_DIR:-$PWD}"
STATE="$ROOT/.claude/state"
[ -d "$STATE" ] || exit 0

# Patterns covering the most common credential formats. Add to taste.
# Each line: a regex; matches are reported but not printed verbatim.
PATTERNS=(
  'sk-[A-Za-z0-9_-]{20,}'                # OpenAI / Anthropic-style keys
  'sk_live_[A-Za-z0-9]{16,}'             # Stripe live
  'sk_test_[A-Za-z0-9]{16,}'             # Stripe test
  'AKIA[0-9A-Z]{16}'                     # AWS access key id
  'ghp_[A-Za-z0-9]{36}'                  # GitHub personal access token
  'github_pat_[A-Za-z0-9_]{20,}'         # GitHub fine-grained PAT
  'xox[baprs]-[A-Za-z0-9-]{10,}'         # Slack tokens
  'AIza[0-9A-Za-z_-]{35}'                # Google API
  'eyJ[A-Za-z0-9_-]{20,}\.[A-Za-z0-9_-]{20,}\.[A-Za-z0-9_-]{20,}' # JWT (3 segments)
  '-----BEGIN [A-Z ]*PRIVATE KEY-----'   # Any private key block
  'postgres://[^[:space:]]*:[^[:space:]]*@'  # Postgres URL with password
  'mongodb(\+srv)?://[^[:space:]]*:[^[:space:]]*@'  # Mongo URL with password
  'mysql://[^[:space:]]*:[^[:space:]]*@'  # MySQL URL with password
)

found=0
for f in "$STATE/MEMORY.md" "$STATE/DECISIONS.md" "$STATE/PROGRESS.md" "$STATE/TASKS.md"; do
  [ -f "$f" ] || continue
  for pat in "${PATTERNS[@]}"; do
    if grep -aEq "$pat" "$f" 2>/dev/null; then
      basename=$(basename "$f")
      echo "[claude-optimizer] WARNING: $basename appears to contain a secret matching pattern: ${pat:0:30}..."
      echo "[claude-optimizer] Review .claude/state/$basename and rotate the credential if real. Do NOT commit until cleaned."
      found=1
    fi
  done
done

[ "$found" -eq 0 ] || echo "[claude-optimizer] One or more state files flagged. Treat as if a real secret leaked until proven otherwise."

exit 0
