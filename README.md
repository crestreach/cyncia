# ai-dev-agent-config-sync

Tool-agnostic source of truth for AI coding-assistant configuration —
**agents**, **skills**, **rules/guidelines**, and a top-level **`AGENTS.md`** —
plus sync scripts that generate tool-specific files for **Cursor**,
**Claude Code**, **GitHub Copilot**, and **JetBrains Junie**.

Use it when you want to **author one set of agents/skills/rules once** (in a generic format),
then **sync** them into each tool’s native file layout automatically.

**Symlinking** generated paths from the submodule into
your tree works on macOS/Linux but is **brittle** on Windows and in CI; a fixed
submodule path is usually simpler. Individual tools also differ in **where**
they look for files and **what format** they expect, and some concepts exist in
only a subset of tools (so the sync scripts define **how each configuration is
mapped** into each tool’s native file set).

## Supported tools and versions

This repo is based on **vendor-documented behavior** for Cursor, Claude Code, GitHub Copilot, and JetBrains Junie.

- **Doc snapshot date:** **2026-04-23** (when the formats + behaviors in this README were last checked).
- **If something stops working after an update:** re-check the relevant vendor docs and adjust the scripts/docs here.
- **More detail:** pinned versions live in [`tool-versions.md`](tool-versions.md); a per-tool field reference lives in [`tools.md`](tools.md).

## Repository layout

### Your generic source tree (you author these)

You provide a **source root** directory to `sync-all` (or call per-tool scripts
directly). That root must contain:

| Path (relative to your source root) | Meaning |
|---|---|
| `AGENTS.md` | Project-wide guidelines (the “generic” source). |
| `agents/<name>.md` | One agent / subagent definition per file. |
| `skills/<name>/SKILL.md` | One skill per folder (Agent Skills format). |
| `rules/<name>.md` | One rule per file (generic frontmatter defined by this repo). |

In *this repository*, `_internal/` is just the authoring tree used to build the repo’s own generated outputs. You do **not** need (and usually should not use) `_internal/` in your own project — create your own source tree anywhere and point `-i`/`-InputRoot` script parameters at it.

### Generated outputs (written into your output root)

The sync scripts write tool-specific files under your **output root**:

| Generated from | Cursor | Claude Code | GitHub Copilot | JetBrains Junie |
|---|---|---|---|---|
| `agents/<name>.md` | `.cursor/agents/<name>.md` | `.claude/agents/<name>.md` | `.github/agents/<name>.md` | `.junie/agents/<name>.md` |
| `skills/<name>/…` | `.cursor/skills/<name>/…` | `.claude/skills/<name>/…` | `.github/skills/<name>/…` | `.junie/skills/<name>/…` |
| `rules/<name>.md` | `.cursor/rules/<name>.mdc` | *(not generated)* | `.github/instructions/<name>.instructions.md` | *(not generated)* |
| `AGENTS.md` | `AGENTS.md` (copied to output root when source root ≠ output root) | `CLAUDE.md` (generated from `AGENTS.md` + `rules/*.md`) | `.github/copilot-instructions.md` (copied from `AGENTS.md`) | `.junie/AGENTS.md` (generated from `AGENTS.md` + `rules/*.md`) |

Notes:

