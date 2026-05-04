<#
.SYNOPSIS
  No-op for generic Markdown rules.
.DESCRIPTION
  Cyncia rules are Markdown instruction snippets. Codex native .rules files are
  Starlark command execution policy, so this script intentionally emits no file.
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
Write-Host 'codex rules -> skipped (Cyncia Markdown rules do not map to Codex Starlark command-policy .rules files)'
