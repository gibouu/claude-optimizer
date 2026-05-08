# Moderate + plan with "## Design decisions" — compound heading containing the
# canonical "decisions" keyword → allow. Validates the permissive matching.
echo "moderate" > "$PROJ_DIR/.claude/state/.last_prompt_complexity"
mkdir -p "$PROJ_DIR/.claude/plans"
cat > "$PROJ_DIR/.claude/plans/test-plan.md" <<'PLAN'
# Plan title

## Context
Some context.

## Design decisions

**Single-script extension.** Chose A over B because of shared state.
**Off-ramp wins.** Chose explicit precedence over priority queues.
**Per-fingerprint cooldown.** Chose hash-based over count-based.

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
- [ ] Smoke.

End of plan.
PLAN
