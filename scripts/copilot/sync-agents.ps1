<#
.SYNOPSIS
  Sync agents from <agents_dir>/*.md to <output_root>/.github/agents/<name>.md.
.PARAMETER InputPath
  Path to the agents directory (e.g. examples/agents).
.PARAMETER OutputPath
  Project root.
.PARAMETER Items
  Optional comma-separated subset of agent names.
.EXAMPLE
  .\sync-agents.ps1 -InputPath "$PWD\examples\agents" -OutputPath "$PWD"
.EXAMPLE
  .\sync-agents.ps1 -InputPath "$PWD\examples\agents" -OutputPath "$PWD" -Items aside
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
  Clear-SyncDirectoryContents -Path (Join-Path $OutputDir '.github/agents')
  Write-Host "copilot agents: cleaned $(Join-Path $OutputDir '.github/agents')\"
}

$handler = {
  param($name, $src)
  $dst = Join-Path $OutputDir ".github/agents/$name.md"
  New-Item -ItemType Directory -Force -Path (Split-Path $dst) | Out-Null
  Copy-Item $src $dst -Force
  Write-Host "copilot agent -> $dst"
}.GetNewClosure()

Sync-Items -SrcDir $InputDir -Kind 'file' -ItemsCsv $Items -Handler $handler
