<#
.SYNOPSIS
  Sync rules from <rules_dir>/*.md to
  <output_root>/.github/instructions/<name>.instructions.md.
.PARAMETER InputPath
  Path to the rules directory (e.g. examples/rules).
.PARAMETER OutputPath
  Project root.
.PARAMETER Items
  Optional comma-separated subset of rule basenames.
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
  Clear-SyncDirectoryContents -Path (Join-Path $OutputDir '.github/instructions')
  Write-Host "copilot rules: cleaned $(Join-Path $OutputDir '.github/instructions')\"
}

$handler = {
  param($name, $src)
  $dst = Join-Path $OutputDir ".github/instructions/$name.instructions.md"
  $applies = Get-FrontmatterField -Path $src -Key 'applies-to'
  $always  = Get-FrontmatterField -Path $src -Key 'always-apply'
  if     ($always -eq 'true') { $applyTo = '**' }
  elseif ($applies)           { $applyTo = $applies }
  else                        { $applyTo = '**' }
  New-Item -ItemType Directory -Force -Path (Split-Path $dst) | Out-Null
  $body = Get-MarkdownBody -Path $src
  $front = @('---', "applyTo: `"$applyTo`"", '---', '')
  Set-Content -LiteralPath $dst -Value ($front + $body) -Encoding UTF8
  Write-Host "copilot rule -> $dst"
}.GetNewClosure()

Sync-Items -SrcDir $InputDir -Kind 'file' -ItemsCsv $Items -Handler $handler
