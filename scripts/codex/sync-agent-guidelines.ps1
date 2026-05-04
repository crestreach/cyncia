<#
.SYNOPSIS
  Copy AGENTS.md to the output root for Codex.
.DESCRIPTION
  Codex discovers project guidance from AGENTS.md files, walking from the
  project root down to the current working directory. This script emits only
  the root project AGENTS.md.
#>
[CmdletBinding()]
param(
  [Parameter(Mandatory=$true)][string]$InputPath,
  [Parameter(Mandatory=$true)][string]$OutputPath,
  [switch]$Clean
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '..\common\common.ps1')

$srcRoot = Resolve-AbsoluteDirectory -Path $InputPath
$outRoot = Resolve-AbsoluteDirectory -Path $OutputPath
$agentsFile = Join-Path $srcRoot 'AGENTS.md'
if (-not (Test-Path -LiteralPath $agentsFile -PathType Leaf)) { throw "Missing $agentsFile" }

$dst = Join-Path $outRoot 'AGENTS.md'
if ($Clean -and $srcRoot -ne $outRoot -and (Test-Path -LiteralPath $dst -PathType Leaf)) {
  Remove-Item -LiteralPath $dst -Force
  Write-Host "codex agent-guidelines: removed $dst (-Clean) before copy"
}

Copy-AgentsMdBetweenRoots -SourceRoot $srcRoot -OutputRoot $outRoot
Write-Host "codex agent-guidelines -> $dst"
