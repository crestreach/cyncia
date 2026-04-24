---
name: agent-conf-sync
description: Runs the ai-dev-agent-config-sync batch script (`sync-all`) to regenerate Cursor, Claude Code, GitHub Copilot, VS Code, and JetBrains Junie configuration from a generic source tree. Use when the user asks to "sync agent config", "regenerate rules/skills/agents/mcp", "update .cursor / .claude / .github / .junie / .vscode from source", "run sync-all", or similar — so they don't have to assemble CLI flags or pick Windows vs Unix scripts themselves. The skill detects the OS, finds the script, and infers `-i` / `-o` / `--tools` / `--items` / `--clean` from the natural-language request.
---

# agent-conf-sync

This skill invokes **`scripts/sync-all.sh`** (macOS/Linux/Git Bash) or **`scripts/sync-all.ps1`** (Windows PowerShell) from the `ai-dev-agent-config-sync` repo. The user describes what they want in plain language; you pick the right script, resolve paths, infer flags, run it, and summarize the result.

Full format reference is in the repo's `README.md`. This skill is only about **invocation and reporting**.

## When to apply

Apply when the user wants to (re)generate tool-specific AI-assistant config from a single generic source tree. Trigger phrases include:

- "sync all", "run sync-all", "sync agent config", "sync the config"
- "regenerate / update the rules / skills / agents / guidelines / mcp"
- "rebuild `.cursor` / `.claude` / `.github` / `.junie`"
- "sync MCP servers", "regenerate `.vscode/mcp.json`", "update Claude `.mcp.json`"
- "sync for Cursor and Claude", "only Copilot", "skip Junie"
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
2. Else if the user named a path (e.g. `vendor/ai-dev-agent-config-sync`), use that.
3. Else search the workspace for `**/scripts/sync-all.sh` and use its grandparent.
4. If still ambiguous or missing, **ask once** for the path.

Use **absolute paths** when invoking the script.

## Step 3: Infer the required parameters

### Input root — `-i` / `-InputRoot` (required)

The directory that contains `AGENTS.md`, `agents/`, `skills/`, `rules/` (the generic authoring tree). May optionally contain `mcp-servers/` — when present, `sync-all` also generates the per-tool MCP config (Cursor `.cursor/mcp.json`, Claude `.mcp.json`, VS Code `.vscode/mcp.json`; Junie prints the snippet to stdout). `.vscode/mcp.json` is written by the `vscode` tool, not by `copilot` (it is a VS Code file, not a Copilot file).

Mapping from user phrasing:

- "from `_internal`", "internal tree", "authoring root", "this repo's own source" → `<CONFIG_SYNC_ROOT>/_internal`
- "from examples", "the examples tree" → `<CONFIG_SYNC_ROOT>/examples`
- "from my source", "from `<path>`" → that path
- "in place", "same as output" → same path as output root

If nothing is stated, look at the workspace: presence of `AGENTS.md` + `agents/` + `skills/` + `rules/` at some root indicates it's the source. Ask if unclear.

### Output root — `-o` / `-OutputRoot` (required)

The project root where `.cursor/`, `.claude/`, `.github/`, `.junie/`, and the root `AGENTS.md` copy are written. Usually the consumer project root, or this repo's root when regenerating its own outputs.

### `--tools` / `-Tools` (optional; default: all four)

Comma-separated subset of `cursor,claude,copilot,vscode,junie` (case-insensitive, no spaces).

| Phrase | Value |
|--------|-------|
| "all tools", "everything", no tool mentioned | omit flag (default = all five) |
| "only Cursor" | `cursor` |
| "Cursor and Claude", "not Copilot, not Junie" | `cursor,claude` |
| "skip Junie" | `cursor,claude,copilot,vscode` |
| "only VS Code", "just MCP for VS Code" | `vscode` |
| "Copilot with its MCP" | `copilot,vscode` (Copilot Chat in VS Code reads `.vscode/mcp.json`) |

Synonyms: **cursor** ← "Cursor"; **claude** ← "Claude", "Claude Code"; **copilot** ← "Copilot", "GitHub Copilot"; **vscode** ← "VS Code", "VSCode", "Visual Studio Code"; **junie** ← "Junie", "JetBrains".

