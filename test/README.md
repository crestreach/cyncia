# Tests (isolated to `test/`)

## Prerequisites

- **Bash tests:** [bats-core](https://github.com/bats-core/bats-core)  
  - macOS: `brew install bats-core`
- **PowerShell tests:** [Pester](https://pester.dev/) v5+  
  - `Install-Module Pester -Scope CurrentUser -MinimumVersion 5.0.0 -Force`

## Run

From the **repository root**:

```bash
./test/run-bats.sh
```

```powershell
pwsh -File ./test/run-pester.ps1
# or Windows PowerShell 5.1+ if you install Pester for that host
```

## What is covered

- **`sync-all`** (`sync-all.sh` / `sync-all.ps1`): tool scoping, `--items` subsets, `--clean` stale output removal, help/error paths.
- **`--items`**: the same comma list is passed to **agents**, **skills**, and **rules** in each run. For a tight subset with no spurious `skip:` lines, list names that exist in each of those trees (e.g. `one,alpha,ra` in the `two-skills` fixture), or call a single `sync-*.sh` for one artifact type.
- **Per-tool scripts** (`sync-rules`, `sync-agent-guidelines` edge where relevant).
- **Fixtures** under `test/fixtures/two-skills/` (two skills, two rules, one agent) so we can test *stale* files and *partial* `--items` lists.

## Fixture layout

`test/fixtures/two-skills/` is a minimal valid source tree: `AGENTS.md`, `agents/`, `skills/alpha`, `skills/beta`, `rules/ra.md`, `rules/rb.md`.

All test paths are self-contained; scripts under `scripts/` are invoked read-only (they write only into per-test temp directories under `$TMPDIR` / `$env:TEMP`).
