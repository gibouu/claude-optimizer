# Complex + websearch (research-first allows), but plan lacks alternatives →
# multi-plan blocks. Validates that check 2 runs even after check 1 passes.
echo "complex" > "$PROJ_DIR/.claude/state/.last_prompt_complexity"
touch "$PROJ_DIR/.claude/state/.websearch_this_turn"
mkdir -p "$PROJ_DIR/.claude/plans"
cat > "$PROJ_DIR/.claude/plans/test-plan.md" <<'PLAN'
# Plan title

## Context
Big change.

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
11. Step eleven.
12. Step twelve.
13. Step thirteen.
14. Step fourteen.
15. Step fifteen.

## Verification
- [ ] Tests pass.
- [ ] Smoke test passes.
- [ ] No regressions.

## Notes
Some notes.
End.
PLAN
