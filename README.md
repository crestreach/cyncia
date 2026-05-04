# cyncia

**Author your AI-assistant config once, sync it to every tool.**

Website: <https://www.cyncia.net>

Cyncia takes a single, tool-agnostic source tree (guidelines, agents, skills,
rules, MCP servers) and generates the per-tool layouts that
**Cursor**, **Claude Code**, **GitHub Copilot**, **VS Code**,
**JetBrains Junie**, and **Codex** expect — file paths, file formats, and frontmatter keys
all translated for you.

> Full reference (formats, frontmatter, MCP secret tokens, per-tool field map,
> edge cases): **[`cyncia.md`](cyncia.md)**.

## What it does

You write this once:

```text
.agent-config/
├── AGENTS.md                 # project-wide guidelines
├── agents/<name>.md          # one subagent per file
├── skills/<name>/SKILL.md    # one skill per folder
├── rules/<name>.md           # one rule per file
└── mcp-servers/<name>.json   # one MCP server per file
```

Cyncia generates the rest:

| Source                       | Cursor                             | Claude Code                  | GitHub Copilot                                | VS Code             | JetBrains Junie                | Codex                         |
| ---------------------------- | ---------------------------------- | ---------------------------- | --------------------------------------------- | ------------------- | ------------------------------ | ----------------------------- |
| `AGENTS.md`                  | `AGENTS.md`                        | `CLAUDE.md`                  | `.github/copilot-instructions.md`             | —                   | `.junie/AGENTS.md`             | `AGENTS.md`                   |
| `agents/<n>.md`              | `.cursor/agents/<n>.md`            | `.claude/agents/<n>.md`      | `.github/agents/<n>.md`                       | —                   | `.junie/agents/<n>.md`         | `.codex/agents/<n>.toml`      |
| `skills/<n>/`                | `.cursor/skills/<n>/`              | `.claude/skills/<n>/`        | `.github/skills/<n>/`                         | —                   | `.junie/skills/<n>/`           | `.agents/skills/<n>/`         |
| `rules/<n>.md`               | `.cursor/rules/<n>.mdc`            | merged into `CLAUDE.md` *or* `.claude/rules/<n>.md` (configurable, see `cyncia.conf`) | `.github/instructions/<n>.instructions.md`    | —                   | merged into `.junie/AGENTS.md` | *(not generated)*             |
| `mcp-servers/<n>.json`       | `.cursor/mcp.json`                 | `.mcp.json`                  | (uses VS Code’s `.vscode/mcp.json`)           | `.vscode/mcp.json`  | stdout snippet                 | `.codex/config.toml`          |

Along the way it also rewrites **frontmatter** to each tool's native shape:

- Generic rule keys (`applies-to`, `always-apply`, `description`) →
  `globs` / `alwaysApply` (Cursor) and `applyTo` (Copilot).
- Generic skill key `applies-to` → `paths` for Claude; stripped elsewhere.
- Generic agent key `mcp-servers` → `mcpServers: [...]` (Claude),
  `tools: ["a/*", ...]` (Copilot); stripped for Cursor and Junie.
- MCP secret tokens (`${secret:NAME}`, `${secret:NAME?optional}`) →
  `${env:NAME}` (Cursor), `${NAME}` / `${NAME:-}` (Claude),
  `${input:NAME}` + `inputs[]` entry (VS Code), and Codex environment
  forwarding / bearer-token env vars where Codex documents those fields.

Codex note: Codex's native `.rules` files are Starlark command-approval
policies, not Markdown instruction files. Cyncia's generic `rules/*.md` are
therefore not emitted for Codex; keep Codex command policy under
`.codex/rules/*.rules` by hand.

## Dependencies

- **Bash 4+** (macOS/Linux/WSL/Git Bash) — for `scripts/**/*.sh`.
- **PowerShell 5.1+** or **PowerShell 7+** (Windows / cross-platform) — for `scripts/**/*.ps1`.
- **`jq` 1.6+** — required only by the MCP sync (`sync-mcp.{sh,ps1}` and the
  MCP step of `sync-all`); install with `brew install jq` /
  `apt-get install jq` / `winget install jqlang.jq`.
