#!/usr/bin/env bash
# Runs before each user prompt is dispatched to the model.
#
# Two jobs:
#   1. State-checkpoint enforcement — when the project's edit counter shows
#      accumulated work without a corresponding state checkpoint, emit an
#      "additional context" block instructing Claude to invoke cm-checkpoint
#      / cm-task-tracker / cm-memory before responding.
#   2. Issue-driven-workflow enforcement — when the user's prompt looks like
#      a conversational request ("I want X", "we should Y") rather than a
#      precise instruction, emit a directive instructing Claude to invoke
#      cm-issue-driven-workflow (clarify → file issue → branch → fix → PR).
#
# UserPromptSubmit hooks send stdout to the model as inline context, which
# is much harder to ignore than stderr nags. Both blocks share stdout and
# concatenate naturally when both fire on the same prompt.
#
# Never blocks. Logging-only failure modes are swallowed — a parse error
# must not crash the prompt path.
set -euo pipefail

ROOT="${CLAUDE_PROJECT_DIR:-$PWD}"
STATE_DIR="$ROOT/.claude/state"

# Per-project opt-out — silent pass-through.
[ -f "$ROOT/.claude/optimizer-disabled" ] && exit 0

# State must exist; if not, session_start.sh hasn't seeded yet.
[ -d "$STATE_DIR" ] || exit 0

# Capture stdin once — both blocks may consume the UserPromptSubmit JSON
# payload (which includes the user's prompt text).
PAYLOAD="$(cat 2>/dev/null || true)"

# ── Block 1: edit-count state-checkpoint enforcement ────────────────────
COUNT_FILE="$STATE_DIR/.edit_count"
LAST_FILE="$STATE_DIR/.last_directive_count"

read_int() {
  local v
  v="$(cat "$1" 2>/dev/null || echo 0)"
  case "$v" in ''|*[!0-9]*) echo 0 ;; *) echo "$v" ;; esac
}

COUNT="$(read_int "$COUNT_FILE")"
LAST="$(read_int "$LAST_FILE")"

# Defensive rollover: if LAST is somehow ahead of COUNT (e.g. stale file
# survived a session reset), treat as fresh.
if [ "$LAST" -gt "$COUNT" ]; then
  LAST=0
fi

# Cadence: fire on each new positive multiple of 5 edits. The LAST<COUNT
# guard prevents repeat-firing on prompts that arrive without intervening
# edits.
if [ "$COUNT" -ge 5 ] && [ $((COUNT % 5)) -eq 0 ] && [ "$LAST" -lt "$COUNT" ]; then
  echo "$COUNT" > "$LAST_FILE" || true
  cat <<EOF
[claude-optimizer] State checkpoint required.
You have made $COUNT edits this session without a state write. Before responding to the user's prompt:
- Invoke cm-checkpoint to atomically update PROGRESS.md / TASKS.md / DECISIONS.md / MEMORY.md as warranted (the bundled skill — preferred).
- Or, if you only need to touch one file, invoke cm-task-tracker (TASKS.md) or cm-memory (PROGRESS / DECISIONS / MEMORY) directly.
This is a hard requirement under this project's claude-optimizer plugin contract. Do this BEFORE addressing the user's prompt; do not skip or defer.
EOF
fi

# ── Block 2: issue-driven-workflow enforcement ──────────────────────────
# Extract the user's prompt from the UserPromptSubmit JSON payload.
# Prefer jq; fall back to sed for environments without jq. Silent failure.
extract_prompt() {
  local p=""
  if command -v jq >/dev/null 2>&1; then
    p=$(printf '%s' "$PAYLOAD" | jq -r '.prompt // empty' 2>/dev/null || true)
  fi
  if [ -z "$p" ] && [ -n "$PAYLOAD" ]; then
    p=$(printf '%s' "$PAYLOAD" | sed -n 's/.*"prompt"[[:space:]]*:[[:space:]]*"\(.*\)".*/\1/p' | head -1)
  fi
  printf '%s' "$p"
}

