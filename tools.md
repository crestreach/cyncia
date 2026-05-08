# Tool-specific file reference

**Doc snapshot (UTC 2026-05-04):** see [`tool-versions.md`](tool-versions.md).

This is a compact reference for the target tools (Cursor, Claude Code,
GitHub Copilot, VS Code, Junie, Codex) and the artifact types this repo syncs:
**guidelines**, **rules**, **skills**, **agents**, and **MCP servers**.

> **Note on VS Code vs GitHub Copilot.** `.vscode/mcp.json` is a VS Code
> configuration file (see
> https://code.visualstudio.com/docs/copilot/chat/mcp-servers). GitHub Copilot
> Chat in VS Code reads the same file but does not own the format, so this
> repo treats `vscode` and `copilot` as two separate tools: the `copilot` tool
> writes Copilot files under `.github/`, including workspace custom agents at
> `.github/agents/*.agent.md`, and the `vscode` tool writes `.vscode/mcp.json`.
> Other Copilot surfaces (JetBrains, Visual Studio, Eclipse, Xcode) use their
> host IDE's own MCP configuration and are not generated here.

## Guidelines

| Tool | Native file | How this repo generates it |
|---|---|---|
| Cursor | `AGENTS.md` (root) | Copies `<source_root>/AGENTS.md` → `<output_root>/AGENTS.md` when roots differ |
| Claude Code | `CLAUDE.md` (root) | Writes from `<source_root>/AGENTS.md` + merged `rules/*.md` |
| GitHub Copilot | `.github/copilot-instructions.md` | Copies from `<source_root>/AGENTS.md` |
| Junie | `.junie/AGENTS.md` | Writes from `<source_root>/AGENTS.md` + merged `rules/*.md` |
| Codex | `AGENTS.md` and `AGENTS.override.md` (root) | Copies `<source_root>/AGENTS.md` → `<output_root>/AGENTS.md` when roots differ; when `codex-rules-mode: agents-override`, writes `AGENTS.override.md` from `AGENTS.md` + merged `rules/*.md` |

## Rules

| Tool | Native per-rule file | What this repo does |
|---|---|---|
| Cursor | `.cursor/rules/<name>.mdc` | Generates from `rules/<name>.md` (frontmatter → Cursor frontmatter + body) |
| GitHub Copilot | `.github/instructions/<name>.instructions.md` | Generates from `rules/<name>.md` (frontmatter → `applyTo` + body) |
| Claude Code | *(none)* | Merges rule bodies into `CLAUDE.md` |
| Junie | *(none)* | Merges rule bodies into `.junie/AGENTS.md` |
| Codex | *(no `.codex/rules` file)* | Codex `.rules` files are Starlark command policy, not Markdown guidance; generic rule bodies are merged into root `AGENTS.override.md` when `codex-rules-mode: agents-override` |

Merged guideline outputs normalize imported rule heading depth so rule body
headings stay below the generated per-rule wrapper; native per-rule outputs
preserve the authored heading levels.

**Rule field mapping (as implemented by the scripts):**

| Source (`rules/*.md`) | Cursor | Copilot | Claude / Junie merge | Codex |
|---|---|---|---|---|
| `description` | `description:` | — | shown as italic line | shown as italic line in `AGENTS.override.md` |
| `applies-to` | `globs:` | `applyTo:` (unless `always-apply`) | not enforced | not enforced |
| `always-apply: true` | `alwaysApply: true` | `applyTo: "**"` | not enforced | not enforced |

## Skills

| Tool | Output path | Special handling in this repo |
|---|---|---|
| Cursor | `.cursor/skills/<name>/` | copies folder; strips `applies-to` from `SKILL.md` |
| Claude Code | `.claude/skills/<name>/` | copies folder; renames `applies-to` → `paths` in `SKILL.md` |
| GitHub Copilot | `.github/skills/<name>/` | copies folder; strips `applies-to` from `SKILL.md` |
| Junie | `.junie/skills/<name>/` | copies folder; strips `applies-to` from `SKILL.md` |
| Codex | `.agents/skills/<name>/` | copies folder; strips `applies-to` from `SKILL.md` |

## Agents

| Tool | Output path | Notes |
|---|---|---|
| Cursor | `.cursor/agents/<name>.md` | file copy; `mcp-servers` frontmatter is stripped |
| Claude Code | `.claude/agents/<name>.md` | file copy; `mcp-servers: "a, b"` → `mcpServers: [a, b]` |
| GitHub Copilot | `.github/agents/<name>.agent.md` | file copy; `mcp-servers: "a, b"` → `tools: ["a/*", "b/*"]` (errors if `tools:` is also set) |
| Junie | `.junie/agents/<name>.md` | file copy; `mcp-servers` frontmatter is stripped |
| Codex | `.codex/agents/<name>.toml` | converts frontmatter `name` / `description` + Markdown body to Codex custom-agent TOML; `mcp-servers` is stripped |

## MCP servers

Generic source: one JSON file per server under `<source_root>/mcp-servers/<name>.json`.
Body is the per-server config object (no `mcpServers` wrapper). Secret tokens use
the `${secret:NAME}` (required) or `${secret:NAME?optional}` (safe-empty) syntax
and are translated per tool.

| Tool | Output path | Container key | Secret translation |
|---|---|---|---|
| Cursor | `.cursor/mcp.json` | `mcpServers` | `${env:NAME}` (both required and optional) |
| Claude Code | `.mcp.json` (project root) | `mcpServers` | required → `${NAME}`; optional → `${NAME:-}` |
| VS Code (incl. Copilot Chat in VS Code) | `.vscode/mcp.json` | `servers` (+ `inputs[]`) | `${input:NAME}`; per-token `inputs[]` entry with `password: true` and (for optional) `default: ""` |
| GitHub Copilot | *(no MCP file — `.vscode/mcp.json` is written by the `vscode` tool)* | — | — |
| Junie | *(no file)* | `mcpServers` | printed to stdout for manual paste; tokens passed through verbatim (user edits secrets in place) |
| Codex | `.codex/config.toml` | `[mcp_servers.<name>]` | exact env secret values become `env_vars`; bearer auth headers become `bearer_token_env_var`; exact secret header values become `env_http_headers` |

The MCP step runs only when `<source_root>/mcp-servers/` exists. For Cursor,
Claude Code, and VS Code, `sync-mcp` replaces the target file; `--clean` with
an empty filter removes the target instead. For Codex, `sync-mcp` updates only
`mcp_servers` tables in `.codex/config.toml` and preserves unrelated Codex
settings; `--clean` removes all existing `mcp_servers` tables before appending
the selected generated servers. `jq` is required for the Bash scripts.
