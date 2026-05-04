<#
.SYNOPSIS
  Sync MCP servers into Codex project-scoped .codex/config.toml.
.DESCRIPTION
  Updates only mcp_servers tables, preserving unrelated Codex config.
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

function Test-CodexMcpEnabled {
  $value = (Get-CynciaConfValue -Key 'codex-sync-mcp' -Default 'true').ToLowerInvariant()
  switch ($value) {
    { $_ -in @('true','yes','y','1','on') } { return $true }
    { $_ -in @('false','no','n','0','off') } { return $false }
    default {
      Write-Warning "codex mcp: unknown codex-sync-mcp='$value' (valid: true, false); falling back to true"
      return $true
    }
  }
}

function Get-CodexMcpSectionName {
  param([string]$Line)
  if ($Line -eq '[mcp_servers]') { return '__root__' }
  if ($Line -match '^\[mcp_servers\.(?:"((?:[^"\\]|\\.)*)"|([A-Za-z0-9_-]+))(?:\.|\])') {
    if ($Matches[1]) { return $Matches[1] }
    return $Matches[2]
  }
  return ''
}

function Remove-CodexMcpSections {
  param(
    [Parameter(Mandatory=$true)][string]$Path,
    [Parameter(Mandatory=$true)][string[]]$Names,
    [switch]$All
  )
  if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { return }
  $wanted = @{}
  foreach ($name in $Names) { $wanted[$name] = $true }
  $out = New-Object System.Collections.Generic.List[string]
  $skip = $false
  foreach ($line in (Get-Content -LiteralPath $Path)) {
    if ($line -match '^\[') {
      $sectionName = Get-CodexMcpSectionName -Line $line
      if ($sectionName) {
        $skip = $All -or ($sectionName -ne '__root__' -and $wanted.ContainsKey($sectionName))
      } else {
        $skip = $false
      }
    }
    if (-not $skip) { $out.Add($line) }
  }
  $nonWhitespace = ($out -join '').Trim()
  if (-not $nonWhitespace) {
    Remove-Item -LiteralPath $Path -Force
  } else {
    Set-Content -LiteralPath $Path -Value $out -Encoding UTF8
  }
}

function Add-CodexMcpToml {
  param(
    [Parameter(Mandatory=$true)][string]$Path,
    [Parameter(Mandatory=$true)][string]$Toml
  )
  $lines = New-Object System.Collections.Generic.List[string]
  if (Test-Path -LiteralPath $Path -PathType Leaf) {
    $existing = Get-Content -LiteralPath $Path
    foreach ($line in $existing) { $lines.Add($line) }
    if (($existing -join '').Trim()) { $lines.Add('') }
  }
  foreach ($line in ($Toml.TrimEnd() -split "`r?`n")) { $lines.Add($line) }
  Set-Content -LiteralPath $Path -Value $lines -Encoding UTF8
}

if (-not (Test-CodexMcpEnabled)) {
  Write-Host 'codex mcp: skipped (codex-sync-mcp=false)'
  return
}

$files = Get-McpServerFiles -InputDir $inputDir -ItemsCsv $Items
if (-not $files -or $files.Count -eq 0) {
  if ($Clean) {
    Remove-CodexMcpSections -Path $dst -Names @() -All
    Write-Host "codex mcp: cleaned mcp_servers in $dst (no matching servers)"
  } else {
    Write-Host 'codex mcp: no servers selected; skip'
  }
  return
}

$toml = ConvertTo-CodexMcpToml -InputDir $inputDir -ItemsCsv $Items
Remove-CodexMcpSections -Path $dst -Names @($files | ForEach-Object { $_.Name }) -All:$Clean
Add-CodexMcpToml -Path $dst -Toml $toml
Write-Host "codex mcp -> $dst"
