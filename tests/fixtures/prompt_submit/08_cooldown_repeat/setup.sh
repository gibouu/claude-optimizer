# Pre-seed .recent_fingerprints with the input prompt's fp — directive should
# be suppressed on the repeat (R8 ring-buffer cooldown).
prompt_text='I want to add dark mode'
if command -v shasum >/dev/null 2>&1; then
  fp=$(printf '%s' "$prompt_text" | shasum | cut -c1-12)
elif command -v sha1sum >/dev/null 2>&1; then
  fp=$(printf '%s' "$prompt_text" | sha1sum | cut -c1-12)
else
  fp=""
fi
[ -n "$fp" ] && echo "$fp" > "$PROJ_DIR/.claude/state/.recent_fingerprints"
