---
name: agent-conf-sync
description: Runs the cyncia batch script (`sync-all`) to regenerate Cursor, Claude Code, GitHub Copilot, VS Code, JetBrains Junie, and Codex configuration from a generic source tree. Use when the user asks to "sync agent config", "regenerate rules/skills/agents/mcp", "update .cursor / .claude / .github / .junie / .vscode / .codex / .agents from source", "run sync-all", or similar — so they don't have to assemble CLI flags or pick Windows vs Unix scripts themselves. The skill detects the OS, finds the script, and infers `-i` / `-o` / `--tools` / `--items` / `--clean` from the natural-language request.
---

# agent-conf-sync

This skill invokes **`scripts/sync-all.sh`** (macOS/Linux/Git Bash) or **`scripts/sync-all.ps1`** (Windows PowerShell) from the `cyncia` repo. The user describes what they want in plain language; you pick the right script, resolve paths, infer flags, run it, and summarize the result.

## Source tree format (`<source_root>`)

A source root must contain `AGENTS.md`. It may optionally contain any of these folders; each is independent and missing folders are skipped with a console note:

| Folder | One per | Purpose |
|---|---|---|
| `agents/<name>.md` | file | One agent / subagent definition. |
| `skills/<name>/SKILL.md` | folder | One Agent-Skills-format skill (plus optional extra files in the same folder). |
| `rules/<name>.md` | file | One rule with YAML frontmatter (`description`, `applies-to`, `always-apply`). |
| `mcp-servers/<name>.json` | file | One MCP server definition (body of the per-server config object, no `mcpServers` wrapper). |

## What `sync-all` writes

For each selected tool, `sync-all` writes:

| Tool | Generated paths under `<output_root>` |
|---|---|
| `cursor` | `AGENTS.md` (copy), `.cursor/{agents,skills,rules}/`, `.cursor/mcp.json` |
| `claude` | `CLAUDE.md` (AGENTS + rules merged), `.claude/{agents,skills}/`, `.mcp.json` |
| `copilot` | `.github/copilot-instructions.md`, `.github/{agents,skills,instructions}/` |
| `vscode` | `.vscode/mcp.json` (also read by Copilot Chat in VS Code) |
| `junie` | `.junie/AGENTS.md` (AGENTS + rules merged), `.junie/{agents,skills}/` |
| `codex` | `AGENTS.md` (copy), `AGENTS.override.md` when `codex-rules-mode=agents-override`, `.codex/agents/*.toml`, `.agents/skills/`, `.codex/config.toml` `mcp_servers` tables when `codex-sync-mcp=true` |

`sync-agent-guidelines` always emits the **full** `AGENTS.md` / `CLAUDE.md` / `.junie/AGENTS.md` — `--items` does not trim it. Claude and Junie have no per-rule files by default (rules are appended into the guidelines file). Codex does not generate `.codex/rules` from Cyncia Markdown rules because Codex `.rules` files are Starlark command policy; by default, Codex Markdown rule bodies are merged into root `AGENTS.override.md` instead.

This skill is only about **invocation and reporting**. For source-format details (rule frontmatter fields, secret-token translation, agent ↔ MCP linkage) see the upstream `README.md`.

## When to apply

Apply when the user wants to (re)generate tool-specific AI-assistant config from a single generic source tree. Trigger phrases include:

- "sync all", "run sync-all", "sync agent config", "sync the config"
- "regenerate / update the rules / skills / agents / guidelines / mcp / `AGENTS.override.md`"
- "rebuild `.cursor` / `.claude` / `.github` / `.junie` / `.codex` / `.agents`"
- "sync MCP servers", "regenerate `.vscode/mcp.json`", "update Claude `.mcp.json`"
- "sync for Cursor and Claude", "only Copilot", "only Codex", "skip Junie"
- "clean sync", "prune stale files", "mirror deletions"

Do **not** apply when the user is asking about the *format* of rules/skills/agents, or editing source files. For that, point them to `README.md`.

## Step 1: Detect the OS and shell

Pick the entrypoint based on the shell you'll actually execute in:

