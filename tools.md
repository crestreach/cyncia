# Tool-specific file reference

**Doc snapshot (UTC 2026-04-23):** see [`tool-versions.md`](tool-versions.md).

This is a compact reference for the four target tools (Cursor, Claude Code,
GitHub Copilot, Junie) and the four artifact types this repo syncs:
**guidelines**, **rules**, **skills**, and **agents**.

## Guidelines

| Tool | Native file | How this repo generates it |
|---|---|---|
| Cursor | `AGENTS.md` (root) | Copies `<source_root>/AGENTS.md` → `<output_root>/AGENTS.md` when roots differ |
| Claude Code | `CLAUDE.md` (root) | Writes from `<source_root>/AGENTS.md` + merged `rules/*.md` |
| GitHub Copilot | `.github/copilot-instructions.md` | Copies from `<source_root>/AGENTS.md` |
| Junie | `.junie/AGENTS.md` | Writes from `<source_root>/AGENTS.md` + merged `rules/*.md` |

## Rules

| Tool | Native per-rule file | What this repo does |
|---|---|---|
| Cursor | `.cursor/rules/<name>.mdc` | Generates from `rules/<name>.md` (frontmatter → Cursor frontmatter + body) |
| GitHub Copilot | `.github/instructions/<name>.instructions.md` | Generates from `rules/<name>.md` (frontmatter → `applyTo` + body) |
| Claude Code | *(none)* | Merges rule bodies into `CLAUDE.md` |
| Junie | *(none)* | Merges rule bodies into `.junie/AGENTS.md` |

**Rule field mapping (as implemented by the scripts):**

| Source (`rules/*.md`) | Cursor | Copilot | Claude / Junie merge |
|---|---|---|---|
| `description` | `description:` | — | shown as italic line |
| `applies-to` | `globs:` | `applyTo:` (unless `always-apply`) | not enforced |
| `always-apply: true` | `alwaysApply: true` | `applyTo: "**"` | not enforced |

## Skills

| Tool | Output path | Special handling in this repo |
|---|---|---|
| Cursor | `.cursor/skills/<name>/` | copies folder; strips `applies-to` from `SKILL.md` |
| Claude Code | `.claude/skills/<name>/` | copies folder; renames `applies-to` → `paths` in `SKILL.md` |
| GitHub Copilot | `.github/skills/<name>/` | copies folder; strips `applies-to` from `SKILL.md` |
| Junie | `.junie/skills/<name>/` | copies folder; strips `applies-to` from `SKILL.md` |

## Agents

| Tool | Output path | Notes |
|---|---|---|
| Cursor | `.cursor/agents/<name>.md` | file copy |
| Claude Code | `.claude/agents/<name>.md` | file copy |
| GitHub Copilot | `.github/agents/<name>.md` | file copy |
| Junie | `.junie/agents/<name>.md` | file copy |
