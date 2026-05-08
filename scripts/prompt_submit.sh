#!/usr/bin/env bash
# Runs before each user prompt is dispatched to the model. Token-disciplined
# version (v0.12.0+) — directives compressed, blocks mutex'd, retry detection
# carries failed-attempt context across turns.
#
# Three possible outputs (in this order, all to stdout for inline-context):
#   1. Retry-context block — when the prompt looks like a follow-up to a
#      gate-blocked attempt, surface .recent_blocks so the model doesn't
#      repeat what already failed.
#   2. Issue-workflow directive — when the prompt is a genuine feature/refactor
#      request (R1 trigger regex), telling the model to invoke
#      cm-issue-driven-workflow before responding.
#   3. State-checkpoint directive — when the edit counter has accumulated
#      without a state write. Mutually exclusive with #2 (R2): if the
#      issue-workflow fires, the checkpoint is deferred to the next cadence.
#
# Never blocks. Parse failures are silent.
set -euo pipefail

ROOT="${CLAUDE_PROJECT_DIR:-$PWD}"
STATE_DIR="$ROOT/.claude/state"

[ -f "$ROOT/.claude/optimizer-disabled" ] && exit 0
[ -d "$STATE_DIR" ] || exit 0

# Per-turn marker reset for cm-research-first's gate.
rm -f "$STATE_DIR/.websearch_this_turn" 2>/dev/null || true

PAYLOAD="$(cat 2>/dev/null || true)"

# Extract the user's prompt (jq → sed fallback).
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
lc=""
[ -n "$prompt" ] && lc=$(printf '%s' "$prompt" | tr '[:upper:]' '[:lower:]')

# ── R3: retry-context injection ─────────────────────────────────────────
# When the prompt looks like a retry of a previous attempt, surface the
# last 3 gate-block records so the model doesn't repeat what failed.
RETRY_RE='still (broken|failing|not working|wrong|crashing|erroring)|doesn.?t (work|fire|trigger|match|show|render|run)|didn.?t (work|fix|help|fire|trigger)|tried (this|that|it|both)|same (issue|problem|thing|error|behaviou?r)|keep (getting|seeing|hitting)|why (still|isn.?t this)|once more'
BLOCKS_FILE="$STATE_DIR/.recent_blocks"

if [ -n "$lc" ] && [[ "$lc" =~ $RETRY_RE ]] && [ -s "$BLOCKS_FILE" ]; then
  printf '%s\n' "[claude-optimizer] Recent gate blocks — don't repeat what already failed:"
  sed 's/^/  - /' "$BLOCKS_FILE"
  echo
fi

# ── State-checkpoint cadence (deferred until R2 mutex resolved) ─────────
COUNT_FILE="$STATE_DIR/.edit_count"
LAST_FILE="$STATE_DIR/.last_directive_count"

read_int() {
  local v
  v="$(cat "$1" 2>/dev/null || echo 0)"
  case "$v" in ''|*[!0-9]*) echo 0 ;; *) echo "$v" ;; esac
}

COUNT="$(read_int "$COUNT_FILE")"
LAST="$(read_int "$LAST_FILE")"
[ "$LAST" -gt "$COUNT" ] && LAST=0

fire_checkpoint=0
if [ "$COUNT" -ge 5 ] && [ $((COUNT % 5)) -eq 0 ] && [ "$LAST" -lt "$COUNT" ]; then
  fire_checkpoint=1
fi

# Without a prompt, the only thing left is the checkpoint cadence.
if [ -z "$prompt" ]; then
  if [ "$fire_checkpoint" = "1" ]; then
    echo "$COUNT" > "$LAST_FILE" 2>/dev/null || true
    echo "[claude-optimizer] $COUNT edits without state write. Invoke cm-checkpoint (write PROGRESS/TASKS/DECISIONS/MEMORY)."
  fi
  exit 0
fi

# ── R1: tightened trigger / widened off-ramp ────────────────────────────
COMPLEXITY_FILE="$STATE_DIR/.last_prompt_complexity"

