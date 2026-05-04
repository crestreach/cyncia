<#
.SYNOPSIS
  Claude Code rule emission for rules/<name>.md, controlled by
  claude-rules-mode in <cyncia-dir>/cyncia.conf (default: claude-md).
.DESCRIPTION
  claude-md   No-op. Rule bodies are merged into CLAUDE.md by
              sync-agent-guidelines.ps1.
  rule-files  Write each rule to <OutputPath>\.claude\rules\<name>.md (no
              frontmatter; optional description shown as italic line). Claude
              Code loads these as memory imports referenced from CLAUDE.md
              with the same priority as CLAUDE.md.
.PARAMETER InputPath
  Source rules/ directory.
.PARAMETER OutputPath
  Project root.
.PARAMETER Clean
  In rule-files mode: clears <OutputPath>\.claude\rules\ before writing.
  Ignored in claude-md mode.
.EXAMPLE
  .\sync-rules.ps1 -InputPath "$PWD\examples\rules" -OutputPath "$PWD"
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
$inputDir  = Resolve-AbsoluteDirectory -Path $InputPath
$outputDir = Resolve-AbsoluteDirectory -Path $OutputPath

$mode = Get-CynciaConfValue -Key 'claude-rules-mode' -Default 'claude-md'
if ($mode -ne 'claude-md' -and $mode -ne 'rule-files') {
  Write-Warning "claude rules: unknown claude-rules-mode='$mode' (valid: claude-md, rule-files); falling back to claude-md"
  $mode = 'claude-md'
}

if ($mode -ne 'rule-files') {
  Write-Host "claude rules -> skipped (mode=claude-md; per-rule content is merged into CLAUDE.md by sync-agent-guidelines)"
  return
}

$rulesOut = Join-Path $outputDir '.claude\rules'
if ($Clean) {
  Clear-SyncDirectoryContents -Path $rulesOut
  Write-Host "claude rules: cleaned $rulesOut\"
}

$handler = {
  param($name, $src)
  $dst = Join-Path $rulesOut "$name.md"
  $dstDir = Split-Path $dst
  if (-not (Test-Path -LiteralPath $dstDir -PathType Container)) {
    New-Item -ItemType Directory -Force -Path $dstDir | Out-Null
  }
  $desc = Get-FrontmatterField -Path $src -Key 'description'
  $body = Get-MarkdownBody -Path $src
  $sb = New-Object System.Text.StringBuilder
  [void]$sb.AppendLine("# ``$name.md``")
  [void]$sb.AppendLine()
  if ($desc) {
    [void]$sb.AppendLine("_${desc}_")
    [void]$sb.AppendLine()
  }
  if ($body) { [void]$sb.AppendLine(($body -join "`n").TrimEnd()) }
  Set-Content -LiteralPath $dst -Value $sb.ToString() -Encoding utf8
  Write-Host "claude rule -> $dst"
}.GetNewClosure()

Sync-Items -SrcDir $inputDir -Kind 'file' -Handler $handler -ItemsCsv $Items
