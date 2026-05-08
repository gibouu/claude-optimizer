---
name: cm-research-first
description: Use whenever the most recent user prompt was tagged `[complexity: complex]` by the claude-optimizer prompt directive (a substring of the previous turn's injected context). Concrete trigger: the last UserPromptSubmit hook output included `[claude-optimizer] Issue-driven workflow required.` AND `[complexity: complex]`. Required before invoking any planning tool (ExitPlanMode, /plan, brainstorming) on a complex request: call WebSearch with the problem framing plus "best practices 2026" or similar, read 2–3 results, and cite the findings in the resulting plan. The plugin's PreToolUse(ExitPlanMode) gate enforces this — without a WebSearch tool call in the current turn, ExitPlanMode is blocked.
---

# Research-First (SOP)

For complex tasks, do quick research on current best practices BEFORE proposing an approach. The user's stated workflow: "if it's complex... I want to do a search of best practices in the best way to implement this that is currently available in the market." This skill enforces that step.

## When to fire

The directive emitted by `prompt_submit.sh` for a complex prompt looks like:

```
[claude-optimizer] Issue-driven workflow required.
The user's prompt looks like a conversational request rather than a precise instruction. [complexity: complex]
...
```

If you see `[complexity: complex]` in the inline-context block at the start of a turn, this skill is in scope. Moderate and simple tasks don't require research-first — proceed normally.

## What to do

1. **Frame the search.** State the problem in 1–2 sentences. Identify the unknown ("how do production teams typically X", "what are the tradeoffs of Y vs Z"). Don't research what you already know — research what you'd otherwise *guess*.

2. **WebSearch.** Issue 1–2 WebSearch calls with the problem framing plus a recency hint:
   - `"<problem framing> best practices 2026"`
   - `"<library or pattern> production tradeoffs"`
   - For tooling questions: `"<tool A> vs <tool B> 2026"`

   Read 2–3 of the top results. Skim — you're looking for converging signals across multiple sources, not a single authoritative document.

3. **Synthesise.** Write a 2–4 line summary of what you learned: "Approach A is recommended when…; approach B is preferred when…; approach C has known issue X."

4. **Cite in the plan.** When you write the plan (Plan-mode plan file or PR description), include a one-line "Research notes" section with the synthesis and link the URLs. This becomes input to the multi-plan skill (#23) downstream.

5. **Then plan.** Only after research is in hand, propose alternatives.

## Hard enforcement

The plugin's `pre_exit_plan.sh` PreToolUse hook reads `.last_prompt_complexity` and `.websearch_this_turn`:

- If complexity is `complex` AND no WebSearch was called in the current turn → ExitPlanMode is blocked with exit 2.
- If you legitimately need to bypass (e.g. the "research" was a slack thread or a lab notebook the user pointed you at), set `RESEARCH_FIRST_OFF=1` for the call or add `.claude/optimizer-disabled` to opt-out the whole plugin.

The marker `.websearch_this_turn` is touched by the PostToolUse(WebSearch) hook and cleared at the start of every UserPromptSubmit. So one WebSearch call any time during the current turn satisfies the gate.

## When NOT to fire

- Complexity tag is `simple` or `moderate`.
- The prompt was an off-ramp (precise file:line, "just X", "quick fix") — no complexity tag is set in that case.
- The user explicitly said "skip research" or "you already know this" (off-ramp out loud, then proceed).
- The task is genuinely well-trodden in the current codebase (e.g. "add another React component matching this pattern") — note the existing pattern as your "research" and call WebSearch with a one-line query to satisfy the gate.

## Failure modes

- **WebSearch returns nothing useful.** Try one different query. If still nothing, write that fact in the Research notes ("no consensus best practice; proceeding from first principles") — the gate is satisfied by the call, not by the results.
- **Search would publish sensitive info.** Don't include project-specific code or names in the query. Use generalised framings.
- **The user objects to research overhead.** Acknowledge, set `RESEARCH_FIRST_OFF=1` for the call, and proceed. Note the bypass in the plan so the user can reverse if regretted.
