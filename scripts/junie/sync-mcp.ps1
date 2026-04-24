<#
.SYNOPSIS
  Print a paste-ready "mcpServers" JSON snippet for JetBrains AI Assistant / Junie.

.DESCRIPTION
  Junie has no documented project-local MCP config file, so this script writes
  NO files under .junie/. Instead it prints a JSON document to stdout that the
  user can paste into:
    Settings | Tools | AI Assistant | Model Context Protocol (MCP) | Add server

.PARAMETER InputPath
  Path to the mcp-servers directory.
.PARAMETER OutputPath
  Ignored (kept for flag parity with the other tools).
.PARAMETER Items
  Optional comma-separated subset of server basenames.
.PARAMETER Clean
  Ignored (no file is written).
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
# Validate OutputPath for flag parity even though we don't write to it.
$null = Resolve-AbsoluteDirectory -Path $OutputPath

$files = Get-McpServerFiles -InputDir $InputDir -ItemsCsv $Items
if (-not $files -or $files.Count -eq 0) {
  Write-Host "junie mcp: no servers selected; nothing to print"
  return
}

$obj = Assemble-McpServers -TopKey 'mcpServers' -Translator ${function:Convert-McpBodyPassthrough} -InputDir $InputDir -ItemsCsv $Items
Write-Host "junie mcp: paste the following into Settings | Tools | AI Assistant | Model Context Protocol (MCP):"
$obj | ConvertTo-Json -Depth 50
