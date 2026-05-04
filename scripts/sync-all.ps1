<#
.SYNOPSIS
  Run every sync-*.ps1 for the requested tools.
.DESCRIPTION
  Expects a single source tree containing AGENTS.md plus any of agents/,
  rules/, skills/, mcp-servers/ (all four are optional) and one output
  project root. Each subscript is skipped when its source dir is absent.
.PARAMETER InputRoot
  Directory containing AGENTS.md. May optionally contain agents/, skills/,
  rules/, and mcp-servers/. Subscripts whose source dir is missing are
  skipped with a console note.
.PARAMETER OutputRoot
  Project root where tool-specific files are written. Each
  sync-agent-guidelines run copies AGENTS.md when input≠output.
.PARAMETER Tools
  Comma-separated list. Defaults to the default-tools value in cyncia.conf,
  or all supported tools when unset.
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
  .\sync-all.ps1 -InputRoot "$PWD\.agent-config" -OutputRoot $PWD -Clean
#>
[CmdletBinding()]
param(
  [Parameter(Mandatory)]
  [string]$InputRoot,
  [Parameter(Mandatory)]
  [string]$OutputRoot,
  [string]$Tools = '',
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

if (-not $Tools) {
  $Tools = Get-CynciaConfValue -Key 'default-tools' -Default 'cursor,claude,copilot,vscode,junie,codex'
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
  $agentsSrc = Join-Path $inputBase 'agents'
  if (Test-Path -LiteralPath $agentsSrc -PathType Container) {
    & (Join-Path $dir 'sync-agents.ps1') -InputPath $agentsSrc -OutputPath $outputBase @itemArgs @cleanArgs
  } else {
    Write-Host "$tool agents: skipped (no $agentsSrc)"
  }
  $skillsSrc = Join-Path $inputBase 'skills'
  if (Test-Path -LiteralPath $skillsSrc -PathType Container) {
    & (Join-Path $dir 'sync-skills.ps1') -InputPath $skillsSrc -OutputPath $outputBase @itemArgs @cleanArgs
  } else {
    Write-Host "$tool skills: skipped (no $skillsSrc)"
  }
  $mcpSrc = Join-Path $inputBase 'mcp-servers'
  if (Test-Path -LiteralPath $mcpSrc -PathType Container) {
    & (Join-Path $dir 'sync-mcp.ps1') -InputPath $mcpSrc -OutputPath $outputBase @itemArgs @cleanArgs
  }
  & (Join-Path $dir 'sync-agent-guidelines.ps1') -InputPath $inputBase -OutputPath $outputBase @cleanArgs
  $rulesSrc = Join-Path $inputBase 'rules'
  if (Test-Path -LiteralPath $rulesSrc -PathType Container) {
    & (Join-Path $dir 'sync-rules.ps1') -InputPath $rulesSrc -OutputPath $outputBase @itemArgs @cleanArgs
  } else {
    Write-Host "$tool rules: skipped (no $rulesSrc)"
  }
}
