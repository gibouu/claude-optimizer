# Force the state-checkpoint block to fire by seeding edit_count=10 with
# a stale last_directive_count. Issue-workflow block also fires because the
# input prompt matches the trigger regex.
echo "10" > "$PROJ_DIR/.claude/state/.edit_count"
echo "5" > "$PROJ_DIR/.claude/state/.last_directive_count"
