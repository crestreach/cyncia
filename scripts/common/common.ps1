<#
.SYNOPSIS
  Shared helpers for per-tool sync scripts (PowerShell).

.DESCRIPTION
  Dot-source from a per-tool script:

    . "$PSScriptRoot\..\common\common.ps1"
    $RepoRoot = Initialize-RepoRoot -CallerScriptPath $PSCommandPath

  Then use Sync-Items with a scriptblock handler (use .GetNewClosure() so the
  handler can see $RepoRoot from the caller's scope).
#>

$ErrorActionPreference = 'Stop'

function global:Initialize-RepoRoot {
  param([Parameter(Mandatory=$true)][string]$CallerScriptPath)
  $toolDir    = Split-Path -Parent $CallerScriptPath
  $scriptsDir = Split-Path -Parent $toolDir
  return (Split-Path -Parent $scriptsDir)
}

function global:Resolve-AbsoluteDirectory {
  param([Parameter(Mandatory=$true)][string]$Path)
  if (-not (Test-Path -LiteralPath $Path -PathType Container)) {
    throw "Not a directory: $Path"
  }
  return (Resolve-Path -LiteralPath $Path).Path
}

function global:Resolve-AbsoluteFile {
  param([Parameter(Mandatory=$true)][string]$Path)
  if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
    throw "Not a file: $Path"
  }
  return (Resolve-Path -LiteralPath $Path).Path
}

function global:Clear-SyncDirectoryContents {
  <#
  .SYNOPSIS
    Remove all children of an existing directory (the directory node remains).
  #>
  param(
    [Parameter(Mandatory = $true)]
    [string]$Path
  )
  if (-not (Test-Path -LiteralPath $Path -PathType Container)) { return }
  Get-ChildItem -LiteralPath $Path -Force -ErrorAction Stop |
    ForEach-Object { Remove-Item -LiteralPath $_.FullName -Recurse -Force }
}

function global:Copy-AgentsMdBetweenRoots {
  <#
  Copies SourceRoot/AGENTS.md to OutputRoot/AGENTS.md when the two roots
  differ. No-op when they are the same path.
  #>
  param(
    [Parameter(Mandatory=$true)][string]$SourceRoot,
    [Parameter(Mandatory=$true)][string]$OutputRoot
  )
  if ($SourceRoot -eq $OutputRoot) {
    Write-Host "agent-guidelines: skip AGENTS.md copy (input and output root are the same: $SourceRoot)"
    return
  }
  $src = Join-Path $SourceRoot 'AGENTS.md'
  $dst = Join-Path $OutputRoot 'AGENTS.md'
  if (-not (Test-Path -LiteralPath $src -PathType Leaf)) { throw "Missing $src" }
  Copy-Item -LiteralPath $src -Destination $dst -Force
  Write-Host "agent-guidelines: copied $src -> $dst"
}

function global:ConvertTo-ItemList {
  param([string]$Raw)
  if ([string]::IsNullOrWhiteSpace($Raw)) { return @() }
  return @($Raw -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ })
}

function global:Get-MarkdownBody {
  param([Parameter(Mandatory=$true)][string]$Path)
  $lines = Get-Content -LiteralPath $Path
  if ($lines.Count -lt 1 -or $lines[0].Trim() -ne '---') { return $lines }
  $end = -1
  for ($i = 1; $i -lt $lines.Count; $i++) {
    if ($lines[$i].Trim() -eq '---') { $end = $i; break }
  }
  if ($end -lt 0) { return $lines }
  if ($end + 1 -ge $lines.Count) { return @() }
  return $lines[($end + 1)..($lines.Count - 1)]
}

function global:Get-FrontmatterField {
  param(
    [Parameter(Mandatory=$true)][string]$Path,
    [Parameter(Mandatory=$true)][string]$Key
  )
  $lines = Get-Content -LiteralPath $Path
  if ($lines.Count -lt 1 -or $lines[0].Trim() -ne '---') { return '' }
  $end = -1
  for ($i = 1; $i -lt $lines.Count; $i++) {
    if ($lines[$i].Trim() -eq '---') { $end = $i; break }
  }
  if ($end -lt 0) { return '' }
  $pat = '^\s*' + [regex]::Escape($Key) + '\s*:\s*(.*)$'
  for ($i = 1; $i -lt $end; $i++) {
    if ($lines[$i] -match $pat) {
      $val = $Matches[1].Trim()
      $val = $val -replace '^"|"$',''
      $val = $val -replace "^'|'$",''
      return $val
    }
  }
  return ''
}