| Environment | Entrypoint | Flag style |
|-------------|-----------|-----------|
| Windows native PowerShell (`pwsh`, `powershell.exe`) | `scripts\sync-all.ps1` | `-InputRoot`, `-OutputRoot`, `-Tools`, `-Items`, `-Clean` |
| macOS, Linux, BSD | `scripts/sync-all.sh` | `-i`, `-o`, `--tools`, `--items`, `--clean` |
| Git Bash / WSL on Windows | `scripts/sync-all.sh` (prefer Bash) | same as Unix |

Detect with: `$env:OS -eq "Windows_NT"` in PowerShell; `uname` in Bash. Do **not** assume Unix just because the repo is cross-platform — use what the current session runs.

## Step 2: Locate the script root (`CONFIG_SYNC_ROOT`)

Resolve the directory that contains `scripts/sync-all.sh` and `scripts/sync-all.ps1`:

1. If the workspace root has `scripts/sync-all.sh`, use the workspace root.
2. Else if the user named a path (e.g. `vendor/cyncia`), use that.
3. Else search the workspace for `**/scripts/sync-all.sh` and use its grandparent.
4. If still ambiguous or missing, **ask once** for the path.

Use **absolute paths** when invoking the script.

## Step 3: Infer the required parameters

### Input root — `-i` / `-InputRoot` (required)

