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

function global:Get-JsonPropertyValue {
  param(
    [Parameter(Mandatory=$true)][object]$Object,
    [Parameter(Mandatory=$true)][string]$Name
  )
  if ($null -eq $Object) { return $null }
  $prop = $Object.PSObject.Properties[$Name]
  if ($null -eq $prop) { return $null }
  return $prop.Value
}

function global:ConvertTo-TomlString {
  param([AllowNull()][object]$Value)
  $s = if ($null -eq $Value) { '' } else { [string]$Value }
  $s = $s.Replace('\', '\\')
  $s = $s -replace '"','\"'
  $s = $s -replace "`r",'\r'
  $s = $s -replace "`n",'\n'
  $s = $s -replace "`t",'\t'
  return '"' + $s + '"'
}

function global:ConvertTo-TomlStringArray {
  param([object[]]$Values)
  if (-not $Values) { return '[]' }
  return '[' + (($Values | ForEach-Object { ConvertTo-TomlString $_ }) -join ', ') + ']'
}

function global:Get-CodexSecretName {
  param([AllowNull()][string]$Value)
  if ($Value -match '^\$\{secret:(?<n>[A-Za-z_][A-Za-z0-9_]*)(\?optional)?\}$') {
    return $Matches['n']
  }
  return $null
}

function global:Get-CodexBearerSecretName {
  param([AllowNull()][string]$Value)
  if ($Value -match '^Bearer \$\{secret:(?<n>[A-Za-z_][A-Za-z0-9_]*)(\?optional)?\}$') {
    return $Matches['n']
  }
  return $null
}

function global:Assert-NoCodexSecretToken {
  param(
    [AllowNull()][string]$Value,
    [Parameter(Mandatory=$true)][string]$Field
  )
  if ($Value -match '\$\{secret:') {
    throw "codex mcp: unsupported secret token in $Field"
  }
}

function global:Add-CodexTomlTableLines {
  param(
    [Parameter(Mandatory=$true)][System.Collections.Generic.List[string]]$Lines,
    [Parameter(Mandatory=$true)][string]$Header,
    [object[]]$Entries = @()
  )
  if (-not $Entries -or $Entries.Count -eq 0) { return }
  $Lines.Add('')
  $Lines.Add($Header)
  foreach ($entry in ($Entries | Sort-Object Key)) {
    $Lines.Add((ConvertTo-TomlString $entry.Key) + ' = ' + (ConvertTo-TomlString $entry.Value))
  }
}

function global:ConvertTo-CodexMcpToml {
  <#
    Convert selected generic mcp-servers/*.json files to Codex config.toml
    content with [mcp_servers.<name>] tables.
  #>
  param(
    [Parameter(Mandatory=$true)][string]$InputDir,
    [string]$ItemsCsv = ''
  )

  $files = Get-McpServerFiles -InputDir $InputDir -ItemsCsv $ItemsCsv
  $allLines = New-Object System.Collections.Generic.List[string]
  $first = $true

  foreach ($file in $files) {
    if (-not $first) { $allLines.Add('') }
    $first = $false

    $server = Get-Content -LiteralPath $file.Path -Raw | ConvertFrom-Json
    $nameToml = ConvertTo-TomlString $file.Name
    $type = Get-JsonPropertyValue -Object $server -Name 'type'
    if (-not $type) {
      if (Get-JsonPropertyValue -Object $server -Name 'command') { $type = 'stdio' }
      else { $type = 'streamable_http' }
    }

    $lines = New-Object System.Collections.Generic.List[string]
    $lines.Add("[mcp_servers.$nameToml]")

    if ($type -eq 'stdio') {
      $command = Get-JsonPropertyValue -Object $server -Name 'command'
      if (-not ($command -is [string]) -or -not $command) { throw "codex mcp: stdio server $($file.Name) requires command" }
      Assert-NoCodexSecretToken -Value $command -Field 'command'
      $lines.Add('command = ' + (ConvertTo-TomlString $command))

      $args = @(Get-JsonPropertyValue -Object $server -Name 'args')
      if ($args.Count -gt 0 -and $null -ne $args[0]) {
        foreach ($arg in $args) { Assert-NoCodexSecretToken -Value ([string]$arg) -Field 'args' }
        $lines.Add('args = ' + (ConvertTo-TomlStringArray $args))
      }

      $cwd = Get-JsonPropertyValue -Object $server -Name 'cwd'
      if ($cwd) {
        Assert-NoCodexSecretToken -Value ([string]$cwd) -Field 'cwd'
        $lines.Add('cwd = ' + (ConvertTo-TomlString $cwd))
      }

      $secretEnvVars = @()
      $staticEnv = @()
      $env = Get-JsonPropertyValue -Object $server -Name 'env'
      if ($env) {
        foreach ($prop in $env.PSObject.Properties) {
          $value = [string]$prop.Value
          $secretName = Get-CodexSecretName -Value $value
          if ($secretName) {
            if ($secretName -ne $prop.Name) {
              throw "codex mcp: env secret for $($file.Name).$($prop.Name) must use the same variable name"
            }
            $secretEnvVars += $secretName
          } else {
            Assert-NoCodexSecretToken -Value $value -Field "env for $($file.Name)"
            $staticEnv += [pscustomobject]@{ Key = $prop.Name; Value = $value }
          }
        }
      }

      $envVars = @(Get-JsonPropertyValue -Object $server -Name 'env_vars')
      $combinedEnvVars = @($envVars | Where-Object { $null -ne $_ }) + $secretEnvVars
      if ($combinedEnvVars.Count -gt 0) {
        $lines.Add('env_vars = ' + (ConvertTo-TomlStringArray $combinedEnvVars))
      }

      foreach ($key in @('startup_timeout_sec','tool_timeout_sec')) {
        $value = Get-JsonPropertyValue -Object $server -Name $key
        if ($null -ne $value) { $lines.Add("$key = $value") }
      }
      foreach ($key in @('enabled','required')) {
        $value = Get-JsonPropertyValue -Object $server -Name $key
        if ($null -ne $value) { $lines.Add("$key = " + ([string]$value).ToLower()) }
      }
      foreach ($key in @('enabled_tools','disabled_tools')) {
        $value = @(Get-JsonPropertyValue -Object $server -Name $key)
        if ($value.Count -gt 0 -and $null -ne $value[0]) { $lines.Add("$key = " + (ConvertTo-TomlStringArray $value)) }
      }
      Add-CodexTomlTableLines -Lines $lines -Header "[mcp_servers.$nameToml.env]" -Entries $staticEnv
    } elseif ($type -eq 'http' -or $type -eq 'streamable_http') {
      $url = Get-JsonPropertyValue -Object $server -Name 'url'
      if (-not ($url -is [string]) -or -not $url) { throw "codex mcp: HTTP server $($file.Name) requires url" }
      Assert-NoCodexSecretToken -Value $url -Field 'url'
      $lines.Add('url = ' + (ConvertTo-TomlString $url))

      $headers = Get-JsonPropertyValue -Object $server -Name 'headers'
      if (-not $headers) { $headers = Get-JsonPropertyValue -Object $server -Name 'http_headers' }
      $staticHeaders = @()
      $envHeaders = @()
      $bearerTokenEnvVar = Get-JsonPropertyValue -Object $server -Name 'bearer_token_env_var'
      if ($headers) {
        foreach ($prop in $headers.PSObject.Properties) {
          $value = [string]$prop.Value
          $bearerSecret = Get-CodexBearerSecretName -Value $value
          $bareSecret = Get-CodexSecretName -Value $value
          if ($prop.Name -eq 'Authorization' -and $bearerSecret) {
            $bearerTokenEnvVar = $bearerSecret
          } elseif ($bareSecret) {
            $envHeaders += [pscustomobject]@{ Key = $prop.Name; Value = $bareSecret }
          } else {
            Assert-NoCodexSecretToken -Value $value -Field "headers for $($file.Name)"
            $staticHeaders += [pscustomobject]@{ Key = $prop.Name; Value = $value }
          }
        }
      }
      if ($bearerTokenEnvVar) { $lines.Add('bearer_token_env_var = ' + (ConvertTo-TomlString $bearerTokenEnvVar)) }

      foreach ($key in @('startup_timeout_sec','tool_timeout_sec')) {
        $value = Get-JsonPropertyValue -Object $server -Name $key
        if ($null -ne $value) { $lines.Add("$key = $value") }
      }
      foreach ($key in @('enabled','required')) {
        $value = Get-JsonPropertyValue -Object $server -Name $key
        if ($null -ne $value) { $lines.Add("$key = " + ([string]$value).ToLower()) }
      }
      foreach ($key in @('enabled_tools','disabled_tools')) {
        $value = @(Get-JsonPropertyValue -Object $server -Name $key)
        if ($value.Count -gt 0 -and $null -ne $value[0]) { $lines.Add("$key = " + (ConvertTo-TomlStringArray $value)) }
      }
      Add-CodexTomlTableLines -Lines $lines -Header "[mcp_servers.$nameToml.http_headers]" -Entries $staticHeaders
      Add-CodexTomlTableLines -Lines $lines -Header "[mcp_servers.$nameToml.env_http_headers]" -Entries $envHeaders
    } else {
      throw "codex mcp: unsupported server type for $($file.Name): $type"
    }

    foreach ($line in $lines) { $allLines.Add($line) }
  }

  return ($allLines -join [Environment]::NewLine) + [Environment]::NewLine
}
