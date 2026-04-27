# cyncia

Tool-agnostic source of truth for AI coding-assistant configuration —
**agents**, **skills**, **rules/guidelines**, a top-level **`AGENTS.md`**, and
**MCP servers** — plus sync scripts that generate tool-specific files for
**Cursor**, **Claude Code**, **GitHub Copilot**, **VS Code**, and
**JetBrains Junie**.

**Why it exists.** Each of those tools looks in a **different place**, expects
a **different file format**, and has its own **frontmatter keys** (and some
concepts — like `paths`-gated skills or per-agent MCP allowlists — only exist
in a subset). Maintaining the same agent / skill / rule across all of them by
hand means either copy-paste drift or only supporting one tool. Cyncia lets
you author each thing **once** in a generic format, then **mechanically
translate** paths and frontmatter for every tool you care about.

This document is the **full reference and source of truth**. For a short
quickstart, see [`README.md`](README.md).

## Supported tools and versions

This repo is based on **vendor-documented behavior** for Cursor, Claude Code, GitHub Copilot, VS Code, and JetBrains Junie.

- **Doc snapshot date:** **2026-04-24** (when the formats + behaviors in this README were last checked).
- **If something stops working after an update:** re-check the relevant vendor docs and adjust the scripts/docs here.
- **More detail:** pinned versions live in [`tool-versions.md`](tool-versions.md); a per-tool field reference lives in [`tools.md`](tools.md).

## What it does

You author one source tree:

```text
.agent-config/
├── AGENTS.md                 # project-wide guidelines
├── agents/<name>.md          # one subagent per file
├── skills/<name>/SKILL.md    # one skill per folder
├── rules/<name>.md           # one rule per file
└── mcp-servers/<name>.json   # one MCP server per file
```

Cyncia generates the per-tool files:

