<#
.SYNOPSIS
  Copy <source_root>/AGENTS.md to <output_root>/.github/copilot-instructions.md.
.PARAMETER InputPath
  Source root directory (must contain AGENTS.md).
.PARAMETER OutputPath
  Project root.
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
$OutputDir = Resolve-AbsoluteDirectory -Path $OutputPath
if ($Clean -and ($srcRoot -ne $OutputDir)) {
  $dstAgents = Join-Path $OutputDir 'AGENTS.md'
  if (Test-Path -LiteralPath $dstAgents -PathType Leaf) {
    Remove-Item -LiteralPath $dstAgents -Force
    Write-Host "copilot agent-guidelines: removed $dstAgents (-Clean) before copy"
  }
}
Copy-AgentsMdBetweenRoots -SourceRoot $srcRoot -OutputRoot $OutputDir
$dst = Join-Path $OutputDir '.github/copilot-instructions.md'
if ($Clean -and (Test-Path -LiteralPath $dst -PathType Leaf)) {
  Remove-Item -LiteralPath $dst -Force
  Write-Host "copilot agent-guidelines: removed $dst (-Clean) before copy"
}
New-Item -ItemType Directory -Force -Path (Split-Path $dst) | Out-Null
Copy-Item -LiteralPath $agentsFile -Destination $dst -Force
Write-Host "copilot agent-guidelines -> $dst"
