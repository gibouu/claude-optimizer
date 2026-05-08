# Tag the prompt as complex but do NOT touch the websearch marker — the gate
# should block.
echo "complex" > "$PROJ_DIR/.claude/state/.last_prompt_complexity"
