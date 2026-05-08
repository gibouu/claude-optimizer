---
name: cm-decompose
description: Use right after a Plan-mode plan has been approved (ExitPlanMode just succeeded) when the plan describes ≥2 discrete deliverables. Concrete trigger: ExitPlanMode just returned successfully AND the plan file under `~/.claude/plans/` contains multiple top-level deliverables (`## Tier N` headings, `## N.` numbered sections, a "Deliverables" / "Phases" / "Issues" section with ≥2 bulleted entries, or an "Out of scope" / "Follow-ups" section listing future tickets). The skill suggests running the `/decompose-plan` slash command, which parses the plan, drafts an umbrella GitHub issue + N sub-issues with crossreferences, asks for user confirmation, and files them via `gh issue create`. Off-ramp: single-deliverable plans, plans with no GitHub remote, or the user saying "single PR / don't decompose".
---

# Decompose (SOP)

The user's stated workflow: "create a list of issues to be able to fix them one by one... if it's a bigger product to break it down in a smaller bite-size products." This skill bridges Plan-mode → backlog so the user gets a clean checklist of issues immediately after agreeing to a plan, instead of one giant PR or a forgotten "follow-ups" bullet.

## When to fire

Right after `ExitPlanMode` succeeds, scan the most recently modified plan file under `~/.claude/plans/*.md`. Fire if the plan structure indicates multiple discrete deliverables.

## Indicators of multi-deliverable plans

Any of these triggers decomposition:

- `## Tier N` headings (e.g. `## Tier 1`, `## Tier 2`, …) — roadmap-style plans
- Top-level `## N.` numbered sections (e.g. `## 1.`, `## 2.`)
- A `## Deliverables`, `## Phases`, `## Issues`, or `## Milestones` section with ≥2 bulleted/numbered items
- A `## Out of scope` / `## Follow-ups` section listing items the user wants tracked separately (not just buried in the PR body)
- Multiple `### Issue N` markers under a single plan

## When NOT to fire

- Single-deliverable plan (one cohesive PR)
- Trivial off-ramp work (precise file:line, "just X", quick fix)
- No GitHub remote configured (`gh repo view` errors)
- The user explicitly said "this is one PR" / "don't decompose" / "single issue is fine"

## What to do

1. **Suggest first.** "I notice this plan has N deliverables — want me to run `/decompose-plan` to file an umbrella + sub-issues?" Wait for user confirmation. Don't auto-file.
2. **The slash command does the work.** `/decompose-plan` parses the plan, drafts the umbrella + sub-issue titles/bodies, asks the user to confirm, then runs `gh issue create` for each. The umbrella body has a `- [ ] #<sub>: <title>` checklist; each sub-issue body has `Refs #<umbrella>` for traceability.
3. **Branch off the FIRST sub-issue, not the umbrella.** The umbrella is for tracking; sub-issues are for actual work. Each sub-issue gets its own `feat/<N>-<slug>` branch and PR with `Closes #<sub>`.
4. **As sub-issues merge,** their `Closes #<N>` directives auto-tick the umbrella's checklist (GitHub renders cross-PR checkbox state).

## Worked example

Plan structure:
```
## Tier 1: Trigger detection
## Tier 2: Research-first skill
## Tier 3: Decompose skill
## Tier 4: Polish (slash command, ADR, template)
```

After plan approval, the skill fires. Suggest `/decompose-plan`. The slash command files:

- `Umbrella` — "Hook-enforced workflow series (Tiers 1–4)" with checklist
- `Tier 1` — "Trigger detection in prompt_submit.sh"
- `Tier 2` — "cm-research-first skill + WebSearch gate"
- `Tier 3` — "cm-decompose skill"
- `Tier 4` — "/research command + ADR + issue template"

User picks them off the board one at a time.

## Failure modes

- **Plan file can't be located.** `/decompose-plan` reports "no recent plan found under ~/.claude/plans/" and stops. The user can pass a path explicitly: `/decompose-plan path/to/plan.md`.
- **Sub-issue titles feel generic.** The slash command shows the proposal before filing; the user can override or accept. Post-creation editing is also fine — `gh issue edit <N>`.
- **Umbrella checklist gets stale.** Sub-issue PRs use `Closes #<sub>`; GitHub auto-ticks the umbrella's `#<sub>` reference when the sub-issue closes. If a sub-issue is closed without merging (e.g. won't-fix), the user manually unchecks.
- **The user prefers a single PR after all.** That's fine — decompose only when there are real reasons for separate review cycles (different reviewers, different deploy windows, distinct risk profiles).