prompt="$(extract_prompt)"
[ -n "$prompt" ] || exit 0

# Lower-case once for all subsequent regex matching.
lc=$(printf '%s' "$prompt" | tr '[:upper:]' '[:lower:]')

# Off-ramp regex — if any of these match, skip the directive entirely.
# Covers: explicit overrides ("just", "quick fix"), file:line citations,
# direct rename/delete imperatives, nits and typo fixes.
OFFRAMP_RE='(^|[^a-z])(just |quick fix|small thing|skip the issue|no pr|no issue|nit:|typo)|[a-z_./-]+\.[a-z]+:[0-9]+|^(rename|delete|remove) [a-z_`]'

if [[ "$lc" =~ $OFFRAMP_RE ]]; then
  exit 0
fi

# Trigger regex — conversational request openers. Apostrophes are matched
# with `.?` to tolerate both "i'd" and "id" without bash-quoting headaches.
TRIGGER_RE='(^|[^a-z])(i want|i.?d like|we should|we need|let.?s (add|build|make|create|fix|refactor)|how do i|why (doesn.?t|is|does)|can you (add|make|fix|build|implement|refactor)|this is (broken|annoying|slow|confusing)|feature request|the proper way|standard practice|should we|what if we|wouldn.?t it be)'

if [[ ! "$lc" =~ $TRIGGER_RE ]]; then
  exit 0
fi

# Cooldown: SHA-1 fingerprint of the matched prompt. Identical re-presses
# (same prompt twice in a row) suppress; a different trigger phrase
# re-arms naturally. Cleared by session_end.sh.
fp=""
if command -v shasum >/dev/null 2>&1; then
  fp=$(printf '%s' "$prompt" | shasum 2>/dev/null | cut -c1-12)
elif command -v sha1sum >/dev/null 2>&1; then
  fp=$(printf '%s' "$prompt" | sha1sum 2>/dev/null | cut -c1-12)
fi

if [ -n "$fp" ]; then
  FP_FILE="$STATE_DIR/.last_intent_fingerprint"
  if [ "$(cat "$FP_FILE" 2>/dev/null || true)" = "$fp" ]; then
    exit 0
  fi
  echo "$fp" > "$FP_FILE" 2>/dev/null || true
fi

# Complexity classifier. First match wins; default is `moderate`.
COMPLEX_KW='refactor|architect|migrate|redesign|cross-cutting|breaking change|multi-(file|repo|service)|integrat(e|ion)|orchestrat|plumb|end-to-end|backfill'
len=${#prompt}
words=$(printf '%s' "$prompt" | wc -w | tr -d ' ')
file_mentions=$(printf '%s' "$prompt" | { grep -oE '[a-zA-Z_./-]+\.(sh|ts|js|tsx|jsx|py|md|json|yaml|yml|rb|go|rs|css|html|sql)' 2>/dev/null || true; } | wc -l | tr -d ' ')
file_mentions=${file_mentions:-0}

complexity="moderate"
if [[ "$lc" =~ $COMPLEX_KW ]] || [ "${words:-0}" -gt 60 ] || [ "$file_mentions" -ge 3 ]; then
  complexity="complex"
elif [ "$len" -lt 80 ] && [ "$file_mentions" -le 1 ]; then
  complexity="simple"
fi

cat <<EOF
[claude-optimizer] Issue-driven workflow required.
The user's prompt looks like a conversational request rather than a precise instruction. [complexity: $complexity]
Before responding:
- Invoke cm-issue-driven-workflow to refine the request, file a GitHub issue, branch, fix, and open a PR with \`Closes #<N>\`.
- If the prompt is genuinely a one-line precise edit, an off-ramp question, or out of scope (no GitHub remote, ≤10-line single-file fix), say so explicitly in one sentence and proceed without ceremony — do not silently skip.
This is a hard requirement under this project's claude-optimizer plugin contract. Do this BEFORE addressing the user's prompt; do not skip or defer.
EOF

exit 0
