---
name: cm-multi-plan
description: Use when drafting a Plan-mode plan for moderate/complex work. Plan must include an Alternatives/Tradeoffs/Decisions section with 2-3 approaches before ExitPlanMode. Hook gate enforces. Trivial plans (<30 lines) bypass.
---

# Multi-Plan (SOP)

The user's stated workflow: "show me two or three plans or two or three options... we could pick and choose the best portions of each plan." A single recommended approach hides the tradeoff space and forces the user to push back to surface alternatives. This skill makes alternatives a first-class part of the plan.

## When to fire

- Drafting a Plan-mode plan file for a moderate or complex task.
- Designing implementation for any non-trivial change, even outside formal Plan mode.
- The previous turn's directive emitted `[complexity: moderate]` or `[complexity: complex]`.

## When NOT to fire

- Trivial plans (one-liner edits, typo fixes, single-file <30-line changes).
- Off-ramp prompts (precise file:line, "just X", "quick fix") — no complexity tag set.
- The user explicitly said "skip alternatives, pick one and go" — off-ramp out loud, then proceed.

## What the plan must include

A section with one of these canonical headings (`##` or `###` level, case-insensitive):

- `## Alternatives` (preferred for genuinely competing approaches)
- `## Tradeoffs` (preferred when surfacing pros/cons of one direction)
- `## Options` / `## Approaches considered` / `## Comparison`

Inside the section: 2–3 distinct entries. For each, write:

- **Name / one-line summary** (e.g. "Single-script extension" vs. "Sibling script")
- **Pros** (1–3 bullets)
- **Cons** (1–3 bullets)
- **Recommendation marker** on the chosen one ("→ chosen because …")

The `## Design decisions` heading also satisfies the gate — useful when the alternatives are smaller forks discussed inline rather than a single comparison block. The body of that section must still surface the tradeoffs that were considered.

## Hard enforcement

The plugin's `pre_exit_plan.sh` PreToolUse hook checks the most recently modified plan file under `~/.claude/plans/`:

- If `.last_prompt_complexity` is `moderate` or `complex` AND the plan file lacks any canonical-heading match → ExitPlanMode is blocked with exit 2 and a stderr message naming the rule.
- Plan files under 30 lines bypass the check (treated as trivial).
- Same bypasses as `cm-research-first`: `MULTI_PLAN_OFF=1` env, `.claude/optimizer-disabled`.

## Worked example

Bad plan (gate blocks):

```markdown
# Add dark mode toggle

## Implementation
1. Add a useTheme hook
2. Wire it into the root component
3. Persist choice to localStorage
```

Good plan (gate allows):

```markdown
# Add dark mode toggle

## Alternatives

### A. CSS variables + class toggle
**Pros:** zero JS bundle cost; works without React state. **Cons:** can't conditionally render different components per theme.

### B. React context + theme prop on every component
**Pros:** componentry can branch on theme. **Cons:** heavier; requires touching every styled component.

### C. styled-components ThemeProvider (chosen)
**Pros:** idiomatic for the existing component lib; supports both static CSS and conditional rendering. **Cons:** small runtime overhead.
→ chosen because the codebase already uses styled-components and option B's prop-drilling cost outweighs A's bundle savings.

## Implementation
…
```

## Failure modes

- **Gate keeps firing on a plan that legitimately has alternatives but uses a non-canonical heading.** Add the heading "Alternatives" or "Tradeoffs" — even as a wrapper around your existing content — to satisfy the gate. The gate does not parse the section's body.
- **The user objects to alternatives overhead on what they consider a simple change.** Acknowledge, set `MULTI_PLAN_OFF=1` for the call, and proceed. Note the bypass in the plan so the user can reverse if regretted.
- **Plan file path can't be inferred.** The gate looks at the most recently modified `*.md` under `~/.claude/plans/` (mtime within the last hour). If you wrote the plan elsewhere (e.g. project-local), the gate has no plan to scan and falls through to allow.