The directory that contains `AGENTS.md` and optionally any of `agents/`, `skills/`, `rules/`, `mcp-servers/` (see [Source tree format](#source-tree-format-source_root) above). Each folder is independent — `sync-all` skips the corresponding subscript (with a console note) when its source dir is absent. Only `AGENTS.md` is mandatory; if it is missing, `sync-all` exits with an error.

Mapping from user phrasing:

- "from `.agent-config`", "internal tree", "authoring root", "this repo's own source" → `<CONFIG_SYNC_ROOT>/.agent-config`
- "from examples", "the examples tree" → `<CONFIG_SYNC_ROOT>/examples`
- "from my source", "from `<path>`" → that path
- "in place", "same as output" → same path as output root

If nothing is stated, look at the workspace: presence of `AGENTS.md` + `agents/` + `skills/` + `rules/` at some root indicates it's the source. Ask if unclear.

### Output root — `-o` / `-OutputRoot` (required)

The project root where `.cursor/`, `.claude/`, `.github/`, `.junie/`, `.codex/`, `.agents/`, the root `AGENTS.md` copy, and root `AGENTS.override.md` are written. Usually the consumer project root, or this repo's root when regenerating its own outputs.

### `--tools` / `-Tools` (optional; default from config)

Comma-separated subset of `cursor,claude,copilot,vscode,junie,codex` (case-insensitive, no spaces). If omitted, `sync-all` uses `default-tools` from `.cyncia/cyncia.conf`; if that property is missing, the built-in default is all six supported tools.

| Phrase | Value |
|--------|-------|
| "all tools", "everything", no tool mentioned | omit flag (uses `default-tools`; built-in default all six) |
| "only Cursor" | `cursor` |
| "Cursor and Claude", "not Copilot, not Junie" | `cursor,claude` |
| "skip Junie" | `cursor,claude,copilot,vscode,codex` |
| "only VS Code", "just MCP for VS Code" | `vscode` |
| "Copilot with its MCP" | `copilot,vscode` (Copilot Chat in VS Code reads `.vscode/mcp.json`) |
| "only Codex" | `codex` |

Synonyms: **cursor** ← "Cursor"; **claude** ← "Claude", "Claude Code"; **copilot** ← "Copilot", "GitHub Copilot"; **vscode** ← "VS Code", "VSCode", "Visual Studio Code"; **junie** ← "Junie", "JetBrains"; **codex** ← "Codex", "OpenAI Codex".

### `--items` / `-Items` (optional)

Single comma-separated list of **basenames without extension** (e.g. `delegate-to-aside`, `commit-style`). Applied to agents, skills, and rules together.

| Phrase | Value |
|--------|-------|
| "only the aside skill", "just `delegate-to-aside`" | `delegate-to-aside` |
| "just `foo` and `bar`" | `foo,bar` |
| "full sync", "all of them", no item mentioned | omit flag |

**Caveat:** `--items` does not trim the guidelines merge. `sync-agent-guidelines` always emits the full `AGENTS.md` + merged rules for Claude/Junie/Codex. Mention this in the report if the user expected partial guidelines.

### `--clean` / `-Clean` (optional; default: off)

Set when the user asks to **remove stale outputs**, **prune**, **mirror source deletions**, **empty generated dirs first**, or says "clean sync".

**Warning — data loss risk:** `--clean` empties the entire output directory for **every** sync step on **every** selected tool before writing: `.cursor/{agents,rules,skills}`, `.claude/{agents,skills}`, `.github/{agents,instructions,skills}`, `.junie/{agents,skills}`, `.codex/agents`, and `.agents/skills`. Any hand-authored files in those dirs are deleted. This is especially risky for `.github/` since users often keep unrelated content there (workflows live in `.github/workflows/` — not wiped — but a user might have put manual instruction files in `.github/instructions/`). Codex MCP clean is narrower: it removes/replaces only `mcp_servers` sections in `.codex/config.toml`, preserving unrelated Codex config. Flag clean risk in your pre-run note whenever `-Clean` is inferred, and name the specific dirs or Codex config sections affected by the `--tools` selection.

## Step 4: Validate and run

Before running:

1. Check that `<input_root>/AGENTS.md` exists. If not, stop and tell the user.
2. Use absolute paths in the command.
3. Capture full stdout and stderr.

Example — macOS / Linux:

```bash
bash "/abs/path/to/cyncia/scripts/sync-all.sh" \
  -i "/abs/path/to/source-root" \
  -o "/abs/path/to/output-root" \
  --tools cursor,claude \
  --items delegate-to-aside
```

With clean:

```bash
bash "/abs/path/to/cyncia/scripts/sync-all.sh" \
  -i "/abs/path/to/source-root" \
  -o "/abs/path/to/output-root" \
  --clean
```

Example — Windows PowerShell:

```powershell
& 'C:\abs\path\to\cyncia\scripts\sync-all.ps1' `
  -InputRoot 'C:\abs\path\to\source-root' `
  -OutputRoot 'C:\abs\path\to\output-root' `
  -Tools 'cursor,claude' `
  -Items 'delegate-to-aside'
```

On non-zero exit, surface the error and suggest fixes (missing dirs, unknown tool name, missing `AGENTS.md`).

## Step 5: Post-run report (required)

Reply with a **compact** summary, not the full log:

1. **Command** — one line: OS/shell, script path, effective `-i`/`-o`/`--tools`/`--items`/`--clean`. If `--tools` was omitted and `default-tools` is visible, mention the configured default that was used.
2. **Deletions / clean** — list paths from log lines matching `cleaned` / `removed` / `Clean`. If `--clean` was not used, state that no clean step ran (overwrite in place only).
3. **Generated / updated** — from lines with `->` (e.g. `cursor agent ->`, `copilot skill ->`) and `== tool ==` headers. Group by tool. Call out `AGENTS.md`, `AGENTS.override.md`, `CLAUDE.md`, `.github/copilot-instructions.md`, `.junie/AGENTS.md`, `.codex/config.toml`, and `.codex/agents/*.toml` when they appear.
4. **Basis** — one short sentence explaining what you inferred from the user's request.

## Edge cases

- **MCP-only sync:** likewise, call `scripts/<tool>/sync-mcp.{sh,ps1} -i <src>/mcp-servers -o <out>` directly. The Bash variants require `jq`.
- **Rules-only sync:** `sync-all` has no such flag. Call the per-tool script directly (e.g. `scripts/cursor/sync-rules.sh -i <src>/rules -o <out>`).
- **Installed cyncia files / monorepo:** always resolve real filesystem paths before running.
- **Input equals output:** allowed; scripts skip the redundant `AGENTS.md` copy.
- **Git Bash on Windows:** prefer the `.sh` script with `bash`; only use `.ps1` when the session is clearly native PowerShell.
