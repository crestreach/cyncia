# Tests (isolated to `test/`)

## Prerequisites

- **Bash tests:** [bats-core](https://github.com/bats-core/bats-core)  
  - macOS: `brew install bats-core`
  - The MCP tests additionally require `jq` (`brew install jq`).
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

- **`sync-all`** (`sync-all.sh` / `sync-all.ps1`): tool scoping, `default-tools` config behavior, `--items` subsets, `--clean` stale output removal, help/error paths, and Codex `AGENTS.override.md` generation / opt-out.
- **`--items`**: the same comma list is passed to **agents**, **skills**, and **rules** in each run. For a tight subset with no spurious `skip:` lines, list names that exist in each of those trees (e.g. `one,alpha,ra` in the `two-skills` fixture), or call a single `sync-*.sh` for one artifact type.
- **Per-tool scripts** (`sync-rules`, `sync-agent-guidelines` edge where relevant).
- **MCP servers** (`sync-mcp.{sh,ps1}` and the `sync-all` integration): per-tool secret token translation (`${secret:NAME}` → Cursor `${env:NAME}`, Claude `${NAME}`/`${NAME:-}`, VS Code `${input:NAME}` + `inputs[]`, Codex `env_vars` / `bearer_token_env_var`), Junie stdout-only behavior, `--items` filtering, `--clean`-removes-empty-target, Codex scoped `.codex/config.toml` `mcp_servers` merging and `codex-sync-mcp` opt-out, agent-frontmatter `mcp-servers` translation across native tools, and the Copilot conflict error when `tools:` and `mcp-servers:` collide. The `copilot` and `vscode` tools are tested separately: `copilot` no longer writes any MCP file, and `vscode` writes `.vscode/mcp.json`.
- **Fixtures** under `test/fixtures/two-skills/` (two skills, two rules, one agent) and `test/fixtures/mcp/` (one stdio + one http MCP server) so we can test *stale* files, *partial* `--items` lists, and MCP translation.

## Fixture layout

- `test/fixtures/two-skills/` — minimal valid source tree: `AGENTS.md`, `agents/`, `skills/alpha`, `skills/beta`, `rules/ra.md`, `rules/rb.md`.
- `test/fixtures/mcp/` — MCP fixture: `mcp-servers/context7.json` (stdio + optional secret), `mcp-servers/httpbin.json` (http + required secret + headers).

All test paths are self-contained; scripts under `scripts/` are invoked read-only (they write only into per-test temp directories under `$TMPDIR` / `$env:TEMP`).
