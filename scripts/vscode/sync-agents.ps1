<#
.SYNOPSIS
  No-op: VS Code has no project-level agent files of its own.
.DESCRIPTION
  Agent definitions for Copilot Chat live under .github/agents and are handled
  by scripts/copilot/sync-agents.ps1. This script exists only so sync-all can
  iterate the vscode tool uniformly.
#>
[CmdletBinding()]
param(
  [Parameter(Mandatory)][string]$InputPath,
  [Parameter(Mandatory)][string]$OutputPath,
  [string]$Items = '',
  [switch]$Clean
)
Write-Host "vscode agents: nothing to do (VS Code has no project-level agent files; see .github/agents for Copilot)"
