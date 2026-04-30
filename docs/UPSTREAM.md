# Tracking Upstream Improvements

You wanted to keep your version lean, but still benefit when the upstream projects ship something genuinely good. Here's a workable approach.

## The problem

`claude-mem` ships ~weekly with multi-issue cleanup releases. `caveman/cavemem/cavekit` iterate fast and shed features as often as they add them. `everything-claude-code` keeps growing — it has 48 agents, 184 skills, 79 commands, and most of them are not relevant to your work.

You don't want to fork everything and hand-merge. You also don't want to auto-pull and inherit churn.

## The strategy: watch, don't merge

Instead of treating upstream as a parent branch, treat it as a **source of ideas**. The actual code stays small and yours.

### Step 1 — pin what you care about

In `docs/UPSTREAM.md` (this file), keep a table. One row per upstream concept you've borrowed or are watching:

| Concept | Source | Borrowed? | Last reviewed | Notes |
|---|---|---|---|---|
| Session-boundary memory hooks | claude-mem | yes | 2026-04-30 | Replaced their SQLite worker with flat files |
| `<private>` redaction tag | cavemem | yes | 2026-04-30 | Used in cm-memory skill |
| Output compression discipline | caveman | adapted | 2026-04-30 | Kept the principle, dropped the grammar |
| Spec-as-durable-truth | cavekit (v4) | yes | 2026-04-30 | Maps to MEMORY.md |
| Per-language rule files | everything-claude-code | no | 2026-04-30 | Watching; might add for TypeScript only |
| Forced-eval skill activation | scott spence's toolkit | no | 2026-04-30 | Investigate next month |

This table is your truth. Don't sync code; sync ideas.

### Step 2 — automate the watch

Create a tiny GitHub Action (or local cron) that pings each upstream's `releases.atom` once a week and emails/Slacks you the titles. You don't read every release — you scan titles.

`.github/workflows/upstream-watch.yml`:

```yaml
name: upstream-watch
on:
  schedule:
    - cron: "0 9 * * MON"
  workflow_dispatch:
jobs:
  watch:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Fetch latest releases
        run: |
          for repo in thedotmack/claude-mem JuliusBrussee/caveman \
                     JuliusBrussee/cavemem JuliusBrussee/cavekit \
                     affaan-m/everything-claude-code; do
            echo "=== $repo ==="
            curl -s "https://api.github.com/repos/$repo/releases?per_page=3" \
              | jq -r '.[] | "\(.published_at | split("T")[0])  \(.tag_name)  \(.name)"'
          done > upstream-digest.txt
      - name: Upload digest
        uses: actions/upload-artifact@v4
        with:
          name: upstream-digest
          path: upstream-digest.txt
```

That's it. The action posts a digest you can scan in 30 seconds.

### Step 3 — quarterly review

Once a quarter, sit down with the digest history, open the upstream READMEs, and ask three questions per project:

1. Did they add a *capability* I don't have? (not a feature — a capability)
2. Did they remove something I copied? (often a sign it didn't work)
3. Does any new release note describe a problem I'm currently having?

If yes to any of those, read the diff for that one piece. Port the idea, not the code. Update the table above.

### Step 4 — keep the surface area small

A guideline that's worked for plugin authors: **a skill earns its place when you've used it twice without remembering it exists.** If a skill needs reminding to be useful, the description is wrong or the skill is wrong. Delete it.

The same applies to upstream borrowing. If you find yourself porting something "just in case", don't.

## Specific recommendations from the source projects

After reviewing all five, here's what is actually worth borrowing if you don't already have it:

- **From `claude-mem`** — the *idea* of compressing observations at session boundaries. The flat-file version of this is already in `cm-memory`. If you ever need full-text search across a year of sessions, then revisit their SQLite+FTS approach. Until then, `grep` is fine.
- **From `cavemem`** — the `<private>` redaction tag. Already in `cm-memory`. Their MCP server is overkill for a single-user setup.
- **From `caveman`** — the principle of cutting conversational filler. The grammar ("caveman speech") is a gimmick that hurts readability for collaborators. Skip it; keep the principle in `cm-token-discipline`.
- **From `cavekit` v4** — the `SPEC.md` durable-truth idea is excellent. `MEMORY.md` + `DECISIONS.md` cover the same ground without the orchestration loop.
- **From `everything-claude-code`** — the per-language rule files are well done. If you work in one or two languages, copy *just those* into `.claude/rules/` and skip the rest. The 48-agent catalog is impressive but most users will never invoke 40 of them.

## What to never borrow

- Multi-process workers and daemons. They break in dev containers, on Windows, and during `claude --debug`.
- Vector embeddings without a real reason. `grep` over markdown is faster to set up, faster to debug, and faster at small scale (under ~50k entries).
- Large skill catalogs. Every extra skill is a description Claude has to filter past on every prompt. Each one has a small but non-zero cost.

## Versioning your own kit

Tag releases (`v0.1.0`, `v0.2.0`) and write a one-line CHANGELOG entry per change. When you update a single project's `.claude/` from your kit, you'll know what you're getting.
