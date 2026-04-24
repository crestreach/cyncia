<#
.SYNOPSIS
  No-op: MCP config for Copilot Chat in VS Code lives in .vscode/mcp.json,
  a VS Code format. It is now written by scripts/vscode/sync-mcp.ps1.
.DESCRIPTION
  Kept so sync-all can iterate the copilot tool uniformly and so existing
  callers don't break.
#>
[CmdletBinding()]
param(
  [Parameter(Mandatory)][string]$InputPath,
  [Parameter(Mandatory)][string]$OutputPath,
  [string]$Items = '',
  [switch]$Clean
)
Write-Host "copilot mcp: nothing to do (MCP config for Copilot Chat in VS Code is written by scripts/vscode/sync-mcp.ps1 -> .vscode/mcp.json)"