- **Claude rules:** rule bodies are appended into `CLAUDE.md` by `sync-agent-guidelines`.
- **Junie rules:** Junie has no per-rule file format, so rule bodies are appended into `.junie/AGENTS.md` by `sync-agent-guidelines` (and `sync-rules` remains a no-op).

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
its four modes (always / intelligent / glob / manual); see
[How each tool consumes content](#how-each-tool-consumes-the-generated-files).

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

## Generic fields and translation (summary)

### Rules (`rules/*.md`)

| Generic field | Cursor (`.mdc`) | Copilot (`.instructions.md`) | Claude / Junie |
|---------------|-----------------|------------------------------|----------------|
| `applies-to: "**/*.ts"` | `globs: **/*.ts` | `applyTo: "**/*.ts"` (unless `always-apply`) | skipped |
| `always-apply: true` | `alwaysApply: true` | `applyTo: "**"` | skipped |
| `description: "..."` | `description: ...` | not emitted (body only) | skipped |

### Skills (`skills/<name>/SKILL.md`)

| Generic field | Cursor | Claude Code | Copilot | Junie |
|---------------|--------|------------|---------|-------|
| `applies-to: "**/*.java"` | stripped | `paths: "**/*.java"` | stripped | stripped |

### Agents (`agents/*.md`)

Pass-through file copy. Tool-only frontmatter keys may be ignored by other tools
(they do not enforce behavior cross-tool).

## What loads when you open the project

| Kind | Auto-loaded / discovered | How it is used |
|------|-------------------------|----------------|
| **Guidelines** | Yes — `AGENTS.md` (Cursor), `CLAUDE.md` (Claude), `.github/copilot-instructions.md` (Copilot), and for **Junie** the first of: `.junie/AGENTS.md` → root `AGENTS.md` → legacy `guidelines` (see [Guidelines and memory](https://junie.jetbrains.com/docs/guidelines-and-memory.html)) | Merged into the model’s context for that workspace (exact mechanics depend on the product; Copilot may list them under Chat **References**). |
| **Rules** | Yes — where generated (`.cursor/rules/*.mdc`, `.github/instructions/*.instructions.md`) | Cursor/Copilot apply by `globs` / `applyTo` / `alwaysApply` and product-specific UI modes. |
| **Skills** | Yes — under each tool’s `skills/` tree | **Not** all injected every time: the agent **selects** skills by relevance (and Claude can additionally gate on `paths`). |
| **Agents** | Yes — each tool discovers `agents/*.md` copies | **Not** run automatically: they are **invoked** (picker, `/command`, delegate, or `@` name), depending on the product. |

If something does not show up, confirm the file path matches the
[Repository layout](#repository-layout) table, run `scripts/sync-all.sh`, and
re-check the [Documentation scope](#documentation-scope-and-re-verification) links
after a major IDE update.

## Scripts

Layout: one directory per tool, plus shared helpers.

```text
scripts/
├── common/                  # shared Bash + PowerShell utilities
│   ├── common.sh
│   └── common.ps1
├── cursor/
│   ├── sync-agents.{sh,ps1}
│   ├── sync-skills.{sh,ps1}
│   ├── sync-agent-guidelines.{sh,ps1}
│   └── sync-rules.{sh,ps1}
├── claude/        ...       # same four pairs
├── copilot/       ...
├── junie/         ...
├── sync-all.sh              # convenience: run every tool's four scripts
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

`sync-all` needs a **source root** that contains `agents/`, `rules/`, `skills/`, and `AGENTS.md`, and an **output root** (usually your project root).

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

This repo also ships the [`agent-conf-sync`](skills/agent-conf-sync/SKILL.md)
skill, so you don’t have to assemble CLI flags by hand. Once the skill is
installed for your AI coding assistant (Cursor, Claude Code, GitHub Copilot,
JetBrains Junie, …), describe the sync in plain language and the assistant will:

1. Detect whether to invoke `scripts/sync-all.sh` (macOS/Linux/Git Bash) or `scripts/sync-all.ps1` (Windows PowerShell).
2. Locate the script root (workspace root, a submodule path, or a search under the workspace).
3. Infer `-i`/`-o`, `--tools`, `--items`, and `--clean` from your request.
4. Run the script, capture output, and return a compact report (what was cleaned, what was written, and why).

Install the skill by syncing it into your assistant’s native layout the same way
you do with any other skill in this repo — e.g. point a run of `sync-all` at a
source tree that contains `skills/agent-conf-sync/` (this repo itself does), or
copy the folder into your own source tree’s `skills/`.

Example prompts (user) → what the assistant runs:

- “Sync everything for all tools from `_internal` into the repo root.”
  → `scripts/sync-all.sh -i <repo>/_internal -o <repo>`
- “Regenerate only Cursor and Claude for `delegate-to-aside`.”
  → `scripts/sync-all.sh -i <src> -o <out> --tools cursor,claude --items delegate-to-aside`
- “Clean sync for Copilot only.”
  → `scripts/sync-all.sh -i <src> -o <out> --tools copilot --clean` (with the
  `--clean` warning surfaced before running)
- “Same thing on Windows.”
  → `scripts\sync-all.ps1 -InputRoot <src> -OutputRoot <out> -Tools copilot -Clean`

If anything is ambiguous (missing input root, conflicting tool names), the skill
asks once instead of guessing. See the skill file for the full inference rules
and the required post-run report format.

## How each tool consumes the generated files

These scripts generate files in the locations each tool expects. For the full,
per-tool field reference, see [`tools.md`](tools.md).

- **Cursor:** uses root `AGENTS.md` plus `.cursor/agents/`, `.cursor/skills/`, `.cursor/rules/`.
- **Claude Code:** uses `CLAUDE.md` plus `.claude/agents/`, `.claude/skills/` (rules are written into CLAUDE.md).
- **GitHub Copilot:** uses `.github/copilot-instructions.md`, `.github/instructions/`, `.github/agents/`, `.github/skills/`.
- **Junie:** uses `.junie/AGENTS.md` plus `.junie/agents/`, `.junie/skills/` (rules are written into .junie/AGENTS.md).

## Adding content

Assuming your source root is `SOURCE_ROOT/`:

1. **New agent:** add `SOURCE_ROOT/agents/<name>.md`, then run `sync-agents` or `sync-all`.
2. **New skill:** add `SOURCE_ROOT/skills/<name>/SKILL.md` (and optional extra files), then run `sync-skills` or `sync-all`.
3. **New rule:** add `SOURCE_ROOT/rules/<name>.md`, then run `sync-rules` (Cursor/Copilot) or `sync-all` (Claude will pick it up via `sync-agent-guidelines`).
4. **Update guidelines:** edit `SOURCE_ROOT/AGENTS.md`, then run `sync-agent-guidelines` or `sync-all`.

## Using this repo inside another Git project

If your application already lives in its own Git repository, you can **pull in
this one** as a dependency and run the sync scripts from a subdirectory. The
usual choice is **Git submodule** (pin a commit, easy updates) or **Git subtree**
(no submodules; everything in one clone). Details: [Git Submodules](https://git-scm.com/book/en/v2/Git-Tools-Submodules), [Git subtree (Atlassian)](https://www.atlassian.com/git/tutorials/git-subtree).

### Git submodule

The parent repo records **which commit** of `ai-dev-agent-config-sync` it uses. Replace the
URL with your fork if needed (for example `https://github.com/arturolszak/ai-dev-agent-config-sync.git`).

```bash
# From the root of your other project
git submodule add https://github.com/arturolszak/ai-dev-agent-config-sync.git path/to/ai-dev-agent-config-sync
git commit -m "Add ai-dev-agent-config-sync as a submodule"
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
cd path/to/ai-dev-agent-config-sync
git fetch origin
git checkout main
git pull
cd -
git add path/to/ai-dev-agent-config-sync
git commit -m "Bump ai-dev-agent-config-sync submodule"
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
git subtree add --prefix=path/to/ai-dev-agent-config-sync https://github.com/arturolszak/ai-dev-agent-config-sync.git main --squash
```

**Update later** (may require merge conflict resolution):

```bash
git subtree pull --prefix=path/to/ai-dev-agent-config-sync https://github.com/arturolszak/ai-dev-agent-config-sync.git main --squash
```

**Trade-off:** One clone for everyone; updates are merges and can conflict.

### After vendoring: run sync and decide what to commit

From your project, with this repo at `path/to/ai-dev-agent-config-sync`:

```bash
path/to/ai-dev-agent-config-sync/scripts/sync-all.sh -i path/to/ai-dev-agent-config-sync/examples -o .
```

On Windows, use `path\to\ai-dev-agent-config-sync\scripts\sync-all.ps1`.

Then either **commit the generated** `.cursor/`, `.github/`, `.claude/`,
`.junie/`, and copies of guidelines in your app repo so the team gets them
without running scripts, **or** document that everyone must run `sync-all` after
updating the submodule.

### Quick choice

| Goal | Approach |
|------|----------|
| Pin versions, update with a few Git commands | **Submodule** |
| No submodules; single `git clone` for all developers | **Subtree** |
| Rare updates, minimal Git ceremony | Manual copy or occasional re-copy from a tarball/zip |

## License

This project is released under the [MIT License](LICENSE).
