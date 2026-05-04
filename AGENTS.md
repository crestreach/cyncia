# Agent guidance (cyncia)

## Repository layout

### Your generic source tree (you author these)

You provide a **source root** directory to `sync-all` (or call per-tool scripts
directly). Only `AGENTS.md` is required; every subfolder is **optional** and
the corresponding sync step is skipped with a console note when its folder is absent.

| Path (relative to your source root) | Required | Meaning |
|---|---|---|
| `AGENTS.md` | **yes** | Project-wide guidelines (the “generic” source). |
| `agents/<name>.md` | optional | One agent / subagent definition per file. |
| `skills/<name>/SKILL.md` | optional | One skill per folder (Agent Skills format). |
| `rules/<name>.md` | optional | One rule per file (generic frontmatter defined by this repo). |
| `mcp-servers/<name>.json` | optional | One MCP server config per file (see [Internal format: MCP servers](README.md#internal-format-mcp-servers)). |

In *this repository*, `.agent-config/` is just the authoring tree used to build the repo’s own generated outputs. You do **not** need (and usually should not use) `.agent-config/` in your own project — create your own source tree anywhere and point `-i`/`-InputRoot` script parameters at it.

### Generated outputs (written into your output root)

The sync scripts write tool-specific files under your **output root**:

| Generated from | Cursor | Claude Code | GitHub Copilot | VS Code | JetBrains Junie | Codex |
|---|---|---|---|---|---|---|
| `agents/<name>.md` | `.cursor/agents/<name>.md` | `.claude/agents/<name>.md` | `.github/agents/<name>.md` | *(no file)* | `.junie/agents/<name>.md` | `.codex/agents/<name>.toml` |
| `skills/<name>/…` | `.cursor/skills/<name>/…` | `.claude/skills/<name>/…` | `.github/skills/<name>/…` | *(no file)* | `.junie/skills/<name>/…` | `.agents/skills/<name>/…` |
| `rules/<name>.md` | `.cursor/rules/<name>.mdc` | *(not generated)* | `.github/instructions/<name>.instructions.md` | *(no file)* | *(not generated)* | `AGENTS.override.md` (when `codex-rules-mode: agents-override`) |
| `mcp-servers/<name>.json` | `.cursor/mcp.json` | `.mcp.json` (project root) | *(no file — `.vscode/mcp.json` is written by the **vscode** tool)* | `.vscode/mcp.json` (+ `inputs[]`) | *(stdout snippet only — no file)* | `.codex/config.toml` (`mcp_servers` tables only) |
| `AGENTS.md` | `AGENTS.md` (copied to output root when source root ≠ output root) | `CLAUDE.md` (generated from `AGENTS.md` + `rules/*.md`) | `.github/copilot-instructions.md` (copied from `AGENTS.md`) | *(no file)* | `.junie/AGENTS.md` (generated from `AGENTS.md` + `rules/*.md`) | `AGENTS.md` (Codex project guidance) plus `AGENTS.override.md` when Codex rules are enabled |

Notes:

- **Claude rules:** with `claude-rules-mode: claude-md` (the default in `cyncia.conf`), rule bodies are appended into `CLAUDE.md` by `sync-agent-guidelines`. With `claude-rules-mode: rule-files`, each rule is written to `.claude/rules/<n>.md` by `sync-rules` and imported from `CLAUDE.md` via `@.claude/rules/<n>.md` memory-imports.
- **Junie rules:** Junie has no per-rule file format, so rule bodies are appended into `.junie/AGENTS.md` by `sync-agent-guidelines` (and `sync-rules` remains a no-op).
- **Codex rules:** Codex `.rules` files are Starlark command policy, so Cyncia does not generate `.codex/rules`. With `codex-rules-mode: agents-override` (the default), Markdown rule bodies are appended into root `AGENTS.override.md`, which Codex prefers over `AGENTS.md` in the same directory.

## Agent configuration management (cyncia)

This repo manages all of its AI-assistant configuration — guidelines (`AGENTS.md`), rules, skills, agents, and MCP servers — through installed cyncia files under [`.cyncia`](./.cyncia). The single generic source tree lives in [`.agent-config/`](./.agent-config); per-tool layouts (`.cursor/`, `.claude/`, `.github/`, `.junie/`, `.vscode/`, `.codex/`, `.agents/`, root `AGENTS.md`, `AGENTS.override.md`, `CLAUDE.md`) are generated from it. The `agent-conf-sync` skill invokes the sync via `.cyncia/scripts/sync-all.sh` (POSIX) or `.cyncia/scripts/sync-all.ps1` (Windows).

When asked to **create or update** any of (or if any of the following gets updated):

- a guideline (the root `AGENTS.md`)
- a rule
- a skill
- a subagent
- an MCP server entry

read [`.cyncia/README.md`](./.cyncia/README.md) for the source-tree format (frontmatter fields, secret-token translation, agent ↔ MCP linkage), author the file under the appropriate folder of `.agent-config/` (`.agent-config/{rules,skills,agents,mcp-servers}/`), and then re-run the sync (skill `agent-conf-sync`) to fan it out to the per-tool directories. Do not hand-edit generated `.cursor/`, `.claude/`, `.github/`, `.junie/`, `.vscode/`, `.codex/agents/`, `.agents/skills/`, root `AGENTS.md`, root `AGENTS.override.md`, or `CLAUDE.md` files — they are overwritten on the next sync.


## Guidelines

Conventions for AI assistants working in this repository.

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
