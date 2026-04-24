<#
.SYNOPSIS
  No-op: VS Code has no project-level rule files of its own.
#>
[CmdletBinding()]
param(
  [Parameter(Mandatory)][string]$InputPath,
  [Parameter(Mandatory)][string]$OutputPath,
  [string]$Items = '',
  [switch]$Clean
)
Write-Host "vscode rules: nothing to do (VS Code has no project-level rule files; see .github/instructions for Copilot)"
