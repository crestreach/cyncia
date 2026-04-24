<#
.SYNOPSIS
  No-op: VS Code has no project-level skill files of its own.
#>
[CmdletBinding()]
param(
  [Parameter(Mandatory)][string]$InputPath,
  [Parameter(Mandatory)][string]$OutputPath,
  [string]$Items = '',
  [switch]$Clean
)
Write-Host "vscode skills: nothing to do (VS Code has no project-level skill files; see .github/skills for Copilot)"
