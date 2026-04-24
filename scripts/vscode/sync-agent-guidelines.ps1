<#
.SYNOPSIS
  No-op: VS Code has no top-level agent guidelines file of its own.
#>
[CmdletBinding()]
param(
  [Parameter(Mandatory)][string]$InputPath,
  [Parameter(Mandatory)][string]$OutputPath,
  [string]$Items = '',
  [switch]$Clean
)
Write-Host "vscode agent-guidelines: nothing to do (VS Code has no top-level agent guidelines file; see .github/copilot-instructions.md for Copilot)"
