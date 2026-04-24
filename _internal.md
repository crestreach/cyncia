# Sync from `_internal/`

Authoring for this repository lives under **`_internal/`**: **`AGENTS.md`**, **`agents/`**, **`rules/`**, and **`skills/`**.

## One command (repository root)

**Bash (macOS / Linux):**

```bash
./scripts/sync-all.sh -i "$PWD/_internal" -o "$PWD"
```

**PowerShell:**

```powershell
.\scripts\sync-all.ps1 -InputRoot "$PWD\_internal" -OutputRoot $PWD
```

To **drop stale generated files** (e.g. after removing an agent or rule from `_internal/`), add `--clean` (Bash) or `-Clean` (PowerShell) to `sync-all` or to an individual `scripts/<tool>/sync-*.{sh,ps1}`. See [`README.md` — Common flags](README.md#common-flags).

That run walks each tool (agents, skills, `sync-agent-guidelines`, rules).  
Each **`sync-agent-guidelines`** step copies **`_internal/AGENTS.md` →** root **`AGENTS.md`** when the input and output directories differ (so the first time roots differ, you get up to four identical copies in one `sync-all`—harmless). If input and output are the same directory, the copy is skipped.

Then you get **`.cursor/`**, **`.claude/`**, **`.github/`**, **`.junie/`**, **`CLAUDE.md`**, etc., from the same source tree.

**Source of truth for guidelines:** **`_internal/AGENTS.md`**. Edit that file, then re-run the command above.

Full detail: [`README.md`](README.md).
