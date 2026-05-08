# Pre-seed .last_intent_fingerprint with a stale value (different from the
# input prompt's fingerprint). Directive should fire because the new prompt
# has a different fingerprint.
echo "stale99fp00x" > "$PROJ_DIR/.claude/state/.last_intent_fingerprint"
