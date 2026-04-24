<#
.SYNOPSIS
  Sync skills from <skills_dir>/<name>/ to <output_root>/.cursor/skills/<name>/.
.PARAMETER InputPath
  Path to the skills directory (e.g. examples/skills).
.PARAMETER OutputPath
  Project root.
.PARAMETER Items
  Optional comma-separated subset of skill folder names.
.PARAMETER Clean
  Remove all subdirectories under .cursor/skills/ before syncing.
.EXAMPLE
  .\sync-skills.ps1 -InputPath "$PWD\examples\skills" -OutputPath "$PWD"
.EXAMPLE
  .\sync-skills.ps1 -InputPath "$PWD\examples\skills" -OutputPath "$PWD" -Items delegate-to-aside
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
  Clear-SyncDirectoryContents -Path (Join-Path $OutputDir '.cursor/skills')
  Write-Host "cursor skills: cleaned $(Join-Path $OutputDir '.cursor/skills')\"
}

$handler = {
  param($name, $src)
  $dst = Join-Path $OutputDir ".cursor/skills/$name"
  if (Test-Path $dst) { Remove-Item -Recurse -Force $dst }
  New-Item -ItemType Directory -Force -Path (Split-Path $dst) | Out-Null
  Copy-Item -Recurse -Force $src $dst
  Edit-SkillFrontmatter -Path (Join-Path $dst 'SKILL.md') -Drop @('applies-to')
  Write-Host "cursor skill -> $dst/"
}.GetNewClosure()

Sync-Items -SrcDir $InputDir -Kind 'dir' -ItemsCsv $Items -Handler $handler
