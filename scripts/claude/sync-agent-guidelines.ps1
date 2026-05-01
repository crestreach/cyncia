<#
.SYNOPSIS
  Write CLAUDE.md from AGENTS.md plus rules/<name>.md.
.DESCRIPTION
  Two emission modes are supported, selected by claude_rules_mode in
  <cyncia-dir>/cyncia.conf (default: claude-md):

    claude-md   Append rule bodies into CLAUDE.md, grouped by source file
                (frontmatter stripped; optional description shown as italic).
    rule-files  Reference each rule from CLAUDE.md via Claude Code's @path
                memory-import syntax (one "@.claude/rules/<name>.md" line per
                rule). The per-rule files themselves are written by
                sync-rules.ps1 and load at the same priority as CLAUDE.md.
.PARAMETER InputPath
  Source root directory (must contain AGENTS.md; may contain rules/*.md).
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

$ErrorActionPreference = 'Stop'
. "$PSScriptRoot\..\common\common.ps1"
$srcRoot = Resolve-AbsoluteDirectory -Path $InputPath
$agentsFile = Join-Path $srcRoot 'AGENTS.md'
if (-not (Test-Path -LiteralPath $agentsFile -PathType Leaf)) { throw "Missing $agentsFile" }
$OutputDir = Resolve-AbsoluteDirectory -Path $OutputPath
if ($Clean -and ($srcRoot -ne $OutputDir)) {
  $dstAgents = Join-Path $OutputDir 'AGENTS.md'
  if (Test-Path -LiteralPath $dstAgents -PathType Leaf) {
    Remove-Item -LiteralPath $dstAgents -Force
    Write-Host "claude agent-guidelines: removed $dstAgents (-Clean) before copy"
  }
}
Copy-AgentsMdBetweenRoots -SourceRoot $srcRoot -OutputRoot $OutputDir
$dst = Join-Path $OutputDir 'CLAUDE.md'
if ($Clean -and (Test-Path -LiteralPath $dst -PathType Leaf)) {
  Remove-Item -LiteralPath $dst -Force
  Write-Host "claude agent-guidelines: removed $dst (-Clean) before regenerate"
}
$rulesDir = Join-Path $srcRoot 'rules'

$mode = Get-CynciaConfValue -Key 'claude_rules_mode' -Default 'claude-md'
if ($mode -ne 'claude-md' -and $mode -ne 'rule-files') {
  Write-Warning "claude agent-guidelines: unknown claude_rules_mode='$mode' (valid: claude-md, rule-files); falling back to claude-md"
  $mode = 'claude-md'
}

$parts = New-Object System.Collections.Generic.List[string]
$parts.Add((Get-Content -LiteralPath $agentsFile -Raw))

if (Test-Path -LiteralPath $rulesDir -PathType Container) {
  $ruleFiles = Get-ChildItem -Path $rulesDir -Filter *.md -File -ErrorAction SilentlyContinue |
    Where-Object { $_.BaseName -ne 'README' } |
    Sort-Object Name
  if ($ruleFiles.Count -gt 0) {
    if ($mode -eq 'rule-files') {
      $sb = New-Object System.Text.StringBuilder
      [void]$sb.AppendLine("`n`n---`n")
      [void]$sb.AppendLine("## Project rules (from ``rules/``)")
      [void]$sb.AppendLine()
      foreach ($rf in $ruleFiles) {
        [void]$sb.AppendLine("@.claude/rules/$($rf.BaseName).md")
      }
      [void]$sb.AppendLine()
      $parts.Add($sb.ToString())
    } else {
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
}

Set-Content -LiteralPath $dst -Value ($parts -join '') -Encoding utf8
if ($mode -eq 'rule-files') {
  Write-Host "claude agent-guidelines -> $dst (AGENTS.md + @-imports for rules/*.md; mode=rule-files)"
} else {
  Write-Host "claude agent-guidelines -> $dst (AGENTS.md + rules/*.md)"
}
