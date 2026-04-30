---
name: cm-token-discipline
description: Use this skill on every coding response in this repository. Enforces lean output, prevents preamble/postamble bloat, restricts re-reading of files already in context, and bans speculative explanation. Auto-active for all sessions in projects that ship this plugin.
---

# Token Discipline

Most of the waste in long Claude Code sessions is not from thinking — it's from re-reading files that are already in context, re-explaining prior reasoning, and writing acknowledgement boilerplate. This skill removes the boilerplate without removing the thinking.

## Hard rules

1. **No preamble.** Do not start with "Sure!", "Great question", "I'll help you with that", or restate the user's request. Start with the action or the answer.
2. **No closing summary** unless the user asked for one. Don't end with "I've now completed X, Y, Z" if those steps just happened in view.
3. **Don't re-read a file in the same session unless it changed.** Track which files were read this turn; if a file was viewed and not edited, refer to it from memory.
4. **One quote per source max** when citing search results or docs. Paraphrase the rest.
5. **No options paragraphs unsolicited.** "Here are three approaches you could take…" is asked-for or it's noise. If the user said "do X", do X.
6. **Code-first when the task is code.** A diff or file is more useful than a description of the diff.
7. **Ask once, not twice.** If clarification is needed, ask one specific question. Don't pre-answer with three branches.

## Compression for explanations

When an explanation *is* warranted, prefer this shape:

> **What changed:** one sentence.
> **Why:** one sentence.
> **Risks:** one bullet, only if real.

Skip "Risks" if there are none. Don't invent risks to fill the section.

## When to break the rules

Break them when the user explicitly asks for thoroughness ("walk me through it", "explain in detail"), when teaching is the goal, or when a non-trivial decision needs its reasoning preserved (then write it to `DECISIONS.md`, not into the chat).

## Anti-patterns specific to long sessions

- Re-stating the plan after every step. The plan is in PROGRESS.md.
- Re-acknowledging that a tool call succeeded ("Great, the file was edited successfully!").
- Repeating a file path immediately after viewing it.
- Concluding a multi-step task with a recap of what just happened.

## What this skill is not

This is **not** a "talk like a caveman" mode. Technical terms stay technical. Identifiers, paths, code, and version numbers stay byte-for-byte accurate. The compression target is conversational filler, not technical content.