### `--items` / `-Items` (optional)

Single comma-separated list of **basenames without extension** (e.g. `delegate-to-aside`, `commit-style`). Applied to agents, skills, and rules together.

| Phrase | Value |
|--------|-------|
| "only the aside skill", "just `delegate-to-aside`" | `delegate-to-aside` |
| "just `foo` and `bar`" | `foo,bar` |
| "full sync", "all of them", no item mentioned | omit flag |

**Caveat:** `--items` does not trim the guidelines merge. `sync-agent-guidelines` always emits the full `AGENTS.md` + merged rules for Claude/Junie. Mention this in the report if the user expected partial guidelines.

### `--clean` / `-Clean` (optional; default: off)

Set when the user asks to **remove stale outputs**, **prune**, **mirror source deletions**, **empty generated dirs first**, or says "clean sync".

**Warning — data loss risk:** `--clean` empties the entire output directory for **every** sync step on **every** selected tool before writing: `.cursor/{agents,rules,skills}`, `.claude/{agents,skills}`, `.github/{agents,instructions,skills}`, `.junie/{agents,skills}`. Any hand-authored files in those dirs are deleted. This is especially risky for `.github/` since users often keep unrelated content there (workflows live in `.github/workflows/` — not wiped — but a user might have put manual instruction files in `.github/instructions/`). Flag this risk in your pre-run note whenever `-Clean` is inferred, and name the specific dirs that will be emptied based on the `--tools` selection.

## Step 4: Validate and run

Before running:

1. Check that `<input_root>/AGENTS.md` exists. If not, stop and tell the user.
2. Use absolute paths in the command.
3. Capture full stdout and stderr.

Example — macOS / Linux:

```bash
bash "/abs/path/to/ai-dev-agent-config-sync/scripts/sync-all.sh" \
  -i "/abs/path/to/source-root" \
  -o "/abs/path/to/output-root" \
  --tools cursor,claude \
  --items delegate-to-aside
```

With clean:

```bash
bash "/abs/path/to/ai-dev-agent-config-sync/scripts/sync-all.sh" \
  -i "/abs/path/to/source-root" \
  -o "/abs/path/to/output-root" \
  --clean
```

Example — Windows PowerShell:

```powershell
& 'C:\abs\path\to\ai-dev-agent-config-sync\scripts\sync-all.ps1' `
  -InputRoot 'C:\abs\path\to\source-root' `
  -OutputRoot 'C:\abs\path\to\output-root' `
  -Tools 'cursor,claude' `
  -Items 'delegate-to-aside'
```

On non-zero exit, surface the error and suggest fixes (missing dirs, unknown tool name, missing `AGENTS.md`).

## Step 5: Post-run report (required)

Reply with a **compact** summary, not the full log:

1. **Command** — one line: OS/shell, script path, effective `-i`/`-o`/`--tools`/`--items`/`--clean`.
2. **Deletions / clean** — list paths from log lines matching `cleaned` / `removed` / `Clean`. If `--clean` was not used, state that no clean step ran (overwrite in place only).
3. **Generated / updated** — from lines with `->` (e.g. `cursor agent ->`, `copilot skill ->`) and `== tool ==` headers. Group by tool. Call out `AGENTS.md`, `CLAUDE.md`, `.github/copilot-instructions.md`, `.junie/AGENTS.md` when they appear.
4. **Basis** — one short sentence explaining what you inferred from the user's request.

## Edge cases

- **MCP-only sync:** likewise, call `scripts/<tool>/sync-mcp.{sh,ps1} -i <src>/mcp-servers -o <out>` directly. The Bash variants require `jq`.
- **Rules-only sync:** `sync-all` has no such flag. Call the per-tool script directly (e.g. `scripts/cursor/sync-rules.sh -i <src>/rules -o <out>`).
- **Submodule / monorepo:** always resolve real filesystem paths before running.
- **Input equals output:** allowed; scripts skip the redundant `AGENTS.md` copy.
- **Git Bash on Windows:** prefer the `.sh` script with `bash`; only use `.ps1` when the session is clearly native PowerShell.
