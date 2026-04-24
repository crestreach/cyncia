<#
.SYNOPSIS
  Sync MCP servers from <mcp_servers_dir>/*.json to <OutputPath>/.vscode/mcp.json.

.DESCRIPTION
  This is VS Code's own MCP configuration file
  (https://code.visualstudio.com/docs/copilot/chat/mcp-servers). GitHub Copilot
  Chat in VS Code reads the same file, but the format belongs to VS Code, not
  to Copilot.

.PARAMETER InputPath
  Path to the mcp-servers directory.
.PARAMETER OutputPath
  Project root where .vscode/mcp.json is written.
.PARAMETER Items
  Optional comma-separated subset of server basenames.
.PARAMETER Clean
  Overwrite the target file. If the filtered set is empty while -Clean is set,
  the target file is removed.
#>
[CmdletBinding()]
param(
  [Parameter(Mandatory)][string]$InputPath,
  [Parameter(Mandatory)][string]$OutputPath,
  [string]$Items = '',
  [switch]$Clean
)

. "$PSScriptRoot\..\common\common.ps1"
. "$PSScriptRoot\..\common\mcp.ps1"
$InputDir = Resolve-AbsoluteDirectory -Path $InputPath
$OutputDir = Resolve-AbsoluteDirectory -Path $OutputPath

$dst = Join-Path $OutputDir '.vscode\mcp.json'
New-Item -ItemType Directory -Force -Path (Split-Path $dst) | Out-Null

$files = Get-McpServerFiles -InputDir $InputDir -ItemsCsv $Items
if (-not $files -or $files.Count -eq 0) {
  if ($Clean -and (Test-Path -LiteralPath $dst)) {
    Remove-Item -LiteralPath $dst -Force
    Write-Host "vscode mcp: cleaned $dst (no matching servers)"
  } else {
    Write-Host "vscode mcp: no servers selected; skip"
  }
  return
}

$servers = Assemble-McpServers -TopKey 'servers' -Translator ${function:Convert-McpBodyVscode} -InputDir $InputDir -ItemsCsv $Items
$inputs = Get-McpVscodeInputs -InputDir $InputDir -ItemsCsv $Items

$final = [ordered]@{}
$final['servers'] = $servers.servers
if ($inputs -and $inputs.Count -gt 0) {
  $final['inputs'] = @($inputs)
}

Write-McpJson -Object ([pscustomobject]$final) -Path $dst
Write-Host "vscode mcp -> $dst"