# Off-ramp regex (R1 widened) — explicit overrides, file:line, rename/delete,
# AND debug-mode chatter (still broken, doesn't work, tried this, again, etc).
OFFRAMP_RE='(^|[^a-z])(just |quick fix|small thing|skip the issue|no pr|no issue|nit:|typo|still (broken|failing|not working|wrong|crashing)|doesn.?t (work|fire|trigger|match|show|render|run)|didn.?t (work|fix|help|fire)|tried (this|that|it|both)|same (issue|problem|thing|error)|keep (getting|seeing|hitting)|debug |test it|check (the|this|that|it)|look at|once more)|[a-z_./-]+\.[a-z]+:[0-9]+|^(rename|delete|remove|fix|add|update) [a-z_`]'

# Trigger regex (R1 tightened) — only genuine feature/architecture requests.
# Requires "to <verb>" or "(a|an|the) <noun>" structure to filter out
# casual conversation matches.
TRIGGER_RE='(^|[^a-z])(i want to (add|build|create|implement|introduce|refactor|redesign|migrate|design)|i.?d like to (add|build|create|implement|introduce|design)|we should (refactor|redesign|migrate|introduce|implement|build|design|move to)|let.?s (add|build|create|implement|introduce|design) (a|an|the)|feature request|design (a|an) (new|better|proper)|the proper way to|wouldn.?t it be (better|nice|great) (to|if)|should we (refactor|redesign|build|introduce|migrate))'

fire_issue_workflow=0

if [ -n "$lc" ]; then
  if [[ "$lc" =~ $OFFRAMP_RE ]]; then
    rm -f "$COMPLEXITY_FILE" 2>/dev/null || true
  elif [[ "$lc" =~ $TRIGGER_RE ]]; then
    fire_issue_workflow=1
  else
    rm -f "$COMPLEXITY_FILE" 2>/dev/null || true
  fi
fi

# ── R8: ring-buffer fingerprint cooldown ────────────────────────────────
# If the new prompt's fp matches any of the last 3 fingerprints, suppress
# the directive (the model is iterating on a known request).
if [ "$fire_issue_workflow" = "1" ]; then
  fp=""
  if command -v shasum >/dev/null 2>&1; then
    fp=$(printf '%s' "$prompt" | shasum 2>/dev/null | cut -c1-12)
  elif command -v sha1sum >/dev/null 2>&1; then
    fp=$(printf '%s' "$prompt" | sha1sum 2>/dev/null | cut -c1-12)
  fi

  if [ -n "$fp" ]; then
    RING_FILE="$STATE_DIR/.recent_fingerprints"
    if [ -f "$RING_FILE" ] && grep -qxF "$fp" "$RING_FILE" 2>/dev/null; then
      fire_issue_workflow=0   # recent retry — suppress
    else
      echo "$fp" >> "$RING_FILE" 2>/dev/null || true
      tail -3 "$RING_FILE" > "${RING_FILE}.tmp" 2>/dev/null && mv "${RING_FILE}.tmp" "$RING_FILE" || true
    fi
  fi
fi

# Complexity classifier (only when issue-workflow will fire).
if [ "$fire_issue_workflow" = "1" ]; then
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
  echo "$complexity" > "$COMPLEXITY_FILE" 2>/dev/null || true
fi

# ── R2: mutually exclusive emit ─────────────────────────────────────────
# Issue-workflow takes precedence over checkpoint. If both would fire,
# emit only the issue-workflow block (it implicitly subsumes a checkpoint
# via PR creation downstream).
if [ "$fire_issue_workflow" = "1" ]; then
  printf '[claude-optimizer] Conversational request [complexity: %s]. Invoke cm-issue-driven-workflow (clarify → issue → branch → PR with Closes #N), or off-ramp explicitly if trivial.\n' "$complexity"
elif [ "$fire_checkpoint" = "1" ]; then
  echo "$COUNT" > "$LAST_FILE" 2>/dev/null || true
  echo "[claude-optimizer] $COUNT edits without state write. Invoke cm-checkpoint (write PROGRESS/TASKS/DECISIONS/MEMORY)."
fi

exit 0
