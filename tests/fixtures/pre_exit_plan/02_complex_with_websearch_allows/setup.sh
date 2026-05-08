# Complex tag + websearch marker present → research was performed, allow.
echo "complex" > "$PROJ_DIR/.claude/state/.last_prompt_complexity"
touch "$PROJ_DIR/.claude/state/.websearch_this_turn"
