# Pester 5+ tests for MCP sync — per-tool .ps1 scripts and sync-all integration.
# Run from repo: pwsh -File test/run-pester.ps1

BeforeDiscovery {
  $script:ThisRoot = $PSScriptRoot
  $script:RepoRoot = (Resolve-Path (Join-Path $script:ThisRoot '..\..')).Path
  $script:FixtureMcp = Join-Path $script:RepoRoot 'test\fixtures\mcp'
  $script:FixtureTwo = Join-Path $script:RepoRoot 'test\fixtures\two-skills'
  $script:SyncAllPs1 = Join-Path $script:RepoRoot 'scripts\sync-all.ps1'
}

BeforeAll {
  if (-not $script:RepoRoot) {
    $script:RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
  }
  if (-not $script:FixtureMcp) {
    $script:FixtureMcp = Join-Path $script:RepoRoot 'test\fixtures\mcp'
  }
  if (-not $script:FixtureTwo) {
    $script:FixtureTwo = Join-Path $script:RepoRoot 'test\fixtures\two-skills'
  }
  if (-not $script:SyncAllPs1) {
    $script:SyncAllPs1 = Join-Path $script:RepoRoot 'scripts\sync-all.ps1'
  }

  $script:McpScript = {
    param([string]$tool, [string]$file = 'sync-mcp.ps1')
    Join-Path $script:RepoRoot ("scripts\$tool\$file")
  }

  $script:NewMcpSource = {
    $tmp = [System.IO.Path]::GetTempPath()
    $d = Join-Path $tmp ("pester_mcp_src_" + [Guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $d -Force | Out-Null
    Copy-Item -Path (Join-Path $script:FixtureMcp '*') -Destination $d -Recurse -Force
    return $d
  }

  $script:NewOut = {
    $tmp = [System.IO.Path]::GetTempPath()
    $d = Join-Path $tmp ("pester_mcp_out_" + [Guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $d -Force | Out-Null
    return $d
  }
}

Describe 'sync-mcp.ps1 — basic translation' {
  It 'cursor: writes mcpServers with ${env:NAME}' {
    $src = & $script:NewMcpSource
    $out = & $script:NewOut
    try {
      & (& $script:McpScript 'cursor') -InputPath (Join-Path $src 'mcp-servers') -OutputPath $out
      $j = Get-Content -LiteralPath (Join-Path $out '.cursor\mcp.json') -Raw | ConvertFrom-Json
      $j.PSObject.Properties.Name | Should -Be 'mcpServers'
      ($j.mcpServers.PSObject.Properties.Name | Sort-Object) -join ',' | Should -Be 'context7,httpbin'
      $j.mcpServers.context7.env.CONTEXT7_API_KEY | Should -Be '${env:CONTEXT7_API_KEY}'
      $j.mcpServers.httpbin.headers.Authorization | Should -Be 'Bearer ${env:HTTPBIN_TOKEN}'
    } finally {
      Remove-Item -LiteralPath $src, $out -Recurse -Force -ErrorAction SilentlyContinue
    }
  }

  It 'claude: required ${NAME} and optional ${NAME:-}' {
    $src = & $script:NewMcpSource
    $out = & $script:NewOut
    try {
      & (& $script:McpScript 'claude') -InputPath (Join-Path $src 'mcp-servers') -OutputPath $out
      $j = Get-Content -LiteralPath (Join-Path $out '.mcp.json') -Raw | ConvertFrom-Json
      $j.mcpServers.context7.env.CONTEXT7_API_KEY | Should -Be '${CONTEXT7_API_KEY:-}'
      $j.mcpServers.httpbin.headers.Authorization | Should -Be 'Bearer ${HTTPBIN_TOKEN}'
    } finally {
      Remove-Item -LiteralPath $src, $out -Recurse -Force -ErrorAction SilentlyContinue
    }
  }

  It 'vscode: writes servers + inputs[] with optional default ""' {
    $src = & $script:NewMcpSource
    $out = & $script:NewOut
    try {
      & (& $script:McpScript 'vscode') -InputPath (Join-Path $src 'mcp-servers') -OutputPath $out
      $j = Get-Content -LiteralPath (Join-Path $out '.vscode\mcp.json') -Raw | ConvertFrom-Json
      ($j.PSObject.Properties.Name | Sort-Object) -join ',' | Should -Be 'inputs,servers'
      $j.servers.context7.env.CONTEXT7_API_KEY | Should -Be '${input:CONTEXT7_API_KEY}'
      $j.servers.httpbin.headers.Authorization | Should -Be 'Bearer ${input:HTTPBIN_TOKEN}'
      $j.inputs.Count | Should -Be 2
      $opt = $j.inputs | Where-Object { $_.id -eq 'CONTEXT7_API_KEY' }
      $opt.default | Should -Be ''
      $opt.password | Should -BeTrue
      $req = $j.inputs | Where-Object { $_.id -eq 'HTTPBIN_TOKEN' }
      $req.PSObject.Properties.Name -contains 'default' | Should -BeFalse
      $req.password | Should -BeTrue
    } finally {
      Remove-Item -LiteralPath $src, $out -Recurse -Force -ErrorAction SilentlyContinue
    }
  }

  It 'junie: prints stdout snippet, writes nothing under .junie' {
    $src = & $script:NewMcpSource
    $out = & $script:NewOut
    try {
      $output = & (& $script:McpScript 'junie') -InputPath (Join-Path $src 'mcp-servers') -OutputPath $out 6>&1
      ($output | Out-String) | Should -Match 'mcpServers'
      ($output | Out-String) | Should -Match 'context7'
      $junie = Join-Path $out '.junie'
      if (Test-Path -LiteralPath $junie) {
        @(Get-ChildItem -LiteralPath $junie -Recurse -File).Count | Should -Be 0
      }
    } finally {
      Remove-Item -LiteralPath $src, $out -Recurse -Force -ErrorAction SilentlyContinue
    }
  }

  It 'codex: writes config.toml with Codex MCP tables' {
    $src = & $script:NewMcpSource
    $out = & $script:NewOut
    try {
      & (& $script:McpScript 'codex') -InputPath (Join-Path $src 'mcp-servers') -OutputPath $out
      $toml = Get-Content -LiteralPath (Join-Path $out '.codex\config.toml') -Raw
      $toml | Should -Match '(?m)^\[mcp_servers\."context7"\]$'
      $toml | Should -Match '(?m)^command = "npx"$'
      $toml | Should -Match '(?m)^env_vars = \["CONTEXT7_API_KEY"\]$'
      $toml | Should -Match '(?m)^\[mcp_servers\."httpbin"\]$'
      $toml | Should -Match '(?m)^bearer_token_env_var = "HTTPBIN_TOKEN"$'
    } finally {
      Remove-Item -LiteralPath $src, $out -Recurse -Force -ErrorAction SilentlyContinue
    }
  }

  It 'codex: merges only mcp_servers into existing config.toml' {
    $src = & $script:NewMcpSource
    $out = & $script:NewOut
    try {
      $configDir = Join-Path $out '.codex'
      New-Item -ItemType Directory -Path $configDir -Force | Out-Null
      @'
model = "gpt-5"

[mcp_servers."keep"]
command = "keep-server"

[mcp_servers."context7"]
command = "old-server"
'@ | Set-Content -LiteralPath (Join-Path $configDir 'config.toml') -Encoding UTF8

      & (& $script:McpScript 'codex') -InputPath (Join-Path $src 'mcp-servers') -OutputPath $out -Items context7
      $toml = Get-Content -LiteralPath (Join-Path $configDir 'config.toml') -Raw
      $toml | Should -Match '(?m)^model = "gpt-5"$'
      $toml | Should -Match '(?m)^\[mcp_servers\."keep"\]$'
      $toml | Should -Match '(?m)^command = "keep-server"$'
      $toml | Should -Match '(?m)^\[mcp_servers\."context7"\]$'
      $toml | Should -Match '(?m)^command = "npx"$'
      $toml | Should -Not -Match 'old-server'

      & (& $script:McpScript 'codex') -InputPath (Join-Path $src 'mcp-servers') -OutputPath $out -Items context7 -Clean
      $toml = Get-Content -LiteralPath (Join-Path $configDir 'config.toml') -Raw
      $toml | Should -Match '(?m)^model = "gpt-5"$'
      $toml | Should -Not -Match '(?m)^\[mcp_servers\."keep"\]$'
      $toml | Should -Match '(?m)^\[mcp_servers\."context7"\]$'
    } finally {
      Remove-Item -LiteralPath $src, $out -Recurse -Force -ErrorAction SilentlyContinue
    }
  }

  It 'codex: codex-sync-mcp false leaves config.toml untouched' {
    $src = & $script:NewMcpSource
    $out = & $script:NewOut
    $oldConf = $env:CYNCIA_CONF
    try {
      $configDir = Join-Path $out '.codex'
      New-Item -ItemType Directory -Path $configDir -Force | Out-Null
      $configPath = Join-Path $configDir 'config.toml'
      @'
model = "gpt-5"

[mcp_servers."existing"]
command = "existing-server"
'@ | Set-Content -LiteralPath $configPath -Encoding UTF8
      $before = Get-Content -LiteralPath $configPath -Raw
      $conf = Join-Path $out 'cyncia.conf'
      Set-Content -LiteralPath $conf -Value 'codex-sync-mcp: false' -Encoding UTF8
      $env:CYNCIA_CONF = $conf

      & (& $script:McpScript 'codex') -InputPath (Join-Path $src 'mcp-servers') -OutputPath $out -Clean
      (Get-Content -LiteralPath $configPath -Raw) | Should -Be $before
    } finally {
      if ($oldConf) { $env:CYNCIA_CONF = $oldConf } else { Remove-Item Env:CYNCIA_CONF -ErrorAction SilentlyContinue }
      Remove-Item -LiteralPath $src, $out -Recurse -Force -ErrorAction SilentlyContinue
    }
  }
}

Describe 'sync-mcp.ps1 — items and clean' {
  It 'cursor -Items context7: only context7 in mcpServers' {
    $src = & $script:NewMcpSource
    $out = & $script:NewOut
    try {
      & (& $script:McpScript 'cursor') -InputPath (Join-Path $src 'mcp-servers') -OutputPath $out -Items 'context7'
      $j = Get-Content -LiteralPath (Join-Path $out '.cursor\mcp.json') -Raw | ConvertFrom-Json
      ($j.mcpServers.PSObject.Properties.Name) -join ',' | Should -Be 'context7'
    } finally {
      Remove-Item -LiteralPath $src, $out -Recurse -Force -ErrorAction SilentlyContinue
    }
  }

  It 'cursor -Items with spaces after comma: both servers included' {
    $src = & $script:NewMcpSource
    $out = & $script:NewOut
    try {
      & (& $script:McpScript 'cursor') -InputPath (Join-Path $src 'mcp-servers') -OutputPath $out -Items 'context7, httpbin'
      $j = Get-Content -LiteralPath (Join-Path $out '.cursor\mcp.json') -Raw | ConvertFrom-Json
      ($j.mcpServers.PSObject.Properties.Name | Sort-Object) -join ',' | Should -Be 'context7,httpbin'
    } finally {
      Remove-Item -LiteralPath $src, $out -Recurse -Force -ErrorAction SilentlyContinue
    }
  }

  It 'cursor: rerun replaces (not merges)' {
    $src = & $script:NewMcpSource
    $out = & $script:NewOut
    try {
      & (& $script:McpScript 'cursor') -InputPath (Join-Path $src 'mcp-servers') -OutputPath $out
      & (& $script:McpScript 'cursor') -InputPath (Join-Path $src 'mcp-servers') -OutputPath $out -Items 'context7'
      $j = Get-Content -LiteralPath (Join-Path $out '.cursor\mcp.json') -Raw | ConvertFrom-Json
      @($j.mcpServers.PSObject.Properties).Count | Should -Be 1
    } finally {
      Remove-Item -LiteralPath $src, $out -Recurse -Force -ErrorAction SilentlyContinue
    }
  }

  It 'vscode -Clean with empty source removes target' {
    $src = & $script:NewMcpSource
    $out = & $script:NewOut
    try {
      & (& $script:McpScript 'vscode') -InputPath (Join-Path $src 'mcp-servers') -OutputPath $out
      Get-ChildItem -LiteralPath (Join-Path $src 'mcp-servers') -Filter '*.json' -File |
        ForEach-Object { Remove-Item -LiteralPath $_.FullName -Force }
      & (& $script:McpScript 'vscode') -InputPath (Join-Path $src 'mcp-servers') -OutputPath $out -Clean
      (Test-Path -LiteralPath (Join-Path $out '.vscode\mcp.json')) | Should -BeFalse
    } finally {
      Remove-Item -LiteralPath $src, $out -Recurse -Force -ErrorAction SilentlyContinue
    }
  }
}

Describe 'sync-all.ps1 — MCP integration' {
  It 'writes MCP config for cursor/claude/vscode/codex when mcp-servers/ present' {
    $src = & {
      $tmp = [System.IO.Path]::GetTempPath()
      $d = Join-Path $tmp ("pester_mcp_all_src_" + [Guid]::NewGuid().ToString('N'))
      New-Item -ItemType Directory -Path $d -Force | Out-Null
      Copy-Item -Path (Join-Path $script:FixtureTwo '*') -Destination $d -Recurse -Force
      New-Item -ItemType Directory -Path (Join-Path $d 'mcp-servers') -Force | Out-Null
      Copy-Item -Path (Join-Path $script:FixtureMcp 'mcp-servers\*.json') -Destination (Join-Path $d 'mcp-servers') -Force
      $d
    }
    $out = & $script:NewOut
    try {
      & $script:SyncAllPs1 -InputRoot $src -OutputRoot $out
      (Test-Path -LiteralPath (Join-Path $out '.cursor\mcp.json')) | Should -BeTrue
      (Test-Path -LiteralPath (Join-Path $out '.mcp.json')) | Should -BeTrue
      (Test-Path -LiteralPath (Join-Path $out '.vscode\mcp.json')) | Should -BeTrue
      (Test-Path -LiteralPath (Join-Path $out '.codex\config.toml')) | Should -BeTrue
      (Test-Path -LiteralPath (Join-Path $out '.junie\mcp.json')) | Should -BeFalse
    } finally {
      Remove-Item -LiteralPath $src, $out -Recurse -Force -ErrorAction SilentlyContinue
    }
  }

  It 'no MCP step when mcp-servers/ absent' {
    $src = & {
      $tmp = [System.IO.Path]::GetTempPath()
      $d = Join-Path $tmp ("pester_mcp_none_src_" + [Guid]::NewGuid().ToString('N'))
      New-Item -ItemType Directory -Path $d -Force | Out-Null
      Copy-Item -Path (Join-Path $script:FixtureTwo '*') -Destination $d -Recurse -Force
      $d
    }
    $out = & $script:NewOut
    try {
      & $script:SyncAllPs1 -InputRoot $src -OutputRoot $out -Tools cursor
      (Test-Path -LiteralPath (Join-Path $out '.cursor\mcp.json')) | Should -BeFalse
    } finally {
      Remove-Item -LiteralPath $src, $out -Recurse -Force -ErrorAction SilentlyContinue
    }
  }
}

Describe 'sync-agents.ps1 — MCP frontmatter translation' {
  BeforeEach {
    $script:agentsSrc = & $script:NewOut
    New-Item -ItemType Directory -Path (Join-Path $script:agentsSrc 'agents') -Force | Out-Null
    @"
---
name: aside
description: Side question agent.
mcp-servers: "context7, memory"
---

Body.
"@ | Set-Content -LiteralPath (Join-Path $script:agentsSrc 'agents\aside.md') -NoNewline
    @"
---
name: plain
description: No MCP.
---

Plain body.
"@ | Set-Content -LiteralPath (Join-Path $script:agentsSrc 'agents\plain.md') -NoNewline
    $script:agentsOut = & $script:NewOut
  }
  AfterEach {
    Remove-Item -LiteralPath $script:agentsSrc, $script:agentsOut -Recurse -Force -ErrorAction SilentlyContinue
  }

  It 'cursor strips mcp-servers' {
    & (& $script:McpScript 'cursor' 'sync-agents.ps1') -InputPath (Join-Path $script:agentsSrc 'agents') -OutputPath $script:agentsOut
    $body = Get-Content -LiteralPath (Join-Path $script:agentsOut '.cursor\agents\aside.md') -Raw
    $body | Should -Not -Match '(?m)^mcp-servers:'
    $body | Should -Not -Match '(?m)^mcpServers:'
    $body | Should -Not -Match '(?m)^tools:'
  }

  It 'claude rewrites to mcpServers flow list' {
    & (& $script:McpScript 'claude' 'sync-agents.ps1') -InputPath (Join-Path $script:agentsSrc 'agents') -OutputPath $script:agentsOut
    $body = Get-Content -LiteralPath (Join-Path $script:agentsOut '.claude\agents\aside.md') -Raw
    $body | Should -Match '(?m)^mcpServers: \[context7, memory\]$'
    $body | Should -Not -Match '(?m)^mcp-servers:'
    $plain = Get-Content -LiteralPath (Join-Path $script:agentsOut '.claude\agents\plain.md') -Raw
    $plain | Should -Not -Match '(?m)^mcpServers:'
  }

  It 'copilot rewrites to tools list with /* suffix' {
    & (& $script:McpScript 'copilot' 'sync-agents.ps1') -InputPath (Join-Path $script:agentsSrc 'agents') -OutputPath $script:agentsOut
    $body = Get-Content -LiteralPath (Join-Path $script:agentsOut '.github\agents\aside.md') -Raw
    $body | Should -Match '(?m)^tools: \["context7/\*", "memory/\*"\]$'
    $body | Should -Not -Match '(?m)^mcp-servers:'
  }

  It 'junie strips mcp-servers' {
    & (& $script:McpScript 'junie' 'sync-agents.ps1') -InputPath (Join-Path $script:agentsSrc 'agents') -OutputPath $script:agentsOut
    $body = Get-Content -LiteralPath (Join-Path $script:agentsOut '.junie\agents\aside.md') -Raw
    $body | Should -Not -Match '(?m)^mcp-servers:'
    $body | Should -Not -Match '(?m)^tools:'
  }

  It 'codex writes TOML custom agent without generic mcp-servers' {
    & (& $script:McpScript 'codex' 'sync-agents.ps1') -InputPath (Join-Path $script:agentsSrc 'agents') -OutputPath $script:agentsOut
    $body = Get-Content -LiteralPath (Join-Path $script:agentsOut '.codex\agents\aside.toml') -Raw
    $body | Should -Match '(?m)^name = "aside"$'
    $body | Should -Match '(?m)^description = "Side question agent\."$'
    $body | Should -Match '(?m)^developer_instructions = """$'
    $body | Should -Match 'Body\.'
    $body | Should -Not -Match 'mcp-servers'
    $body | Should -Not -Match 'mcpServers'
  }

  It 'copilot errors when both mcp-servers and tools are present' {
    @"
---
name: conflict
description: Conflicting agent.
mcp-servers: "context7"
tools: ["foo/*"]
---

Body.
"@ | Set-Content -LiteralPath (Join-Path $script:agentsSrc 'agents\conflict.md') -NoNewline
    { & (& $script:McpScript 'copilot' 'sync-agents.ps1') -InputPath (Join-Path $script:agentsSrc 'agents') -OutputPath $script:agentsOut -Items 'conflict' } |
      Should -Throw '*both*mcp-servers*tools*'
  }
}
