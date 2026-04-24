<#
.SYNOPSIS
  No-op: Junie has no native per-rule file format. -i and -o are accepted for a
  uniform CLI (e.g. sync-all).
.PARAMETER InputPath
  Any existing directory; not used.
.PARAMETER OutputPath
  Project root; not used.
.EXAMPLE
  .\sync-rules.ps1 -InputPath "$PWD\examples\rules" -OutputPath "$PWD"
.EXAMPLE
  .\sync-rules.ps1 -InputPath "$PWD\examples\rules" -OutputPath "$PWD"
#>
[CmdletBinding()]
param(
  [Parameter(Mandatory)]
  [string]$InputPath,
  [Parameter(Mandatory)]
  [string]$OutputPath,
  # Items ignored; accepted for sync-all.ps1
  [string]$Items = '',
  [switch]$Clean
)

. "$PSScriptRoot\..\common\common.ps1"
[void](Resolve-AbsoluteDirectory -Path $InputPath)
[void](Resolve-AbsoluteDirectory -Path $OutputPath)
Write-Host "junie rules -> skipped (per-rule content is merged into .junie/AGENTS.md by sync-agent-guidelines)"
