# Whole-plugin opt-out flag wins over everything else.
echo "complex" > "$PROJ_DIR/.claude/state/.last_prompt_complexity"
touch "$PROJ_DIR/.claude/optimizer-disabled"
