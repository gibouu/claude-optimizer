# Moderate complexity + plan file without alternatives heading → multi-plan blocks.
echo "moderate" > "$PROJ_DIR/.claude/state/.last_prompt_complexity"
mkdir -p "$PROJ_DIR/.claude/plans"
cat > "$PROJ_DIR/.claude/plans/test-plan.md" <<'PLAN'
# Some plan

## Context
Adding a feature.

## Files to modify
- src/foo.ts
- src/bar.ts
- src/baz.ts

## Implementation
1. Step one with some detail explaining what we'll do.
2. Step two — more detail about the approach.
3. Step three — final piece of the work.
4. Step four — additional context.
5. Step five.
6. Step six.
7. Step seven.
8. Step eight.
9. Step nine.
10. Step ten.

## Verification
- [ ] Run tests
- [ ] Manual smoke test
- [ ] Check production logs

## Notes
Some notes about the approach.
A few more lines.
And another.
End of plan.
PLAN