- **Git** — not required by the installer or by sync time.
- Standard POSIX utilities (`sed`, `awk`, `grep`, `find`) — already present
  on macOS, Linux, WSL, and Git Bash.

## Install

From your project root, run the installer:

```bash
curl -fsSL https://raw.githubusercontent.com/crestreach/cyncia/main/install/install.sh | bash
```

The installer creates `.agent-config/` (with empty `agents/`, `skills/`, `rules/`,
`mcp-servers/` and a stub `AGENTS.md`), downloads a snapshot of cyncia into
`.cyncia/`, and prompts whether to copy the bundled skills into
`.agent-config/skills/` and run `sync-all` immediately. Both prompts default
to **yes** — pressing Enter (or running with no TTY, as under `curl | bash`)
accepts; pass `--no-bootstrap` to decline both. Re-running it later
**updates** the existing `.cyncia/` checkout.

Common parameters (pass after `bash -s --`):

| Flag | Default | Purpose |
|---|---|---|
| `--config-dir PATH` | `.agent-config` | Authoring source tree. |
| `--cyncia-dir PATH` | `.cyncia` | Where the cyncia checkout lives. |
| `--ref REF` | `main` | Branch or tag to download. |
| `--repo OWNER/NAME` | `crestreach/cyncia` | GitHub repo to download from. |
| `--bootstrap` | — | Answer "yes" to all prompts without asking (the default when there is no TTY, e.g. piped from `curl`). |
| `--no-bootstrap` | — | Answer "no" to all prompts: skip copying skills into `<config-dir>/skills/` and skip running `sync-all`. |

Example — pin a tag, full bootstrap, custom dirs:

```bash
curl -fsSL https://raw.githubusercontent.com/crestreach/cyncia/main/install/install.sh \
  | bash -s -- --ref v1.0.0 --config-dir my-config --cyncia-dir vendor/cyncia --bootstrap
```

Full installer reference (all flags, env vars, behavior on re-run): see
[`cyncia.md` → Install](cyncia.md#install).

## After installing

1. **Create a source tree** at `.agent-config/` (*only if skipped during the
   installer run*). Only `AGENTS.md` is required; every subfolder is optional:

   ```bash
   mkdir -p .agent-config/skills
   cp AGENTS.md .agent-config/AGENTS.md
   ```

2. **Install the `agent-conf-sync` skill** into your assistant so it can run
   syncs from natural language (*only if skipped during the installer run*).
   Copy it into your source tree, then sync:

   ```bash
   cp -R .cyncia/skills/agent-conf-sync .agent-config/skills/
   .cyncia/scripts/sync-all.sh -i "$PWD/.agent-config" -o "$PWD"
   ```

   You can also just **ask your AI assistant to do it**, e.g.:

   > Copy `.cyncia/skills/agent-conf-sync` into `.agent-config/skills/`,
   > then run `.cyncia/scripts/sync-all.sh -i .agent-config -o .` to install
   > the skill into every tool's native layout.

3. **(Optional, but recommended) Enable Cyncia's automatic agent behavior.** Paste the block
   below into **your** project's `AGENTS.md` (the source one, under
   `.agent-config/`) and re-run the sync. AI assistants will then know to
   author new rules/skills/agents/MCP servers under `.agent-config/` and
   re-run `sync-all` afterwards.

   > **Before pasting:** if you've changed the default locations — `.cyncia/`
   > for the cyncia checkout and `.agent-config/` for the authoring root —
   > update every path in the snippet (`.cyncia/…`, `.agent-config/…`) to
   > match your project's layout. Otherwise leave it as-is.

   ```markdown
   ## Agent configuration management (cyncia)

    This repo manages all of its AI-assistant configuration — guidelines (`AGENTS.md`), rules, skills, agents, and MCP servers — through [`.cyncia`](./.cyncia). The single generic source tree lives in [`.agent-config/`](./.agent-config); per-tool layouts (`.cursor/`, `.claude/`, `.github/`, `.junie/`, `.vscode/`, `.codex/`, `.agents/`, root `AGENTS.md`, `CLAUDE.md`) are generated from it. The `agent-conf-sync` skill invokes the sync via `.cyncia/scripts/sync-all.sh` (POSIX) or `.cyncia/scripts/sync-all.ps1` (Windows).

   When asked to **create or update** any of (or if any of the following gets updated):

   - a guideline (the root `AGENTS.md`)
   - a rule
   - a skill
   - a subagent
   - an MCP server entry

    read [`.cyncia/README.md`](./.cyncia/README.md) for the source-tree format (frontmatter fields, secret-token translation, agent ↔ MCP linkage), author the file under the appropriate folder of `.agent-config/` (`.agent-config/{rules,skills,agents,mcp-servers}/`), and then re-run the sync (skill `agent-conf-sync`) to fan it out to the per-tool directories. Do not hand-edit the generated `.cursor/`, `.claude/`, `.github/`, `.junie/`, `.vscode/`, `.codex/`, or `.agents/` files — they are overwritten on the next sync.
   ```