function global:Edit-SkillFrontmatter {
  <#
    In-place rewrite of a SKILL.md's frontmatter.
    -Drop:   string[] of keys to drop
    -Rename: hashtable mapping oldKey -> newKey
  #>
  param(
    [Parameter(Mandatory=$true)][string]$Path,
    [string[]]$Drop = @(),
    [hashtable]$Rename = @{}
  )
  if (-not (Test-Path $Path)) { return }
  $lines = Get-Content -LiteralPath $Path
  if ($lines.Count -lt 1 -or $lines[0].Trim() -ne '---') { return }

  $out = New-Object System.Collections.Generic.List[string]
  $out.Add($lines[0])

  $end = -1
  for ($i = 1; $i -lt $lines.Count; $i++) {
    if ($lines[$i].Trim() -eq '---') { $end = $i; break }
    $line = $lines[$i]
    $p = $line.IndexOf(':')
    if ($p -gt 0) {
      $key = $line.Substring(0, $p).Trim()
      if ($Drop -contains $key) { continue }
      if ($Rename.ContainsKey($key)) {
        $line = $Rename[$key] + $line.Substring($p)
      }
    }
    $out.Add($line)
  }
  if ($end -ge 0) {
    for ($i = $end; $i -lt $lines.Count; $i++) { $out.Add($lines[$i]) }
  }

  Set-Content -LiteralPath $Path -Value $out -Encoding UTF8
}

function global:Sync-Items {
  <#
    Iterate sources and invoke a handler scriptblock per item.
      -Kind 'file': picks *.md (ignoring README.md) under $SrcDir
      -Kind 'dir':  picks every immediate subdirectory of $SrcDir
    Handler receives positional args: $name, $srcPath.
    Use .GetNewClosure() on the scriptblock to capture outer variables.
  #>
  param(
    [Parameter(Mandatory=$true)][string]$SrcDir,
    [Parameter(Mandatory=$true)][ValidateSet('file','dir')][string]$Kind,
    [Parameter(Mandatory=$true)][scriptblock]$Handler,
    [string]$ItemsCsv = ''
  )
  if (-not (Test-Path $SrcDir)) { throw "No source dir: $SrcDir" }

  if ($Kind -eq 'dir') {
    $all = Get-ChildItem -Path $SrcDir -Directory | ForEach-Object { $_.Name }
  } else {
    $all = Get-ChildItem -Path $SrcDir -Filter *.md -File |
           Where-Object { $_.BaseName -ne 'README' } |
           ForEach-Object { $_.BaseName }
  }

  $selected = ConvertTo-ItemList $ItemsCsv
  if (-not $selected -or $selected.Count -eq 0) { $selected = @($all) }
  if (-not $selected -or $selected.Count -eq 0) {
    Write-Host "No items found in $SrcDir"
    return
  }

  foreach ($name in $selected) {
    if ($Kind -eq 'dir') {
      $src = Join-Path $SrcDir $name
      if (-not (Test-Path $src -PathType Container)) {
        Write-Warning "skip: $name (not a directory at $src)"; continue
      }
    } else {
      $src = Join-Path $SrcDir "$name.md"
      if (-not (Test-Path $src -PathType Leaf)) {
        Write-Warning "skip: $name (not a file at $src)"; continue
      }
    }
    & $Handler $name $src
  }
}

function global:Copy-WithFrontmatterEdit {
  <#
    Copy a Markdown file with YAML frontmatter from $Source to $Destination,
    optionally dropping keys, renaming keys, or inserting a literal line
    before the closing '---'.
  #>
  param(
    [Parameter(Mandatory=$true)][string]$Source,
    [Parameter(Mandatory=$true)][string]$Destination,
    [string[]]$Drop = @(),
    [hashtable]$Rename = @{},
    [string[]]$Insert = @()
  )
  New-Item -ItemType Directory -Force -Path (Split-Path $Destination) | Out-Null
  Copy-Item -LiteralPath $Source -Destination $Destination -Force
  if (($Drop.Count -gt 0) -or ($Rename.Count -gt 0)) {
    Edit-SkillFrontmatter -Path $Destination -Drop $Drop -Rename $Rename
  }
  if ($Insert.Count -gt 0) {
    $lines = Get-Content -LiteralPath $Destination
    if ($lines.Count -ge 1 -and $lines[0].Trim() -eq '---') {
      $end = -1
      for ($i = 1; $i -lt $lines.Count; $i++) {
        if ($lines[$i].Trim() -eq '---') { $end = $i; break }
      }
      if ($end -gt 0) {
        $out = New-Object System.Collections.Generic.List[string]
        for ($i = 0; $i -lt $end; $i++) { $out.Add($lines[$i]) }
        foreach ($l in $Insert) { $out.Add($l) }
        for ($i = $end; $i -lt $lines.Count; $i++) { $out.Add($lines[$i]) }
        Set-Content -LiteralPath $Destination -Value $out -Encoding UTF8
      }
    }
  }
}

function global:ConvertTo-YamlFlowList {
  <#
    "a, b, c" -> "[a, b, c]". Used for Claude mcpServers.
  #>
  param([string]$Csv)
  if ([string]::IsNullOrWhiteSpace($Csv)) { return '[]' }
  $items = $Csv -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ }
  return '[' + ($items -join ', ') + ']'
}

function global:ConvertTo-CopilotToolsList {
  <#
    "a, b" -> '["a/*", "b/*"]'. Used for Copilot agent tools: field.
  #>
  param([string]$Csv)
  if ([string]::IsNullOrWhiteSpace($Csv)) { return '[]' }
  $items = $Csv -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ } |
           ForEach-Object { '"' + $_ + '/*"' }
  return '[' + ($items -join ', ') + ']'
}
