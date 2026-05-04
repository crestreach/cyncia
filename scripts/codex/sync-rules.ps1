<#
.SYNOPSIS
  No-op for generic Markdown rules.
.DESCRIPTION
  Cyncia rules are Markdown instruction snippets. Codex native .rules files are
  Starlark command execution policy, so this script intentionally emits no
  .codex/rules file. Markdown rules are merged into AGENTS.override.md by
  sync-agent-guidelines.ps1 when codex-rules-mode is agents-override.
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

Resolve-AbsoluteDirectory -Path $InputPath | Out-Null
Resolve-AbsoluteDirectory -Path $OutputPath | Out-Null
Write-Host 'codex rules -> skipped (.codex/rules are Starlark command policy; Markdown rules are handled by codex sync-agent-guidelines when codex-rules-mode=agents-override)'