## Usage

Once the `agent-conf-sync` skill is installed (step 2 above), the easiest way
is to just **ask your AI assistant in plain language**:

- *"sync agent config"*
- *"regenerate Cursor rules"*
- *"clean sync for Copilot only"*
- *"sync `delegate-to-aside` for Cursor and Claude"*

The assistant infers the right flags and runs the script for you.

If you'd rather call the scripts directly:

```bash
# Sync everything for every supported tool
.cyncia/scripts/sync-all.sh -i .agent-config -o .

# Only some tools
.cyncia/scripts/sync-all.sh -i .agent-config -o . --tools cursor,claude

# Only some items (by name); --clean removes stale generated files
.cyncia/scripts/sync-all.sh -i .agent-config -o . --items delegate-to-aside --clean
```

Windows / PowerShell:

```powershell
.\.cyncia\scripts\sync-all.ps1 -InputRoot .agent-config -OutputRoot $PWD
```

A working source tree lives in [`examples/`](examples/) (and the one this repo
itself uses lives in [`.agent-config/`](.agent-config/)). Point `sync-all` at
either:

```bash
.cyncia/scripts/sync-all.sh -i .cyncia/examples -o /tmp/demo-out
```

## Default layout

```text
your-repo/
├── .agent-config/        # source of truth (you author these)
│   ├── AGENTS.md
│   ├── agents/
│   ├── skills/
│   ├── rules/
│   └── mcp-servers/
├── .cyncia/              # cyncia checkout (submodule / subtree / sparse clone)
│   ├── scripts/
│   └── skills/
├── .cursor/              # generated
├── .claude/              # generated
├── .github/              # generated (instructions, skills, agents, copilot-instructions.md)
├── .junie/               # generated
├── .codex/               # generated (agents + MCP config)
├── .agents/              # generated Codex skills
├── .vscode/mcp.json      # generated (when mcp-servers/ exists)
├── AGENTS.md             # generated (copy of .agent-config/AGENTS.md)
└── CLAUDE.md             # generated
```

## Configuration (`.cyncia/cyncia.conf`)

The installer creates `.cyncia/cyncia.conf` with sensible defaults and leaves
it alone on subsequent runs. When a new version of cyncia introduces a new
property the installer prompts you to add it (default **yes**); when a
property is no longer supported it prompts to remove it (default **no**).

Currently supported properties:

| Key | Default | Values | Effect |
|---|---|---|---|
| `claude_rules_mode` | `claude-md` | `claude-md`, `rule-files` | How `rules/<n>.md` is emitted for Claude Code. `claude-md` merges every rule body into `CLAUDE.md` (the previous behavior). `rule-files` writes each rule to `.claude/rules/<n>.md` and references it from `CLAUDE.md` via Claude Code's `@`-import syntax (`@.claude/rules/<n>.md`), so each rule is loaded by Claude Code with the same priority as `CLAUDE.md`. |

If the file or a property is missing, sync scripts use the built-in default.

## More

- **Detailed reference** — formats, frontmatter, MCP secret tokens,
  per-tool field map, scripts and flags, edge cases:
  **[`cyncia.md`](cyncia.md)**.
- **Per-tool field cheat sheet** — [`tools.md`](tools.md).
- **Pinned tool versions / doc snapshot** — [`tool-versions.md`](tool-versions.md).

## License

[MIT](LICENSE).
