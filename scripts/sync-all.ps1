<#
.SYNOPSIS
  Run every sync-*.ps1 for the requested tools.
.DESCRIPTION
  Expects a single source tree (agents/, rules/, skills/, AGENTS.md) and one
  output project root.
.PARAMETER InputRoot
  Directory containing: agents/, rules/, skills/, and AGENTS.md
.PARAMETER OutputRoot
  Project root where tool-specific files are written. Each
  sync-agent-guidelines run copies AGENTS.md when input≠output.
.PARAMETER Tools
  Comma-separated list. Default: cursor,claude,copilot,junie
.PARAMETER Items
  Comma-separated list forwarded to agents, skills, and rules (ignored by
  sync-agent-guidelines and by no-op rules scripts for Claude and Junie)
.PARAMETER Clean
  When set, each per-tool script clears its output location(s) before writing.
  See each sync-*.ps1 for details. Default: off.
.EXAMPLE
  .\sync-all.ps1 -InputRoot "$PWD\examples" -OutputRoot "$PWD"
.EXAMPLE
  .\sync-all.ps1 -InputRoot "$PWD\examples" -OutputRoot "$PWD" -Tools cursor,claude -Items delegate-to-aside
.EXAMPLE
  .\sync-all.ps1 -InputRoot "$PWD\_internal" -OutputRoot $PWD -Clean
#>
[CmdletBinding()]
param(
  [Parameter(Mandatory)]
  [string]$InputRoot,
  [Parameter(Mandatory)]
  [string]$OutputRoot,
  [string]$Tools = 'cursor,claude,copilot,junie',
  [string]$Items = '',
  [switch]$Clean
)

$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot 'common\common.ps1')

$inputBase = Resolve-AbsoluteDirectory -Path $InputRoot
$outputBase = Resolve-AbsoluteDirectory -Path $OutputRoot
$agentsFile = Join-Path $inputBase 'AGENTS.md'
if (-not (Test-Path -LiteralPath $agentsFile -PathType Leaf)) {
  throw "Missing $agentsFile"
}

$itemArgs = @{}
if ($Items) { $itemArgs['Items'] = $Items }
$cleanArgs = @{}
if ($Clean) { $cleanArgs['Clean'] = $true }

$toolList = $Tools -split ',' | ForEach-Object { $_.Trim().ToLower() } | Where-Object { $_ }

foreach ($tool in $toolList) {
  $dir = Join-Path $PSScriptRoot $tool
  if (-not (Test-Path $dir)) { throw "Unknown tool: $tool" }
  Write-Host "== $tool =="
  & (Join-Path $dir 'sync-agents.ps1') -InputPath (Join-Path $inputBase 'agents') -OutputPath $outputBase @itemArgs @cleanArgs
  & (Join-Path $dir 'sync-skills.ps1') -InputPath (Join-Path $inputBase 'skills') -OutputPath $outputBase @itemArgs @cleanArgs
  & (Join-Path $dir 'sync-agent-guidelines.ps1') -InputPath $inputBase -OutputPath $outputBase @cleanArgs
  & (Join-Path $dir 'sync-rules.ps1') -InputPath (Join-Path $inputBase 'rules') -OutputPath $outputBase @itemArgs @cleanArgs
}
