<#
.SYNOPSIS
  Sync rules from <rules_dir>/*.md to <output_root>/.cursor/rules/<name>.mdc.
.PARAMETER InputPath
  Path to the rules directory (e.g. examples/rules).
.PARAMETER OutputPath
  Project root.
.PARAMETER Items
  Optional comma-separated subset of rule file basenames.
.PARAMETER Clean
  Remove all files under .cursor/rules/ before syncing.
.EXAMPLE
  .\sync-rules.ps1 -InputPath "$PWD\examples\rules" -OutputPath "$PWD"
.EXAMPLE
  .\sync-rules.ps1 -InputPath "$PWD\examples\rules" -OutputPath "$PWD" -Items java-conventions,commit-style
#>
[CmdletBinding()]
param(
  [Parameter(Mandatory)]
  [string]$InputPath,
  [Parameter(Mandatory)]
  [string]$OutputPath,
  [string]$Items = '',
  [switch]$Clean
)

. "$PSScriptRoot\..\common\common.ps1"
$OutputDir = Resolve-AbsoluteDirectory -Path $OutputPath
$InputDir  = Resolve-AbsoluteDirectory -Path $InputPath

if ($Clean) {
  Clear-SyncDirectoryContents -Path (Join-Path $OutputDir '.cursor/rules')
  Write-Host "cursor rules: cleaned $(Join-Path $OutputDir '.cursor/rules')\"
}

$handler = {
  param($name, $src)
  $dst = Join-Path $OutputDir ".cursor/rules/$name.mdc"
  $desc   = Get-FrontmatterField -Path $src -Key 'description'
  $globs  = Get-FrontmatterField -Path $src -Key 'applies-to'
  $always = Get-FrontmatterField -Path $src -Key 'always-apply'
  if (-not $desc)  { $desc   = $name }
  if ($always -ne 'true') { $always = 'false' }
  New-Item -ItemType Directory -Force -Path (Split-Path $dst) | Out-Null
  $body = Get-MarkdownBody -Path $src
  $front = @('---', "description: $desc")
  if ($globs) { $front += "globs: $globs" }
  $front += "alwaysApply: $always"
  $front += @('---','')
  Set-Content -LiteralPath $dst -Value ($front + $body) -Encoding UTF8
  Write-Host "cursor rule -> $dst"
}.GetNewClosure()

Sync-Items -SrcDir $InputDir -Kind 'file' -ItemsCsv $Items -Handler $handler
