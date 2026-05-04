<#
.SYNOPSIS
  Sync skills to Codex repository-scoped .agents/skills/.
#>
[CmdletBinding()]
param(
  [Parameter(Mandatory=$true)][string]$InputPath,
  [Parameter(Mandatory=$true)][string]$OutputPath,
  [string]$Items = '',
  [switch]$Clean
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '..\common\common.ps1')

$inputDir = Resolve-AbsoluteDirectory -Path $InputPath
$outRoot = Resolve-AbsoluteDirectory -Path $OutputPath
$skillsOut = Join-Path $outRoot '.agents\skills'

if ($Clean) {
  Clear-SyncDirectoryContents -Path $skillsOut
  Write-Host "codex skills: cleaned $skillsOut\"
}

$handler = {
  param($name, $src)
  $dst = Join-Path $skillsOut $name
  if (Test-Path -LiteralPath $dst) { Remove-Item -LiteralPath $dst -Recurse -Force }
  New-Item -ItemType Directory -Force -Path (Split-Path $dst) | Out-Null
  Copy-Item -LiteralPath $src -Destination $dst -Recurse -Force
  Edit-SkillFrontmatter -Path (Join-Path $dst 'SKILL.md') -Drop @('applies-to')
  Write-Host "codex skill -> $dst\"
}.GetNewClosure()

Sync-Items -SrcDir $inputDir -Kind dir -Handler $handler -ItemsCsv $Items
