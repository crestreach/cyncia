---
name: delegate-to-aside
description: Delegates a side question to the `aside` subagent with a properly composed prompt so the main chat context stays clean. Use when the user says "ask aside", "side question", "delegate this", "run in a subagent", or otherwise signals they want the question answered in isolated context. Also use proactively when a request is clearly off the current work thread (research, lookups, "how does X work?") and would bloat the main context.
---

# Delegate to the `aside` Subagent

The user has an `aside` subagent at `~/.cursor/agents/aside.md` that answers side questions in an isolated context. Only its final message returns here, so intermediate tool output does not pollute this chat.

This skill covers **how to invoke `aside` with a proper brief** instead of forwarding the user's raw words.

## When to apply

Apply when the user:

- Says "ask aside", "side question", "delegate this", "run in a subagent", or similar natural-language cues.
- Types `/aside <question>` at the start of a message. Despite the slash, this is **not** a hard system-level bypass — the message is routed to you (the main agent), and you should delegate. Treat it as an explicit cue to invoke the subagent. You may (and should) still enrich the prompt with conversation context per the recipe below.
- Asks something clearly tangential to the current work (research, lookups, comparisons, "how does X work?") that would bloat the main context.

Do **not** apply when:

- They want the answer inline in the main thread.
- The question is trivially answerable from existing context.

## How to invoke

Use the Task tool with `subagent_type: "aside"` (or the equivalent subagent invocation in this session). Compose a brief; do not forward the raw question.

## Prompt recipe

Build the subagent prompt with these sections, in order. Omit any that don't apply; do not pad.

```
## Question
<User's question, restated cleanly. Resolve pronouns like "this",
"that file", "the function we discussed" to concrete names.>

## Context from the current conversation
<2–8 terse bullets: what the user is working on, prior decisions,
constraints, project-specific vocabulary. Briefing, not transcript.>

## Relevant files / symbols
<Paths, line ranges, symbol names. Prefer pointers over pasted
content — the subagent has Read/Grep/Glob. Paste only small, central
snippets.>

## What the user wants back
<1–2 lines on depth, format, citations, code vs. prose, etc.>

## Out of scope
<Optional. Guard against scope creep, e.g. "do not propose code changes".>
```

## Context selection rules

- **Include**: decisions made, files touched, errors hit, constraints stated, project-specific vocabulary.
- **Exclude**: earlier unrelated tangents, your own prior reasoning, tool output transcripts, anything trivially rediscovered by reading a file.
- When in doubt, point to a path instead of pasting content. Summarize long histories.

## Example

**User says:** "Ask aside how retries work in `src/net/client.ts`, I want to know before I change this."

**Delegation prompt:**

```
## Question
How does the retry logic in `src/net/client.ts` work? What triggers a
retry, how is backoff computed, and is there a cap?

## Context from the current conversation
- User is about to modify `src/net/client.ts` to add a new endpoint.
- They want to understand existing retry behavior first.

## Relevant files / symbols
- `src/net/client.ts` (primary)
- Helpers it imports — discover via grep.
- `src/net/config.ts` may hold retry tunables.

## What the user wants back
Short explanation with file:line citations. No code changes.

## Out of scope
Do not suggest changes to the retry logic.
```

For self-contained research questions ("what's the difference between X and Y?"), omit the conversation-context and files sections.

## After the subagent returns

- Pass its final message through to the user. Add at most a one-line note.
- Do **not** re-explain or expand the answer — that defeats context isolation.
- If it said it lacked information, ask the user (or offer a follow-up delegation with more context) rather than answering from memory.
