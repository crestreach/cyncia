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
- **Git** — only for the install methods (submodule / subtree / sparse
  clone) described under [Using this repo inside another Git project](#using-this-repo-inside-another-git-project).
  Not needed at sync time.
- Standard POSIX utilities (`sed`, `awk`, `grep`, `find`, `cp`, `mv`) —
  already present on macOS, Linux, WSL, and Git Bash.

## Using this repo inside another Git project

If your application already lives in its own Git repository, you can **pull in
this one** as a dependency and run the sync scripts from a subdirectory.

There are three approaches in increasing order of Git ceremony:

1. **Minimal install** — download only `scripts/` and `skills/` from a tarball
   (simplest, no upstream tracking).
2. **Git submodule** — pin a commit, easy updates with a few Git commands.
3. **Git subtree** — no submodules; everything in one clone.

Reference docs: [Git Submodules](https://git-scm.com/book/en/v2/Git-Tools-Submodules),
[Git subtree (Atlassian)](https://www.atlassian.com/git/tutorials/git-subtree).

### Minimal install (only `scripts/` and `skills/`)

The simplest setup pulls **only the two directories you need** from a tagged
release or `main` into a directory of your choice (the examples use
`.cyncia/` at your project root — the default in this guide; you can pick any
name, it's just a plain subdirectory in your repo, not auto-tracked or
auto-linked to upstream).
Two equivalent variants:

#### Variant A — `git sparse-checkout` (two commands)

Shortest to type. Leaves a small `.git/` inside the target directory so you
can `git pull` to update.

```bash
git clone --depth=1 --filter=blob:none --sparse \
  https://github.com/crestreach/cyncia.git .cyncia
git -C .cyncia sparse-checkout set scripts skills
```

To pin a tag instead of `main`, add `--branch vX.Y.Z` to the `git clone` line.

**Update later:** `git -C .cyncia pull`.

#### Variant B — tarball (no `.git/` left behind)

Uses GitHub's tarball endpoint and extracts only `scripts/` and `skills/`.
No Git history, no submodule pointer — just two checked-in directories.

```bash
# From the root of your other project. Pick main, a branch, or a tag (vX.Y.Z).
REF=main
mkdir -p .cyncia
curl -sL "https://github.com/crestreach/cyncia/archive/${REF}.tar.gz" \
  | tar -xz --strip-components=1 -C .cyncia \
      "cyncia-${REF}/scripts" \
      "cyncia-${REF}/skills"
```

PowerShell equivalent (`tar` ships with Windows 10+):

```powershell
$Ref = 'main'
New-Item -ItemType Directory -Force .cyncia | Out-Null
Invoke-WebRequest "https://github.com/crestreach/cyncia/archive/$Ref.tar.gz" -OutFile cyncia.tgz
tar -xzf cyncia.tgz --strip-components=1 -C .cyncia `
  "cyncia-$Ref/scripts" `
  "cyncia-$Ref/skills"
Remove-Item cyncia.tgz
```

**Update later:** rerun the same command. The two directories are
overwritten in place. Commit the diff if anything changed.

**Trade-off (both variants):** No upstream provenance in your project's Git
history (variant A keeps a small `.git/` inside the target directory only),
no automatic update notifications. You decide when to refresh. For most
consumers this is the right default.

### Git submodule

The parent repo records **which commit** of `cyncia` it uses. Replace the URL
with your fork if needed.

```bash
# From the root of your other project
git submodule add https://github.com/crestreach/cyncia.git .cyncia
git commit -m "Add cyncia as a submodule"
```

**Cloning a project that already has submodules:**

```bash
git clone --recurse-submodules https://github.com/yourorg/your-app.git
# or after a normal clone:
git submodule update --init --recursive
```

**Update the submodule to the latest on `main`**, then commit the new pointer in
the parent:

```bash
cd .cyncia
git fetch origin
git checkout main
git pull
cd -
git add .cyncia
git commit -m "Bump cyncia submodule"
```

To **pin a release**, check out a tag inside the submodule (`git checkout v1.2.3`)
and commit the parent.

**Trade-off:** Clear provenance and version pins; teammates must run
`submodule update` when they pull. Submodules typically include the **whole**
upstream repository; to use only part of it, keep the full submodule and run
sync from it, or maintain a small copy script (see below).

### Git subtree

Upstream is merged into a **prefix directory** inside your single repository;
`git clone` of your app does not need `--recurse-submodules`.

```bash
git subtree add --prefix=.cyncia https://github.com/crestreach/cyncia.git main --squash
```

**Update later** (may require merge conflict resolution):

```bash
git subtree pull --prefix=.cyncia https://github.com/crestreach/cyncia.git main --squash
```

**Trade-off:** One clone for everyone; updates are merges and can conflict.

### After downloading

After the files are in your project (via any of the three methods above), you
typically want the **`agent-conf-sync` skill** itself installed into each tool's
native layout so your AI assistant can run future syncs from natural language.

The recommended pattern is to **copy the skill into your own source tree first**
(so it survives future upstream updates and you can edit it), then run
`sync-all` from that source tree:

```bash
# 1. Make sure your source tree has a skills/ directory and AGENTS.md.
#    If you don't have a source tree yet, create the bare minimum:
mkdir -p .agent-config/skills
[ -f .agent-config/AGENTS.md ] || echo "# Project guidelines" > .agent-config/AGENTS.md

# 2. Copy the skill into your source tree.
cp -R .cyncia/skills/agent-conf-sync .agent-config/skills/

# 3. Sync it into every tool's native layout (.cursor, .claude, .github, .junie).
.cyncia/scripts/sync-all.sh -i "$PWD/.agent-config" -o "$PWD"
```

Or for a single tool only (e.g. just Claude Code):

```bash
.cyncia/scripts/sync-all.sh -i "$PWD/.agent-config" -o "$PWD" --tools claude
```

PowerShell:

```powershell
New-Item -ItemType Directory -Force .agent-config\skills | Out-Null
if (-not (Test-Path .agent-config\AGENTS.md)) { '# Project guidelines' | Set-Content .agent-config\AGENTS.md }
Copy-Item -Recurse .cyncia\skills\agent-conf-sync .agent-config\skills\
.\.cyncia\scripts\sync-all.ps1 -InputRoot "$PWD\.agent-config" -OutputRoot $PWD
```

Or just **ask your AI assistant to do it**, e.g.:

> Copy `.cyncia/skills/agent-conf-sync` into `.agent-config/skills/`, then run
> `.cyncia/scripts/sync-all.sh -i .agent-config -o .` to install the skill into
> every tool's native layout.

After this, your assistant has the skill loaded and you can ask it in plain
language to *“sync agent config”*, *“regenerate Cursor rules”*, etc.

### Enable Cyncia's automatic behavior in your repo

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

### After vendoring: run sync and decide what to commit

From your project, with this repo at `.cyncia/`:

```bash
.cyncia/scripts/sync-all.sh -i .agent-config -o .
```

On Windows, use `.cyncia\scripts\sync-all.ps1`.

Then either **commit the generated** `.cursor/`, `.github/`, `.claude/`,
`.junie/`, and copies of guidelines in your app repo so the team gets them
without running scripts, **or** document that everyone must run `sync-all` after
updating the submodule.

### Quick choice

| Goal | Approach |
|------|----------|
| Smallest footprint, only `scripts/` + `skills/`, no upstream tracking | **Minimal install** (sparse / tarball) |
| Pin versions, update with a few Git commands | **Submodule** |
| No submodules; single `git clone` for all developers | **Subtree** |

## License

This project is released under the [MIT License](LICENSE).
