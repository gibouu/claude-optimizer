# Pre-seed .recent_blocks with 2 prior gate blocks. Prompt contains retry
# phrases ("still doesn't work", "tried it") so the retry-context block
# should fire. The "still" + "doesn't" patterns also hit the off-ramp →
# no directive, just the retry context.
{
  echo "pre_exit_plan: research-first blocked, no WebSearch this turn"
  echo "pr_preflight: no Closes #N on 200-line diff"
} > "$PROJ_DIR/.claude/state/.recent_blocks"
