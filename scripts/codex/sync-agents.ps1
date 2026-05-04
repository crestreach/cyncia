<#
.SYNOPSIS
  Sync Markdown agents to Codex custom-agent TOML files.
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

$inputDir = Resolve-AbsoluteDirectory -Path $InputPath
$outRoot = Resolve-AbsoluteDirectory -Path $OutputPath
$dstDir = Join-Path $outRoot '.codex\agents'

if ($Clean) {
  Clear-SyncDirectoryContents -Path $dstDir
  Write-Host "codex agents: cleaned $dstDir\"
}

$escapeTomlString = {
  param([AllowNull()][object]$Value)
  $s = if ($null -eq $Value) { '' } else { [string]$Value }
  $s = $s.Replace('\', '\\')
  $s = $s -replace '"','\"'
  $s = $s -replace "`r",'\r'
  $s = $s -replace "`n",'\n'
  $s = $s -replace "`t",'\t'
  return '"' + $s + '"'
}.GetNewClosure()

$escapeMultilineBasicBody = {
  param([string[]]$Lines)
  return ($Lines | ForEach-Object {
    ($_.Replace('\', '\\')) -replace '"""','\"\"\"'
  })
}.GetNewClosure()

$handler = {
  param($name, $src)
  $dst = Join-Path $dstDir "$name.toml"
  New-Item -ItemType Directory -Force -Path (Split-Path $dst) | Out-Null
  $agentName = Get-FrontmatterField -Path $src -Key 'name'
  $desc = Get-FrontmatterField -Path $src -Key 'description'
  if (-not $agentName) { $agentName = $name }
  if (-not $desc) { $desc = $name }
  $body = & $escapeMultilineBasicBody -Lines (Get-MarkdownBody -Path $src)
  $out = New-Object System.Collections.Generic.List[string]
  $out.Add('name = ' + (& $escapeTomlString $agentName))
  $out.Add('description = ' + (& $escapeTomlString $desc))
  $out.Add('developer_instructions = """')
  foreach ($line in $body) { $out.Add($line) }
  $out.Add('"""')
  Set-Content -LiteralPath $dst -Value $out -Encoding UTF8
  Write-Host "codex agent -> $dst"
}.GetNewClosure()

Sync-Items -SrcDir $inputDir -Kind file -Handler $handler -ItemsCsv $Items
