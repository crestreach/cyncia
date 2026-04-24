<#
.SYNOPSIS
  Sync agents from <agents_dir>/*.md to <output_root>/.cursor/agents/<name>.md.
.PARAMETER InputPath
  Path to the agents directory (e.g. examples/agents).
.PARAMETER OutputPath
  Project root where .cursor/ is written.
.PARAMETER Items
  Optional comma-separated subset of agent names.
.PARAMETER Clean
  Remove all files under .cursor/agents/ before syncing.
.EXAMPLE
  .\sync-agents.ps1 -InputPath "$PWD\examples\agents" -OutputPath "$PWD"
.EXAMPLE
  .\sync-agents.ps1 -InputPath "$PWD\examples\agents" -OutputPath "$PWD" -Items aside
.EXAMPLE
  .\sync-agents.ps1 -InputPath "$PWD\examples\agents" -OutputPath "$PWD" -Clean
#>
[CmdletBinding()]
param(
  [Parameter(Mandatory)]
  [string]$InputPath,
  [Parameter(Mandatory)]
  [string]$OutputPath,
  [string]$Items = '',
  [switch]$Clean
)

. "$PSScriptRoot\..\common\common.ps1"
$OutputDir = Resolve-AbsoluteDirectory -Path $OutputPath
$InputDir  = Resolve-AbsoluteDirectory -Path $InputPath

if ($Clean) {
  Clear-SyncDirectoryContents -Path (Join-Path $OutputDir '.cursor/agents')
  Write-Host "cursor agents: cleaned $(Join-Path $OutputDir '.cursor/agents')\"
}

$handler = {
  param($name, $src)
  $dst = Join-Path $OutputDir ".cursor/agents/$name.md"
  Copy-WithFrontmatterEdit -Source $src -Destination $dst -Drop @('mcp-servers')
  Write-Host "cursor agent -> $dst"
}.GetNewClosure()

Sync-Items -SrcDir $InputDir -Kind 'file' -ItemsCsv $Items -Handler $handler
