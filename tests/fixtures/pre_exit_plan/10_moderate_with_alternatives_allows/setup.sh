# Moderate + plan file has canonical "## Alternatives" heading → allow.
echo "moderate" > "$PROJ_DIR/.claude/state/.last_prompt_complexity"
mkdir -p "$PROJ_DIR/.claude/plans"
cat > "$PROJ_DIR/.claude/plans/test-plan.md" <<'PLAN'
# Plan title

## Context
Some context here.

## Alternatives

### A. Approach one
Pros and cons.

### B. Approach two (chosen)
More pros and cons.

## Implementation
1. Step one.
2. Step two.
3. Step three.
4. Step four.
5. Step five.
6. Step six.
7. Step seven.
8. Step eight.
9. Step nine.
10. Step ten.

## Verification
- [ ] Tests.
- [ ] Smoke test.

End.
PLAN
