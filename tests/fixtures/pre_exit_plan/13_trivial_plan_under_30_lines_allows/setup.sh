# Moderate + plan file under 30 lines → trivial-plan bypass.
echo "moderate" > "$PROJ_DIR/.claude/state/.last_prompt_complexity"
mkdir -p "$PROJ_DIR/.claude/plans"
cat > "$PROJ_DIR/.claude/plans/test-plan.md" <<'PLAN'
# Tiny plan

Implementation:
1. Do the thing.
2. Done.
PLAN
