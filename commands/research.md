---
description: Quick best-practices research on a topic via WebSearch, synthesised into a 2-3 approach comparison and saved as an Architecture Decision Record. Usage: /research <topic>
---

Apply the `cm-research-first` skill — but instead of feeding the synthesis into a plan, save it as an ADR for future reference.

## 1. Take the topic

The user's argument is the topic. If empty, ask "What should I research?" and stop.

## 2. WebSearch

Issue 1–2 WebSearch calls with the topic plus a recency hint:

- `"<topic> best practices 2026"`
- `"<topic> production tradeoffs"` or `"<topic> vs <alternative> 2026"`

Read 2–3 of the top results from each. Skim — you're looking for converging signals across multiple sources, not a single authoritative document.

## 3. Synthesise

Identify 2–3 distinct approaches in the result set. For each:

- Name + 1-line summary
- 1–3 pros
- 1–3 cons
- Mark the recommended approach with a brief rationale

If sources don't converge, write that fact in the synthesis ("no consensus best practice; proceeding from first principles").

## 4. Save as an ADR

Locate or create `docs/adr/`. Scan for `NNNN-*.md` files; find the highest existing N, increment by 1. If none exists, start at `0001`. Pad to 4 digits.

Slug the topic into kebab-case under 40 chars (lowercase, replace spaces and punctuation with `-`, collapse repeats, trim leading/trailing dashes).

Write `docs/adr/<NNNN>-<slug>.md` with this template:

```markdown
# ADR <NNNN>: <Topic>

**Status:** Proposed
**Date:** <YYYY-MM-DD>

## Context

<1–2 sentences on what prompted this research — the question being answered>

## Approaches considered

### A. <Name>
**Pros:** …
**Cons:** …

### B. <Name>
**Pros:** …
**Cons:** …

### C. <Name> (recommended)
**Pros:** …
**Cons:** …
**Rationale:** …

## Decision

<chosen approach + 1-sentence rationale>

## References

- <url 1>
- <url 2>
- <url 3>

— Captured by /research on <YYYY-MM-DD>
```

## 5. Confirm

Reply with one line: `Researched and saved: docs/adr/<NNNN>-<slug>.md. Recommended: <approach name>.`

Don't dump the ADR contents back to chat — the user can read the file. If they want a verbal summary, they'll ask.

## Edge cases

- **WebSearch returns nothing useful.** Try one different query. If still nothing, write a short "no consensus" ADR documenting the gap. The ADR is still useful — it records that the question was asked and found no answer.
- **Topic is too narrow / project-specific.** WebSearch won't help. Tell the user "this looks project-specific; I'll need code context instead of the web. Point me at the relevant files." Skip the ADR.
- **Existing ADR covers the same topic.** Note the duplicate in your reply ("ADR 0007 already covers this") and ask whether to revise the existing ADR or write a new one.
- **`docs/` directory shouldn't exist** (e.g. flat-repo project). Ask the user whether to create it or save the ADR elsewhere.
