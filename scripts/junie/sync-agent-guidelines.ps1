<#
.SYNOPSIS
  Write .junie/AGENTS.md from AGENTS.md plus rules/*.md (Junie has no native per-rule files).
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
    Write-Host "junie agent-guidelines: removed $dstAgents (-Clean) before copy"
  }
}
Copy-AgentsMdBetweenRoots -SourceRoot $srcRoot -OutputRoot $OutputDir
$dst = Join-Path $OutputDir '.junie/AGENTS.md'
if ($Clean -and (Test-Path -LiteralPath $dst -PathType Leaf)) {
  Remove-Item -LiteralPath $dst -Force
  Write-Host "junie agent-guidelines: removed $dst (-Clean) before write"
}
New-Item -ItemType Directory -Force -Path (Split-Path $dst) | Out-Null

$rulesDir = Join-Path $srcRoot 'rules'
$parts = New-Object System.Collections.Generic.List[string]
$parts.Add((Get-Content -LiteralPath $agentsFile -Raw))

if (Test-Path -LiteralPath $rulesDir -PathType Container) {
  $ruleFiles = Get-ChildItem -Path $rulesDir -Filter *.md -File -ErrorAction SilentlyContinue |
    Where-Object { $_.BaseName -ne 'README' } |
    Sort-Object Name
  if ($ruleFiles.Count -gt 0) {
    $parts.Add("`n`n---`n`n## Project rules (from ``rules/``)`n`n")
    foreach ($rf in $ruleFiles) {
      $base = $rf.BaseName
      $desc = Get-FrontmatterField -Path $rf.FullName -Key 'description'
      $section = New-Object System.Text.StringBuilder
      [void]$section.AppendLine("### ``$base.md``")
      [void]$section.AppendLine()
      if ($desc) {
        [void]$section.AppendLine("_${desc}_")
        [void]$section.AppendLine()
      }
      $body = Get-MarkdownBody -Path $rf.FullName
      if ($body) { [void]$section.AppendLine(($body -join "`n").TrimEnd()) }
      [void]$section.AppendLine()
      $parts.Add($section.ToString())
    }
  }
}

Set-Content -LiteralPath $dst -Value ($parts -join '') -Encoding utf8
Write-Host "junie agent-guidelines -> $dst (AGENTS.md + rules/*.md)"
