# MULTI_PLAN_OFF=1 — one-off env bypass. Plan lacks alternatives but env wins.
echo "moderate" > "$PROJ_DIR/.claude/state/.last_prompt_complexity"
mkdir -p "$PROJ_DIR/.claude/plans"
cat > "$PROJ_DIR/.claude/plans/test-plan.md" <<'PLAN'
# Plan title

## Implementation
1. Do thing.
2. Step two.
3. Step three.
4. Step four.
5. Step five.
6. Step six.
7. Step seven.
8. Step eight.
9. Step nine.
10. Step ten.

## Notes
Without alternatives section.
Without alternatives section.
Without alternatives section.
Without alternatives section.
Without alternatives section.
Without alternatives section.
Without alternatives section.
Without alternatives section.
Without alternatives section.
Without alternatives section.
Without alternatives section.
Without alternatives section.
Without alternatives section.
Without alternatives section.
Without alternatives section.
Without alternatives section.
Without alternatives section.
Without alternatives section.
Without alternatives section.
Without alternatives section.
PLAN
export MULTI_PLAN_OFF=1
