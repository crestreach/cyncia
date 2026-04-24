<#
.SYNOPSIS
  Sync skills from <skills_dir>/<name>/ to <output_root>/.claude/skills/<name>/.
.PARAMETER InputPath
  Path to the skills directory (e.g. examples/skills).
.PARAMETER OutputPath
  Project root.
.PARAMETER Items
  Optional comma-separated subset of skill folder names.
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
  Clear-SyncDirectoryContents -Path (Join-Path $OutputDir '.claude/skills')
  Write-Host "claude skills: cleaned $(Join-Path $OutputDir '.claude/skills')\"
}

$handler = {
  param($name, $src)
  $dst = Join-Path $OutputDir ".claude/skills/$name"
  if (Test-Path $dst) { Remove-Item -Recurse -Force $dst }
  New-Item -ItemType Directory -Force -Path (Split-Path $dst) | Out-Null
  Copy-Item -Recurse -Force $src $dst
  $skillMd = Join-Path $dst 'SKILL.md'
  if (Test-Path $skillMd) {
    Edit-SkillFrontmatter -Path $skillMd -Rename @{ 'applies-to' = 'paths' }
  }
  Write-Host "claude skill -> $dst/"
}.GetNewClosure()

Sync-Items -SrcDir $InputDir -Kind 'dir' -ItemsCsv $Items -Handler $handler
