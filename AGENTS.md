# Agent guidance (ai-dev-agent-config-sync)

Conventions for AI assistants working in this repository.

## Guidelines

### General

- Do exactly and only what the user asks. Do not add anything that wasn't requested.
- If something seems worth extending or adding, ask first and discuss before changing the file.
- Do not make assumptions. If anything is vague, unclear, or you disagree with it, ask questions and raise concerns before proceeding.
- Match existing style in the touched files (naming, imports, formatting) before introducing new patterns.
- Large or risky changes: summarize the plan in a few bullets, then implement — reduces wrong-direction work
- One retry path, then escalate: try a reasonable alternative once; if still blocked, summarize evidence (error output, file/line) and ask for a decision instead of thrashing.
- Run the checks the task implies (tests, linter, typecheck, formatter) when the project has them; if a command fails, fix or report before declaring done.

### Git

- **Do not commit or push** unless the user explicitly asks you to (e.g. “commit”, “push”, “commit and push”). Staging is fine only if they asked for it; default is to leave `git commit` / `git push` to them unless instructed otherwise.
- Prefer **small, focused commits** with clear messages when you do commit.
- Do not rewrite published history (force-push, rebase onto public `main`) unless the user explicitly requests it.
- Never commit secrets (tokens, keys, .env with real values). If something looks sensitive, redact and tell the user instead of pasting it into chat or files.

### Tools and environment

    - Use the workspace as source of truth (read files, run commands) instead of guessing paths or versions.
    - Note OS/shell assumptions when relevant (e.g. macOS paths, zsh), especially for scripts or one-off commands.

## Communication

- Be **direct and concise**: skip flattery, hedging piles, and filler. A polite opening is enough.
- **Verify before stating facts** about this repo: read files, search the codebase, or run commands. For product or external behavior, cite the doc or page you used (link or title + section).
- Say what is observed (file contents, tool output) vs inferred vs remembered-from-training. Do not present guesses as facts.
- **Do not invent** APIs, CLI flags, config keys, paths, or “it works like this” behavior when you have not checked; say you are unsure and what would confirm it.
- **Do not hallucinate** citations, error messages, or prior conversation details. If something is not in context, say it is not available here.
- If you **disagree** with a request, a stated assumption, or a risky approach, say so **plainly** with short reasoning; if the user still wants it, follow explicit instructions unless impossible.
- When requirements are ambiguous, **ask** narrow clarifying questions instead of assuming.
- Substantiate conclusions: name relevant files, show exact commands you ran (with output when it matters), or point to the specific lines or diff hunk that fixes the issue.
