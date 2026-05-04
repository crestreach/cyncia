<#
.SYNOPSIS
  Copy AGENTS.md and optionally generate AGENTS.override.md for Codex.
.DESCRIPTION
  Codex discovers project guidance from AGENTS.override.md / AGENTS.md files,
  walking from the project root down to the current working directory.
  AGENTS.override.md is preferred over AGENTS.md in the same directory.
#>
[CmdletBinding()]
param(
  [Parameter(Mandatory=$true)][string]$InputPath,
  [Parameter(Mandatory=$true)][string]$OutputPath,
  [switch]$Clean
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '..\common\common.ps1')

$srcRoot = Resolve-AbsoluteDirectory -Path $InputPath
$outRoot = Resolve-AbsoluteDirectory -Path $OutputPath
$agentsFile = Join-Path $srcRoot 'AGENTS.md'
if (-not (Test-Path -LiteralPath $agentsFile -PathType Leaf)) { throw "Missing $agentsFile" }

$dst = Join-Path $outRoot 'AGENTS.md'
if ($Clean -and $srcRoot -ne $outRoot -and (Test-Path -LiteralPath $dst -PathType Leaf)) {
  Remove-Item -LiteralPath $dst -Force
  Write-Host "codex agent-guidelines: removed $dst (-Clean) before copy"
}

Copy-AgentsMdBetweenRoots -SourceRoot $srcRoot -OutputRoot $outRoot
Write-Host "codex agent-guidelines -> $dst"

function Test-CodexRulesOverrideEnabled {
  $value = (Get-CynciaConfValue -Key 'codex_rules_to_agents_override' -Default 'true').ToLowerInvariant()
  switch ($value) {
    { $_ -in @('true','yes','y','1','on') } { return $true }
    { $_ -in @('false','no','n','0','off') } { return $false }
    default {
      Write-Warning "codex agent-guidelines: unknown codex_rules_to_agents_override='$value' (valid: true, false); falling back to true"
      return $true
    }
  }
}

$overrideDst = Join-Path $outRoot 'AGENTS.override.md'
if (-not (Test-CodexRulesOverrideEnabled)) {
  if ($Clean -and (Test-Path -LiteralPath $overrideDst -PathType Leaf)) {
    Remove-Item -LiteralPath $overrideDst -Force
    Write-Host "codex agent-guidelines: removed $overrideDst (-Clean; codex_rules_to_agents_override=false)"
  } else {
    Write-Host 'codex agent-guidelines: skipped AGENTS.override.md (codex_rules_to_agents_override=false)'
  }
  return
}

if ($Clean -and (Test-Path -LiteralPath $overrideDst -PathType Leaf)) {
  Remove-Item -LiteralPath $overrideDst -Force
  Write-Host "codex agent-guidelines: removed $overrideDst (-Clean) before regenerate"
}

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

Set-Content -LiteralPath $overrideDst -Value ($parts -join '') -Encoding UTF8
Write-Host "codex agent-guidelines -> $overrideDst (AGENTS.md + rules/*.md)"
