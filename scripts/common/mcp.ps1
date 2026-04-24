<#
.SYNOPSIS
  Shared helpers for sync-mcp.ps1 scripts (Cursor / Claude / VS Code / Junie).

.DESCRIPTION
  Dot-source AFTER common.ps1:
    . "$PSScriptRoot\..\common\common.ps1"
    . "$PSScriptRoot\..\common\mcp.ps1"
#>

function global:Get-McpServerFiles {
  <#
    Return an array of [pscustomobject]@{Name=...; Path=...} for *.json files
    under $InputDir, filtered by $ItemsCsv if provided.
  #>
  param(
    [Parameter(Mandatory=$true)][string]$InputDir,
    [string]$ItemsCsv = ''
  )
  if (-not (Test-Path $InputDir -PathType Container)) {
    throw "No source dir: $InputDir"
  }
  $all = Get-ChildItem -Path $InputDir -Filter *.json -File |
         ForEach-Object { [pscustomobject]@{ Name = $_.BaseName; Path = $_.FullName } }

  $selected = ConvertTo-ItemList $ItemsCsv
  if (-not $selected -or $selected.Count -eq 0) { return @($all) }

  $byName = @{}
  foreach ($a in $all) { $byName[$a.Name] = $a }

  $result = @()
  foreach ($n in $selected) {
    if ($byName.ContainsKey($n)) {
      $result += $byName[$n]
    } else {
      Write-Warning "skip: $n (not a file at $InputDir\$n.json)"
    }
  }
  return @($result)
}

# -----------------------------------------------------------------------------
# Token translation
#
# Rewrites ${secret:NAME} and ${secret:NAME?optional} string occurrences found
# anywhere inside the parsed JSON object tree.
# -----------------------------------------------------------------------------

function global:_McpRewriteStrings {
  param(
    [object]$Node,
    [scriptblock]$Rewrite
  )
  if ($null -eq $Node) { return $null }
  if ($Node -is [string]) {
    return (& $Rewrite $Node)
  }
  if ($Node -is [System.Collections.IList] -and -not ($Node -is [string])) {
    $arr = @()
    foreach ($item in $Node) {
      $arr += ,(_McpRewriteStrings -Node $item -Rewrite $Rewrite)
    }
    return ,$arr
  }
  if ($Node -is [pscustomobject] -or $Node -is [hashtable]) {
    $out = [ordered]@{}
    $props = if ($Node -is [hashtable]) { $Node.Keys } else { $Node.PSObject.Properties.Name }
    foreach ($key in $props) {
      $val = if ($Node -is [hashtable]) { $Node[$key] } else { $Node.$key }
      $out[$key] = _McpRewriteStrings -Node $val -Rewrite $Rewrite
    }
    return [pscustomobject]$out
  }
  return $Node
}

$global:_McpSecretRegex = [regex]'\$\{secret:(?<n>[A-Za-z_][A-Za-z0-9_]*)(?<o>\?optional)?\}'

function global:Convert-McpBodyCursor {
  param([Parameter(Mandatory=$true)][string]$Path)
  $obj = Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json
  return (_McpRewriteStrings -Node $obj -Rewrite {
    param($s)
    $global:_McpSecretRegex.Replace($s, {
      param($m) '${env:' + $m.Groups['n'].Value + '}'
    })
  })
}

function global:Convert-McpBodyClaude {
  param([Parameter(Mandatory=$true)][string]$Path)
  $obj = Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json
  return (_McpRewriteStrings -Node $obj -Rewrite {
    param($s)
    # Optional -> ${NAME:-}; required -> ${NAME}
    $global:_McpSecretRegex.Replace($s, {
      param($m)
      if ($m.Groups['o'].Success) { '${' + $m.Groups['n'].Value + ':-}' }
      else { '${' + $m.Groups['n'].Value + '}' }
    })
  })
}

function global:Convert-McpBodyVscode {
  param([Parameter(Mandatory=$true)][string]$Path)
  $obj = Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json
  return (_McpRewriteStrings -Node $obj -Rewrite {
    param($s)
    $global:_McpSecretRegex.Replace($s, {
      param($m) '${input:' + $m.Groups['n'].Value + '}'
    })
  })
}

function global:Convert-McpBodyPassthrough {
  param([Parameter(Mandatory=$true)][string]$Path)
  return (Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json)
}

function global:Get-McpVscodeInputs {
  <#
    Scan all strings in $InputDir/*.json (filtered by $ItemsCsv), extract
    ${secret:NAME[?optional]} tokens, return an array of pscustomobject suitable
    for the VS Code "inputs" array. Deduplicates by id; if any occurrence is
    optional, the merged entry gets default "".
  #>
  param(
    [Parameter(Mandatory=$true)][string]$InputDir,
    [string]$ItemsCsv = ''
  )
  $files = Get-McpServerFiles -InputDir $InputDir -ItemsCsv $ItemsCsv
  $found = @{}
  foreach ($f in $files) {
    $raw = Get-Content -LiteralPath $f.Path -Raw
    foreach ($m in $global:_McpSecretRegex.Matches($raw)) {
      $id = $m.Groups['n'].Value
      $opt = $m.Groups['o'].Success
      if ($found.ContainsKey($id)) {
        if ($opt) { $found[$id] = $true }
      } else {
        $found[$id] = $opt
      }
    }
  }
  $inputs = @()
  foreach ($id in $found.Keys) {
    $isOptional = $found[$id]
    if ($isOptional) {
      $inputs += [pscustomobject]@{
        id = $id
        type = 'promptString'
        description = "$id (optional)"
        password = $true
        default = ''
      }
    } else {
      $inputs += [pscustomobject]@{
        id = $id
        type = 'promptString'
        description = $id
        password = $true
      }
    }
  }
  return @($inputs)
}

function global:Assemble-McpServers {
  <#
    Build a pscustomobject of the shape
      { <TopKey>: { name1: body1, name2: body2, ... } }
    using the given translator for each per-server body.
  #>
  param(
    [Parameter(Mandatory=$true)][string]$TopKey,
    [Parameter(Mandatory=$true)][scriptblock]$Translator,
    [Parameter(Mandatory=$true)][string]$InputDir,
    [string]$ItemsCsv = ''
  )
  $files = Get-McpServerFiles -InputDir $InputDir -ItemsCsv $ItemsCsv
  $servers = [ordered]@{}
  foreach ($f in $files) {
    $body = & $Translator $f.Path
    $servers[$f.Name] = $body
  }
  $outer = [ordered]@{}
  $outer[$TopKey] = [pscustomobject]$servers
  return [pscustomobject]$outer
}

function global:Write-McpJson {
  <#
    Write an object as pretty-printed JSON to $Path with two-space indent.
  #>
  param(
    [Parameter(Mandatory=$true)][object]$Object,
    [Parameter(Mandatory=$true)][string]$Path
  )
  $json = $Object | ConvertTo-Json -Depth 50
  Set-Content -LiteralPath $Path -Value $json -Encoding UTF8
}
