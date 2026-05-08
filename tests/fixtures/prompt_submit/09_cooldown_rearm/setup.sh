# Pre-seed .recent_fingerprints with stale entries that don't match the input
# prompt. Directive should fire because the new fp isn't in the ring buffer.
{
  echo "stale99fp00x"
  echo "another1stale"
} > "$PROJ_DIR/.claude/state/.recent_fingerprints"
