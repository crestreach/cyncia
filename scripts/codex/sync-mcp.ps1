<#
.SYNOPSIS
  Sync MCP servers to Codex project-scoped .codex/config.toml.
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
. (Join-Path $PSScriptRoot '..\common\mcp.ps1')

$inputDir = Resolve-AbsoluteDirectory -Path $InputPath
$outRoot = Resolve-AbsoluteDirectory -Path $OutputPath
$dst = Join-Path $outRoot '.codex\config.toml'
New-Item -ItemType Directory -Force -Path (Split-Path $dst) | Out-Null

$files = Get-McpServerFiles -InputDir $inputDir -ItemsCsv $Items
if (-not $files -or $files.Count -eq 0) {
  if ($Clean -and (Test-Path -LiteralPath $dst -PathType Leaf)) {
    Remove-Item -LiteralPath $dst -Force
    Write-Host "codex mcp: cleaned $dst (no matching servers)"
  } else {
    Write-Host 'codex mcp: no servers selected; skip'
  }
  return
}

$toml = ConvertTo-CodexMcpToml -InputDir $inputDir -ItemsCsv $Items
Set-Content -LiteralPath $dst -Value $toml -Encoding UTF8
Write-Host "codex mcp -> $dst"
