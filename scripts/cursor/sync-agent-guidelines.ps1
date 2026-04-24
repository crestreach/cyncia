<#
.SYNOPSIS
  Verifies the source tree contains AGENTS.md; copies AGENTS.md to the output root when input≠output.
.PARAMETER InputPath
  Source root directory (must contain AGENTS.md).
.PARAMETER OutputPath
  Project root (for messaging; no files written for Cursor).
.PARAMETER Clean
  If input and output roots differ, remove root AGENTS.md before copy.
.EXAMPLE
  .\sync-agent-guidelines.ps1 -InputPath "$PWD\examples" -OutputPath "$PWD"
#>
[CmdletBinding()]
param(
  [Parameter(Mandatory)]
  [string]$InputPath,
  [Parameter(Mandatory)]
  [string]$OutputPath,
  [switch]$Clean
)

. "$PSScriptRoot\..\common\common.ps1"
$srcRoot = Resolve-AbsoluteDirectory -Path $InputPath
$agentsFile = Join-Path $srcRoot 'AGENTS.md'
if (-not (Test-Path -LiteralPath $agentsFile -PathType Leaf)) { throw "Missing $agentsFile" }
$out = Resolve-AbsoluteDirectory -Path $OutputPath
if ($Clean -and ($srcRoot -ne $out)) {
  $dstAgents = Join-Path $out 'AGENTS.md'
  if (Test-Path -LiteralPath $dstAgents -PathType Leaf) {
    Remove-Item -LiteralPath $dstAgents -Force
    Write-Host "cursor agent-guidelines: removed $dstAgents (-Clean) before copy"
  }
}
Copy-AgentsMdBetweenRoots -SourceRoot $srcRoot -OutputRoot $out
Write-Host "cursor agent-guidelines -> Cursor uses $(Join-Path $out 'AGENTS.md') when roots differ"
