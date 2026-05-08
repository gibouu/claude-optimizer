# Simple complexity → multi-plan does not enforce, allow regardless of plan content.
echo "simple" > "$PROJ_DIR/.claude/state/.last_prompt_complexity"
mkdir -p "$PROJ_DIR/.claude/plans"
cat > "$PROJ_DIR/.claude/plans/test-plan.md" <<'PLAN'
# Tiny plan

## Implementation
1. Do the thing.
2. Do another thing.
3. Done.
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
16. Step sixteen.
17. Step seventeen.
18. Step eighteen.
19. Step nineteen.
20. Step twenty.
21. Step 21.
22. Step 22.
23. Step 23.
24. Step 24.
25. Step 25.
26. Step 26.
27. Step 27.
28. Step 28.
29. Step 29.
30. Step 30.

End.
PLAN
