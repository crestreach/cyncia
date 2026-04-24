<#
.SYNOPSIS
  Sync MCP servers from <mcp_servers_dir>/*.json to <OutputPath>/.cursor/mcp.json.
.PARAMETER InputPath
  Path to the mcp-servers directory.
.PARAMETER OutputPath
  Project root where .cursor/mcp.json is written.
.PARAMETER Items
  Optional comma-separated subset of server basenames.
.PARAMETER Clean
  Overwrite the target file. If the filtered set is empty while -Clean is set,
  the target file is removed.
.EXAMPLE
  .\sync-mcp.ps1 -InputPath "$PWD\examples\mcp-servers" -OutputPath "$PWD"
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

$dst = Join-Path $OutputDir '.cursor\mcp.json'
New-Item -ItemType Directory -Force -Path (Split-Path $dst) | Out-Null

$files = Get-McpServerFiles -InputDir $InputDir -ItemsCsv $Items
if (-not $files -or $files.Count -eq 0) {
  if ($Clean -and (Test-Path -LiteralPath $dst)) {
    Remove-Item -LiteralPath $dst -Force
    Write-Host "cursor mcp: cleaned $dst (no matching servers)"
  } else {
    Write-Host "cursor mcp: no servers selected; skip"
  }
  return
}

$obj = Assemble-McpServers -TopKey 'mcpServers' -Translator ${function:Convert-McpBodyCursor} -InputDir $InputDir -ItemsCsv $Items
Write-McpJson -Object $obj -Path $dst
Write-Host "cursor mcp -> $dst"
