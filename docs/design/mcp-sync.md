# MCP server config sync

Design notes for the `mcp-servers/` source dir and `sync-mcp` scripts.

## Goal

Extend the "author once, sync to each tool" pattern to **MCP (Model Context
Protocol) server configuration**. The user writes one generic source file per
server under `mcp-servers/<name>.json`; per-tool sync scripts emit each tool's
native project-local MCP file.

## Scope (v1)

| Tool | Project-local file | Emitted by |
|---|---|---|
| Cursor | `.cursor/mcp.json` | `scripts/cursor/sync-mcp.{sh,ps1}` |
| Claude Code | `.mcp.json` | `scripts/claude/sync-mcp.{sh,ps1}` |
| VS Code (incl. Copilot Chat in VS Code) | `.vscode/mcp.json` | `scripts/vscode/sync-mcp.{sh,ps1}` |
| GitHub Copilot | *(no MCP file — `.vscode/mcp.json` belongs to VS Code)* | `scripts/copilot/sync-mcp.{sh,ps1}` is a no-op stub |
| JetBrains Junie | *(no documented project file)* | `scripts/junie/sync-mcp.{sh,ps1}` — **no-op**, prints paste-ready snippet to stdout |

Agent-level MCP binding (v1):

| Tool | Supported on agents | Translation |
|---|---|---|
| Claude Code | Yes (`mcpServers:` in subagent frontmatter) | `mcp-servers: [a, b]` → `mcpServers: [a, b]` |
| GitHub Copilot | Yes (`tools:` list with `<server>/*` globs) | `mcp-servers: "a, b"` → `tools: ["a/*", "b/*"]`; if `tools:` is already present, sync errors instead of merging/appending |
| Cursor | Not documented | `mcp-servers:` stripped from emitted agent |
| Junie | Not documented | `mcp-servers:` stripped |

Skill-level MCP binding is **out of scope for v1** (no tool has first-class
equivalents; Claude's `allowed-tools:` is pre-approval, not scoping). `mcp-servers:`
on skills is treated as a pass-through and stripped from every emitted copy.

## Generic source: `mcp-servers/<name>.json`

One file per server. The file body is the per-server object (no outer `mcpServers`
wrapper). Example — stdio with an optional API key:

```json
{
  "type": "stdio",
  "command": "npx",
  "args": ["-y", "@upstash/context7-mcp"],
  "env": {
    "CONTEXT7_API_KEY": "${secret:CONTEXT7_API_KEY?optional}"
  }
}
```

Example — remote HTTP:

```json
{
  "type": "http",
  "url": "https://mcp.context7.com/mcp",
  "headers": {
    "CONTEXT7_API_KEY": "${secret:CONTEXT7_API_KEY?optional}"
  }
}
```

### Interpolation tokens

| Token | Meaning |
|---|---|
| `${secret:NAME}` | Required secret. Tools that support interactive prompts (VS Code) will prompt. |
| `${secret:NAME?optional}` | Optional secret; missing/empty is acceptable. |

Plain strings pass through unchanged. No other interpolation syntax is defined
in v1 — users who need workspace paths or plain env vars should hard-code the
value in the source file for v1.

### Per-tool translation

| Source token | Cursor | Claude Code | VS Code (Copilot) |
|---|---|---|---|
| `${secret:NAME}` | `${env:NAME}` | `${NAME}` | `${input:NAME}` + `inputs[]` entry (`type: promptString`, `password: true`) |
| `${secret:NAME?optional}` | `${env:NAME}` | `${NAME:-}` | `${input:NAME}` + `inputs[]` entry (`password: true`, `default: ""`) |

Sources: [Cursor MCP config](https://cursor.com/docs/mcp#config-interpolation),
[Claude Code `.mcp.json` env expansion](https://code.claude.com/docs/en/mcp#environment-variable-expansion-in-mcp-json),
[VS Code MCP inputs](https://code.visualstudio.com/docs/copilot/reference/mcp-configuration#_input-variables-for-sensitive-data).

## Emitted file shape

### Cursor — `.cursor/mcp.json`

```json
{
  "mcpServers": {
    "<name>": { ...translated body... }
  }
}
```

### Claude Code — `.mcp.json`

```json
{
  "mcpServers": {
    "<name>": { ...translated body... }
  }
}
```

### Copilot — `.vscode/mcp.json`

```json
{
  "servers": {
    "<name>": { ...translated body... }
  },
  "inputs": [
    { "id": "NAME", "type": "promptString", "password": true }
  ]
}
```

`inputs` is only emitted if at least one server translates a `${secret:...}`
token.

## Script behavior

- `scripts/<tool>/sync-mcp.{sh,ps1}` accepts the same flags as the existing
  `sync-*` scripts: `-i`/`--input` (generic `mcp-servers/` dir), `-o`/`--output`
  (project root), `--items`, `--clean`, `--help`.
- **`--clean`** for `sync-mcp` means: overwrite the single target file
  unconditionally. There is no multi-file cleanup because the MCP config is a
  singleton. If no source files match (`--items` filter excludes everything),
  the target is written as an empty container rather than deleted, unless
  `--clean` is also set — in which case the target file is removed.
- **`--items`** filters by server basename.
- `scripts/sync-all.{sh,ps1}` runs `sync-mcp` **before** `sync-agent-guidelines`
  for each selected tool, so agent/guideline files can reference servers that
  are already materialized.

## Dependencies

- Bash scripts require **`jq`**. The script exits with a clear message if `jq`
  is not installed.
- PowerShell uses native `ConvertFrom-Json` / `ConvertTo-Json`.

## Secrets

- **Never commit real secret values.** Source files should only contain
  interpolation tokens or non-sensitive placeholders.
- If a token is marked `?optional` and the user's environment doesn't have a
  value, the emitted file is still safe to commit: Claude/Cursor expand to an
  empty string; VS Code prompts (empty default is accepted).

## Precedence and trust (per tool)

- **Claude Code**: loading a project-scoped `.mcp.json` server triggers an
  approval prompt. Use `claude mcp reset-project-choices` to re-prompt.
- **VS Code (Copilot)**: shows a trust dialog on first start of each server.
- **Cursor**: prompts per tool call on first use; blanket auto-approve is opt-in
  via `~/.cursor/permissions.json`.
- **Junie**: no committed file; users paste the stdout snippet into
  `Settings | Tools | AI Assistant | Model Context Protocol (MCP)`.

## Non-goals (v1)

- No workspace-path interpolation (`${workspace:...}`).
- No plain `${env:...}` token (not supported uniformly across tools' MCP JSON).
- No skill-level MCP gating.
- No Cursor agent-level MCP gating (not documented).
- No Junie project file generation.
- No tool-specific extension pass-through (`x-cursor`, `x-vscode`, etc.).
  Everything in the source body is passed through to every tool; tools ignore
  keys they don't support.