| Source                  | Cursor                               | Claude Code                  | GitHub Copilot                                | VS Code             | JetBrains Junie                |
| ----------------------- | ------------------------------------ | ---------------------------- | --------------------------------------------- | ------------------- | ------------------------------ |
| `AGENTS.md`             | `AGENTS.md`                          | `CLAUDE.md`                  | `.github/copilot-instructions.md`             | —                   | `.junie/AGENTS.md`             |
| `agents/<n>.md`         | `.cursor/agents/<n>.md`              | `.claude/agents/<n>.md`      | `.github/agents/<n>.md`                       | —                   | `.junie/agents/<n>.md`         |
| `skills/<n>/`           | `.cursor/skills/<n>/`                | `.claude/skills/<n>/`        | `.github/skills/<n>/`                         | —                   | `.junie/skills/<n>/`           |
| `rules/<n>.md`          | `.cursor/rules/<n>.mdc`              | merged into `CLAUDE.md`      | `.github/instructions/<n>.instructions.md`    | —                   | merged into `.junie/AGENTS.md` |
| `mcp-servers/<n>.json`  | `.cursor/mcp.json`                   | `.mcp.json`                  | (uses VS Code's `.vscode/mcp.json`)           | `.vscode/mcp.json`  | stdout snippet                 |

**How each tool picks the generated files up:**

- **Guidelines** (`AGENTS.md` / `CLAUDE.md` / `.github/copilot-instructions.md` / `.junie/AGENTS.md`) are auto-loaded by the matching tool. Junie resolves the first of: `.junie/AGENTS.md` → root `AGENTS.md` → legacy `guidelines` (see [Guidelines and memory](https://junie.jetbrains.com/docs/guidelines-and-memory.html)).
- **Rules** are auto-applied per `globs` / `applyTo` / `alwaysApply` (Cursor and Copilot). Claude and Junie merge rule bodies into their guidelines file.
- **Skills** are discovered automatically but **not all injected every time** — the agent selects skills by relevance (Claude can additionally gate by `paths`).
- **Agents** are discovered, but **not run automatically**: they’re invoked (picker, `/command`, delegate, or `@name`).

Along the way, **frontmatter is rewritten** to each tool's native shape (full
detail in the per-format sections below):

| Generic key (where) | Cursor | Claude Code | GitHub Copilot | VS Code | Junie |
|---|---|---|---|---|---|
| `applies-to` (rule) | `globs:` | merged into `CLAUDE.md` | `applyTo:` | — | merged into `.junie/AGENTS.md` |
| `always-apply` (rule) | `alwaysApply:` | — | (implied via `applyTo: "**"`) | — | — |
| `applies-to` (skill) | stripped | `paths:` | stripped | — | stripped |
| `mcp-servers` (agent) | stripped | `mcpServers: [...]` | `tools: ["a/*", ...]` | — | stripped |
| `${secret:NAME}` (mcp) | `${env:NAME}` | `${NAME}` | — | `${input:NAME}` + `inputs[]` | snippet only |
| `${secret:NAME?optional}` (mcp) | `${env:NAME}` | `${NAME:-}` | — | `${input:NAME}` (optional) | snippet only |

Default project layout (after install + sync):

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
├── .vscode/mcp.json      # generated (when mcp-servers/ exists)
├── AGENTS.md             # generated (copy of .agent-config/AGENTS.md)
└── CLAUDE.md             # generated
```

For the per-tool field cheat sheet, see [`tools.md`](tools.md).

## Adding content

Assuming your source root is `.agent-config/` (adjust if you use a different
path), the format details for each kind live in the sections below.

| Add this | Where | Then run |
|---|---|---|
| **Agent** | `.agent-config/agents/<name>.md` | `sync-agents` or `sync-all` |
| **Skill** | `.agent-config/skills/<name>/SKILL.md` (+ optional extras) | `sync-skills` or `sync-all` |
| **Rule** | `.agent-config/rules/<name>.md` | `sync-rules` (Cursor/Copilot) or `sync-all` |
| **MCP server** | `.agent-config/mcp-servers/<name>.json` | `sync-mcp` or `sync-all` (needs `jq` for Bash) |
| **Guideline** edit | `.agent-config/AGENTS.md` | `sync-agent-guidelines` or `sync-all` |

## Internal format: rules in `rules/`

One Markdown file per rule: YAML **frontmatter** between `---` lines, then the
body. The **generic** keys are defined by this repository (not a published
standard) so one source can feed all the tools.

| Field | Type | Required | Meaning |
|-------|------|----------|---------|
| `description` | string | recommended | Shown in Cursor as the rule’s description; also used as fallback title if the filename is not enough. If empty, the sync uses the basename. |
| `applies-to` | string | optional | Comma-separated **glob** patterns, **without** wrapping the whole value in extra quotes. Example: `**/*.java,**/*.kt`. Maps to Cursor `globs` and to Copilot `applyTo` (unless overridden below). Omitted = no file filter in Cursor’s output (rule still can be “always on” or description-driven; see [Cursor rule activation](https://cursor.com/docs/rules)). |
| `always-apply` | boolean | optional | If exactly `true`, the rule is always injected (Cursor: `alwaysApply: true`). For Copilot, `always-apply: true` forces `applyTo: "**"` and wins over `applies-to`. Any other / missing value is treated as `false` in Cursor. |

Example:

```markdown
---
description: Short sentence about when the rule applies.
applies-to: "**/*.ts,**/*.tsx"   # optional; comma-separated globs, no extra wrapping quotes
always-apply: false              # optional; true = always on (overrides applies-to for Copilot output)
---

# Rule title

- Bullet 1
- Bullet 2
```

| Where it lands | Path | Notes |
|----------------|------|--------|
| Cursor | `.cursor/rules/<name>.mdc` | `description`, optional `globs` from `applies-to`, `alwaysApply` from `always-apply` (default `false` if not exactly `true`). |
| GitHub Copilot | `.github/instructions/<name>.instructions.md` | `applyTo`: `**` if `always-apply: true`; else `applies-to` if set; else `**` (see resolution below). |
| Claude Code | *(no per-rule file)* | Bodies are merged into `CLAUDE.md` (with `AGENTS.md`) by `sync-agent-guidelines`. |
| Junie | *(no per-rule file)* | Bodies are merged into `.junie/AGENTS.md` via `sync-agent-guidelines`. |

**Copilot `applyTo` resolution** (implemented in `scripts/copilot/sync-rules.{sh,ps1}`):

1. If `always-apply: true` → `applyTo: "**"`.
2. Else if `applies-to` is non-empty → `applyTo` = that string (unchanged, quoted in output).
3. Else → `applyTo: "**"` (whole workspace).

**Cursor output** (implemented in `scripts/cursor/sync-rules.{sh,ps1}`): frontmatter
always includes `description`, `alwaysApply: true` or `false`, and `globs:`
**only** when `applies-to` was set in the source. Cursor then applies rules per
its four modes (always / intelligent / glob / manual); see the
[generated outputs table](#what-it-does).

## Internal format: skills in `skills/`

- **Base:** [Agent Skills spec](https://agentskills.io/specification) — at minimum
  `name` and `description` in YAML frontmatter, then Markdown body.
- **Optional in this repo only:** `applies-to` — **not** part of the open spec.
  It is a **portable** stand-in for “only auto-activate when these paths matter.”
  On sync, it is:
  - **Claude Code:** renamed to `paths` (native per-skill glob gating; see
    [Claude skills doc](https://code.claude.com/docs/en/skills)).
  - **Cursor, Copilot, Junie:** **removed** from the generated `SKILL.md`, because
    those products do not document an equivalent on skills. If you need hard
    file scoping in Cursor/Copilot, model it as a **rule** under `rules/` using
    `applies-to`.

Other frontmatter keys (`argument-hint`, `disable-model-invocation`, Copilot
`user-invokable`, Claude `allowed-tools`, etc.) are passed through **unchanged**
to every tool’s copy; tools ignore keys they do not support.

## Internal format: MCP servers

Optional. If `<source_root>/mcp-servers/` exists, `sync-all` will generate the
appropriate MCP config file for every tool that supports a project-level config
(Cursor, Claude Code, VS Code). `.vscode/mcp.json` belongs to **VS Code** —
GitHub Copilot Chat in VS Code reads the same file but does not define the
format, so it is written by the `vscode` tool, not by `copilot`. For Junie —
which has no project-level MCP file as of the documented version — the snippet
is printed to stdout for manual paste.

### Source format

One JSON file per server: `<source_root>/mcp-servers/<name>.json`. The file
basename becomes the server name. The body is the per-server config object
(no `mcpServers` wrapper).

Example — `mcp-servers/context7.json`:

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

Example — `mcp-servers/httpbin.json`:

```json
{
  "type": "http",
  "url": "https://httpbin.example/api",
  "headers": {
    "Authorization": "Bearer ${secret:HTTPBIN_TOKEN}"
  }
}
```

### Secret tokens

Two interpolation tokens are recognised inside string values **anywhere** in the
JSON (env values, args, headers, urls, …):

| Token | Meaning |
|-------|---------|
| `${secret:NAME}` | **Required** secret. Each tool emits its native form (see translation table). |
| `${secret:NAME?optional}` | **Optional** secret. The translated form is safe-empty (e.g. Bash default `${NAME:-}`, VS Code input with `default: ""`). |

`NAME` must match `[A-Za-z_][A-Za-z0-9_]*`.

### Translation per tool

| Tool | Output | Container | Required `${secret:NAME}` | Optional `${secret:NAME?optional}` |
|---|---|---|---|---|
| Cursor | `.cursor/mcp.json` | `mcpServers` | `${env:NAME}` | `${env:NAME}` |
| Claude Code | `.mcp.json` (project root) | `mcpServers` | `${NAME}` | `${NAME:-}` |
| VS Code (incl. Copilot Chat in VS Code) | `.vscode/mcp.json` | `servers` + `inputs[]` | `${input:NAME}` (+ `inputs[]` entry, `password: true`) | `${input:NAME}` (+ `inputs[]` entry, `password: true`, `default: ""`) |
| Junie | *(stdout only)* | `mcpServers` | passed through verbatim | passed through verbatim |

`sync-mcp` always **replaces** the target file (it does not merge with
hand-edited entries). Re-running with `--items <subset>` produces a smaller
file, not a partial one. With `--clean`, an empty filtered set **removes** the
target file.

### Agent ↔ MCP server linkage

Agent frontmatter may declare which MCP servers it expects, using the generic
key `mcp-servers` (a comma-separated string of server names). Each tool
translates this key when copying the agent file:

```markdown
---
name: aside
description: Side question agent.
mcp-servers: "context7, memory"
---
```

| Tool | Resulting frontmatter |
|---|---|
| Cursor | `mcp-servers` is **stripped** (no documented per-agent MCP gating) |
| Claude Code | `mcpServers: [context7, memory]` |
| GitHub Copilot | `tools: ["context7/*", "memory/*"]` |
| Junie | `mcp-servers` is **stripped** |

If a Copilot agent file already has its own `tools:` key **and** `mcp-servers:`,
`sync-agents` exits with an error so you can merge them by hand.

### MCP-specific limits

- Junie has no project-level MCP file in the documented version; `sync-mcp`
  prints the merged JSON to stdout so you can paste it under
  *Settings | Tools | AI Assistant | Model Context Protocol (MCP)*.

If something does not show up after a sync, confirm the file path matches the
[generated outputs table](#what-it-does), then re-run `sync-all.sh`.

## Scripts

Layout: one directory per tool, plus shared helpers.

```text
scripts/
├── common/                  # shared Bash + PowerShell utilities
│   ├── common.sh
│   ├── common.ps1
│   ├── mcp.sh
│   └── mcp.ps1
├── cursor/
│   ├── sync-agents.{sh,ps1}
│   ├── sync-skills.{sh,ps1}
│   ├── sync-agent-guidelines.{sh,ps1}
│   ├── sync-rules.{sh,ps1}
│   └── sync-mcp.{sh,ps1}
├── claude/        ...       # same five pairs
├── copilot/       ...
├── junie/         ...
├── sync-all.sh              # convenience: run every tool's scripts
└── sync-all.ps1
```

### Common flags

Per-tool scripts:

- `--items a,b,c` (Bash) / `-Items a,b,c` (PowerShell): subset of agents /
  skills / rule names. Default: all.
- `--clean` (Bash) / `-Clean` (PowerShell): before writing, **remove existing
  files** in that script’s output location (agents folder, skills folder, rules
  folder, and/or specific guideline files—see the script’s header comment).
  Default is **off** (overwrites in place only). Use this when you have **removed**
  a source file and want the old generated copy to disappear instead of lingering
  next to the new outputs. **Warning:** each per-tool script empties its entire
  output directory before writing — `.cursor/{agents,rules,skills}`,
  `.claude/{agents,skills}`, `.github/{agents,instructions,skills}`, and
  `.junie/{agents,skills}`. Any hand-authored files placed there will be lost.
  This is especially easy to overlook under `.github/` (for Copilot), where
  unrelated content is commonly kept. Keep only sync-generated files in these
  directories, or do not use `--clean` for the affected step.
- `--help` / `-h`

`sync-all` adds:

- `--tools cursor,claude,copilot,junie` / `-Tools ...` (default: all four)
- `--clean` / `-Clean` is forwarded to **every** per-tool script in the run (same
  semantics as above).

The Claude and Junie **`sync-rules`** scripts are no-ops (rules are merged in
`sync-agent-guidelines`); they accept `--clean` for a uniform CLI but perform
no deletions.

### Examples — macOS / Linux

`sync-all` needs a **source root** containing `AGENTS.md` (and optionally any of `agents/`, `rules/`, `skills/`, `mcp-servers/`), and an **output root** (usually your project root).

```bash
# Regenerate everything for every tool (source tree → output root)
scripts/sync-all.sh -i "/path/to/your/source-root" -o "$PWD"

# Same, using the examples/ tree instead
scripts/sync-all.sh -i "$PWD/examples" -o "$PWD"

# Only Cursor + Claude, and only one selected item name
scripts/sync-all.sh -i "/path/to/your/source-root" -o "$PWD" --tools cursor,claude --items delegate-to-aside

# Prune stale generated files in each tool output dir (see “Common flags”)
scripts/sync-all.sh -i "/path/to/your/source-root" -o "$PWD" --clean

# Run a single step directly
scripts/cursor/sync-rules.sh -i "/path/to/your/source-root/rules" -o "$PWD"
scripts/copilot/sync-skills.sh -i "/path/to/your/source-root/skills" -o "$PWD" --items delegate-to-aside
scripts/claude/sync-agent-guidelines.sh -i "/path/to/your/source-root" -o "$PWD"
```

### Examples — Windows PowerShell

```powershell
.\scripts\sync-all.ps1 -InputRoot "C:\path\to\your\source-root" -OutputRoot $PWD
.\scripts\sync-all.ps1 -InputRoot "$PWD\examples" -OutputRoot $PWD
.\scripts\sync-all.ps1 -InputRoot "C:\path\to\your\source-root" -OutputRoot $PWD -Tools cursor,claude -Items delegate-to-aside
.\scripts\sync-all.ps1 -InputRoot "C:\path\to\your\source-root" -OutputRoot $PWD -Clean

.\scripts\cursor\sync-rules.ps1 -InputPath "C:\path\to\your\source-root\rules" -OutputPath $PWD
.\scripts\copilot\sync-skills.ps1 -InputPath "C:\path\to\your\source-root\skills" -OutputPath $PWD -Items delegate-to-aside
.\scripts\claude\sync-agent-guidelines.ps1 -InputPath "C:\path\to\your\source-root" -OutputPath $PWD
```

## Running the sync from an AI assistant (`agent-conf-sync` skill)

This repo ships the [`agent-conf-sync`](skills/agent-conf-sync/SKILL.md) skill,
so you don’t have to assemble CLI flags by hand. Once the skill is installed
for your AI coding assistant, describe the sync in plain language and it will
run the right command for you.

Example prompts:

- *“sync agent config”* → `sync-all` for every tool, in place.
- *“regenerate Cursor rules”* → `sync-all --tools cursor` (rules step only).
- *“clean sync for Copilot only”* → `sync-all --tools copilot --clean` (with the `--clean` warning surfaced before running).
- *“sync `delegate-to-aside` for Cursor and Claude”* → `sync-all --tools cursor,claude --items delegate-to-aside`.

**Inference rules the skill follows** (see [`skills/agent-conf-sync/SKILL.md`](skills/agent-conf-sync/SKILL.md) for the authoritative version):

1. Detect the platform and pick `sync-all.sh` (macOS/Linux/Git Bash) or `sync-all.ps1` (Windows PowerShell).
2. Locate the script root (workspace root, a submodule path, or a search under the workspace).
3. Infer `-i` / `-o`, `--tools`, `--items`, and `--clean` from your request or information in AGENTS.md.
4. Run the script, capture output, return a compact report (what was cleaned, what was written, and why).
5. If anything is ambiguous (missing input root, conflicting tool names) — ask once instead of guessing.

## Dependencies

- **Bash 4+** (macOS / Linux / WSL / Git Bash) — required by `scripts/**/*.sh`
  (the scripts use `[[ ]]`, `shopt -s nullglob`, associative arrays).
- **PowerShell 5.1+** or **PowerShell 7+** (Windows / cross-platform) —
  required by `scripts/**/*.ps1`.
- **`jq` 1.6+** — required only by the MCP sync step; the Bash side calls
  `require_jq` and exits with a clear message if it is missing. Install via
  `brew install jq`, `apt-get install jq`, or `winget install jqlang.jq`.
  - The MCP step is **skipped entirely** when `<source_root>/mcp-servers/`
    does not exist, so projects without MCP servers do not need to create
    the directory — and do not need `jq` at all.
- **Git** — not required by the installer or by sync time. Only needed if you
  want to track this repo via your own Git workflow.
- Standard POSIX utilities (`sed`, `awk`, `grep`, `find`, `cp`, `mv`) —
  already present on macOS, Linux, WSL, and Git Bash.

## Install

The recommended way to install or update cyncia in a project is the bundled
installer script:

```bash
curl -fsSL https://raw.githubusercontent.com/crestreach/cyncia/main/install/install.sh | bash
```

It is **idempotent**: running it again later upgrades `.cyncia/` to the latest
snapshot of the chosen ref and offers to refresh skills you previously copied
into `.agent-config/skills/`.

### What the installer does

In order, the script:

1. **Prepares the source tree** at `<config-dir>/` (default `.agent-config/`).
   Creates `agents/`, `skills/`, `rules/`, `mcp-servers/` if missing. Writes a
   stub `AGENTS.md` only if no `AGENTS.md` already exists — never overwrites
   your guidelines.
2. **Downloads a snapshot** of cyncia from
   `https://github.com/<repo>/archive/<ref>.tar.gz` (default `crestreach/cyncia`
   @ `main`) and copies `scripts/`, `skills/`, `examples/`, `README.md`, and
   `cyncia.md` into `<cyncia-dir>/` (default `.cyncia/`). Existing `scripts/`,
   `skills/`, and `examples/` trees in `<cyncia-dir>/` are removed first so
   deletions upstream propagate; `README.md` and `cyncia.md` are overwritten
   in place.
3. **Records the installed version** to `<cyncia-dir>/VERSION`. For an
   explicit `--ref` (tag or non-default branch) the file contains that ref
   verbatim. For the default `main` branch the installer best-effort queries
   the GitHub API for tags pointing at `HEAD`; if any are found, those tag
   names are written (one per line). On API failure or when no tags match,
   the file falls back to `main`.
4. **Optionally copies bundled skills** from `<cyncia-dir>/skills/` into
   `<config-dir>/skills/`. Skills are split into two prompts: missing-here
   skills (offered as a copy) and already-present skills (offered as an
   overwrite-with-upstream).
5. **Optionally runs `sync-all`**:
   `bash <cyncia-dir>/scripts/sync-all.sh -i <config-dir> -o .`
6. **Prints a `jq` notice** (only required by the MCP sync step) with
   per-OS install commands.
7. **Prints the "After installing" section** read directly from the freshly
   downloaded `<cyncia-dir>/README.md`, so the post-install guidance stays
   in sync with the upstream docs.

### Flags and environment

| Flag | Default | Effect |
|---|---|---|
| `--config-dir PATH` | `.agent-config` | Authoring source tree. |
| `--cyncia-dir PATH` | `.cyncia` | Where the cyncia checkout lives. |
| `--ref REF` | `main` | Git branch or tag to download. Tags drop a leading `v` in the GitHub tarball prefix; the script handles that. |
| `--repo OWNER/NAME` | `crestreach/cyncia` | GitHub repo to download from. |
| `--bootstrap` | — | Answer **yes** to every prompt without asking. This is also the default behavior when there is no TTY (e.g. piped from `curl`); use this flag to be explicit in scripts. |
| `--no-bootstrap` | — | Answer **no** to every prompt: skip copying skills into `<config-dir>/skills/` and skip running `sync-all`. |
| `-h`, `--help` | — | Print usage and exit. |

| Env var | Equivalent flag |
|---|---|
| `CYNCIA_REPO` | `--repo` |
| `CYNCIA_REF`  | `--ref`  |

Both prompts default to **yes**. When `bash` is connected to a terminal,
prompts read from `/dev/tty` so `curl … \| bash` still allows interactive
answers — pressing Enter (empty reply) accepts; type `n` to decline. When
there is no TTY and neither `--bootstrap` nor `--no-bootstrap` was passed,
the script proceeds with **yes** for each prompt; pass `--no-bootstrap` to
opt out without typing.

Required tools on the host running the installer: `bash`, `curl`, `tar`,
`mktemp`, `find`.

### Examples

Interactive (prompts for skill copy and `sync-all`):

```bash
curl -fsSL https://raw.githubusercontent.com/crestreach/cyncia/main/install/install.sh | bash
```

One-shot bootstrap (no prompts, do everything):

```bash
curl -fsSL https://raw.githubusercontent.com/crestreach/cyncia/main/install/install.sh \
  | bash -s -- --bootstrap
```

Pin a release, custom directories:

```bash
curl -fsSL https://raw.githubusercontent.com/crestreach/cyncia/main/install/install.sh \
  | bash -s -- --ref v1.0.0 --config-dir my-config --cyncia-dir vendor/cyncia --bootstrap
```

Run from a fork or branch:

```bash
curl -fsSL https://raw.githubusercontent.com/yourorg/cyncia/feature-x/install/install.sh \
  | bash -s -- --repo yourorg/cyncia --ref feature-x
```

Update an existing checkout to the latest `main`:

```bash
curl -fsSL https://raw.githubusercontent.com/crestreach/cyncia/main/install/install.sh | bash
```

This re-downloads the tarball, replaces `<cyncia-dir>/scripts` and
`<cyncia-dir>/skills`, and asks whether to overwrite the skills you keep
under `<config-dir>/skills/`.

### After installing

The installer already performs steps 1 and 2 below when you accept its prompts
(or pass `--bootstrap`). The notes are kept here for runs where those prompts
were declined, or for projects vendored without the installer.

1. **Create a source tree** at `<config-dir>/` (*only if skipped during the
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

   PowerShell:

   ```powershell
   Copy-Item -Recurse .cyncia\skills\agent-conf-sync .agent-config\skills\
   .\.cyncia\scripts\sync-all.ps1 -InputRoot "$PWD\.agent-config" -OutputRoot $PWD
   ```

3. **(Optional, but recommended) Enable Cyncia's automatic agent behavior in your repo.**

To make any AI assistant working in your project pick up the Cyncia workflow
automatically (read the source-tree format, author files under your authoring
root, then re-run the sync), paste the block below into your repository's
root `AGENTS.md` (or its source equivalent — e.g. `.agent-config/AGENTS.md`
if you author guidelines from `.agent-config/`, then re-run `sync-all`).

> **Before pasting:** if you've changed the default locations — `.cyncia/`
> for the cyncia checkout and `.agent-config/` for the authoring root —
> update every path in the snippet (`.cyncia/…`, `.agent-config/…`) to
> match your project's layout. Otherwise leave it as-is.

```markdown
## Agent configuration management (cyncia)

This repo manages all of its AI-assistant configuration — guidelines (`AGENTS.md`), rules, skills, agents, and MCP servers — through [`.cyncia`](./.cyncia). The single generic source tree lives in [`.agent-config/`](./.agent-config); per-tool layouts (`.cursor/`, `.claude/`, `.github/`, `.junie/`, `.vscode/`, root `AGENTS.md`, `CLAUDE.md`) are generated from it. The `agent-conf-sync` skill invokes the sync via `.cyncia/scripts/sync-all.sh` (POSIX) or `.cyncia/scripts/sync-all.ps1` (Windows).

When asked to **create or update** any of (or if any of the following gets updated):

- a guideline (the root `AGENTS.md`)
- a rule
- a skill
- a subagent
- an MCP server entry

read [`.cyncia/README.md`](./.cyncia/README.md) for the source-tree format (frontmatter fields, secret-token translation, agent ↔ MCP linkage), author the file under the appropriate folder of `.agent-config/` (`.agent-config/{rules,skills,agents,mcp-servers}/`), and then re-run the sync (skill `agent-conf-sync`) to fan it out to the per-tool directories. Do not hand-edit the generated `.cursor/`, `.claude/`, `.github/`, `.junie/`, `.vscode/` files — they are overwritten on the next sync.
```

Then either **commit the generated** `.cursor/`, `.github/`, `.claude/`,
`.junie/`, `AGENTS.md`, and `CLAUDE.md` so the team gets them without running
scripts, **or** document that everyone must run `sync-all` after pulling.

## License

This project is released under the [MIT License](LICENSE).
