<#
.SYNOPSIS
  No-op: workspace custom agents are handled by the Copilot sync.
.DESCRIPTION
  Workspace custom agents live under .github/agents/*.agent.md and are handled
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
Write-Host "vscode agents: nothing to do (workspace agents are written by copilot to .github/agents/*.agent.md)"
