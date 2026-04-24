# Pester 5+ tests for scripts/sync-all.ps1 and per-tool .ps1 scripts.
# Run from repo: pwsh -File test/run-pester.ps1

BeforeDiscovery {
  $script:ThisRoot = $PSScriptRoot
  $script:RepoRoot = (Resolve-Path (Join-Path $script:ThisRoot '..\..')).Path
  $script:FixtureTwo = Join-Path $script:RepoRoot 'test\fixtures\two-skills'
  $script:SyncAllPs1 = Join-Path $script:RepoRoot 'scripts\sync-all.ps1'
}

BeforeAll {
  if (-not (Get-Module -ListAvailable -Name Pester)) {
    throw 'Pester is not installed. Install-Module Pester -Scope CurrentUser -Force (v5+).'
  }
  Import-Module Pester

  # Ensure paths are set (BeforeDiscovery scope can differ per Pester run).
  if (-not $script:RepoRoot) {
    $script:RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
  }
  if (-not $script:FixtureTwo) {
    $script:FixtureTwo = Join-Path $script:RepoRoot 'test\fixtures\two-skills'
  }
  if (-not $script:SyncAllPs1) {
    $script:SyncAllPs1 = Join-Path $script:RepoRoot 'scripts\sync-all.ps1'
  }

  # Helper scriptblocks: Pester can execute tests in isolated scopes, so prefer
  # script-scoped scriptblocks over global functions.
  $script:NewTestSourceFromFixture = {
    $tmp = [System.IO.Path]::GetTempPath()
    $d = Join-Path $tmp ("pester_src_" + [Guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $d -Force | Out-Null
    Copy-Item -Path (Join-Path $script:FixtureTwo '*') -Destination $d -Recurse -Force
    return $d
  }

  $script:NewTestOutputDir = {
    $tmp = [System.IO.Path]::GetTempPath()
    $d = Join-Path $tmp ("pester_out_" + [Guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $d -Force | Out-Null
    return $d
  }
}

Describe 'sync-all.ps1' {
  It 'with -Tools cursor creates .cursor outputs' {
    $src = & $script:NewTestSourceFromFixture
    $out = & $script:NewTestOutputDir
    try {
      & $script:SyncAllPs1 -InputRoot $src -OutputRoot $out -Tools cursor
      (Test-Path -LiteralPath (Join-Path $out '.cursor\agents\one.md')) | Should -BeTrue
      (Test-Path -LiteralPath (Join-Path $out '.cursor\skills\alpha\SKILL.md')) | Should -BeTrue
      (Test-Path -LiteralPath (Join-Path $out 'AGENTS.md')) | Should -BeTrue
    } finally {
      Remove-Item -LiteralPath $src, $out -Recurse -Force -ErrorAction SilentlyContinue
    }
  }

  It 'missing required parameters does not hang (non-interactive pwsh errors)' {
    # Calling a script with missing Mandatory params can trigger an interactive prompt.
    # Run in a separate non-interactive process so we get a normal error/exit code.
    $exe = (Get-Process -Id $PID).MainModule.FileName
    $cmd = "& '$script:SyncAllPs1' -InputRoot 'x'"
    $p = Start-Process -FilePath $exe -ArgumentList @('-NoProfile','-NonInteractive','-Command', $cmd) -PassThru -Wait
    $p.ExitCode | Should -Not -Be 0
  }

  It 'unknown tool fails' {
    $src = & $script:NewTestSourceFromFixture
    $out = & $script:NewTestOutputDir
    try {
      { & $script:SyncAllPs1 -InputRoot $src -OutputRoot $out -Tools 'nope' } | Should -Throw
    } finally {
      Remove-Item -LiteralPath $src, $out -Recurse -Force -ErrorAction SilentlyContinue
    }
  }

  It 'input tree without AGENTS.md throws' {
    $src = & $script:NewTestSourceFromFixture
    $out = & $script:NewTestOutputDir
    try {
      Remove-Item -LiteralPath (Join-Path $src 'AGENTS.md') -Force
      { & $script:SyncAllPs1 -InputRoot $src -OutputRoot $out -Tools cursor } | Should -Throw
    } finally {
      Remove-Item -LiteralPath $src, $out -Recurse -Force -ErrorAction SilentlyContinue
    }
  }

  It 'forwards -Items to skills (alpha only; other skills omitted)' {
    $src = & $script:NewTestSourceFromFixture
    $out = & $script:NewTestOutputDir
    try {
      & $script:SyncAllPs1 -InputRoot $src -OutputRoot $out -Tools cursor -Items alpha
      (Test-Path -LiteralPath (Join-Path $out '.cursor\skills\alpha\SKILL.md')) | Should -BeTrue
      (Test-Path -LiteralPath (Join-Path $out '.cursor\skills\beta')) | Should -BeFalse
    } finally {
      Remove-Item -LiteralPath $src, $out -Recurse -Force -ErrorAction SilentlyContinue
    }
  }

  It 'forwards -Items for agent, skill, and rule names together (one,alpha,ra)' {
    $src = & $script:NewTestSourceFromFixture
    $out = & $script:NewTestOutputDir
    try {
      & $script:SyncAllPs1 -InputRoot $src -OutputRoot $out -Tools cursor -Items 'one,alpha,ra'
      (Test-Path -LiteralPath (Join-Path $out '.cursor\agents\one.md')) | Should -BeTrue
      (Test-Path -LiteralPath (Join-Path $out '.cursor\skills\alpha\SKILL.md')) | Should -BeTrue
      (Test-Path -LiteralPath (Join-Path $out '.cursor\rules\ra.mdc')) | Should -BeTrue
      (Test-Path -LiteralPath (Join-Path $out '.cursor\skills\beta')) | Should -BeFalse
      (Test-Path -LiteralPath (Join-Path $out '.cursor\rules\rb.mdc')) | Should -BeFalse
    } finally {
      Remove-Item -LiteralPath $src, $out -Recurse -Force -ErrorAction SilentlyContinue
    }
  }

  It 'with -Clean and rule removed from source drops stale .mdc' {
    $src = & $script:NewTestSourceFromFixture
    $out = & $script:NewTestOutputDir
    try {
      & $script:SyncAllPs1 -InputRoot $src -OutputRoot $out -Tools cursor
      (Test-Path -LiteralPath (Join-Path $out '.cursor\rules\rb.mdc')) | Should -BeTrue
      Remove-Item -LiteralPath (Join-Path $src 'rules\rb.md') -Force
      & $script:SyncAllPs1 -InputRoot $src -OutputRoot $out -Tools cursor -Clean
      (Test-Path -LiteralPath (Join-Path $out '.cursor\rules\ra.mdc')) | Should -BeTrue
      (Test-Path -LiteralPath (Join-Path $out '.cursor\rules\rb.mdc')) | Should -BeFalse
    } finally {
      Remove-Item -LiteralPath $src, $out -Recurse -Force -ErrorAction SilentlyContinue
    }
  }

  It 'Copilot -Items ra -Clean drops stale second instruction file' {
    $src = & $script:NewTestSourceFromFixture
    $out = & $script:NewTestOutputDir
    try {
      & $script:SyncAllPs1 -InputRoot $src -OutputRoot $out -Tools copilot
      (Test-Path -LiteralPath (Join-Path $out '.github\instructions\rb.instructions.md')) | Should -BeTrue
      & $script:SyncAllPs1 -InputRoot $src -OutputRoot $out -Tools copilot -Items ra -Clean
      (Test-Path -LiteralPath (Join-Path $out '.github\instructions\ra.instructions.md')) | Should -BeTrue
      (Test-Path -LiteralPath (Join-Path $out '.github\instructions\rb.instructions.md')) | Should -BeFalse
    } finally {
      Remove-Item -LiteralPath $src, $out -Recurse -Force -ErrorAction SilentlyContinue
    }
  }

  It '-Clean removes stale cursor agent output' {
    $src = & $script:NewTestSourceFromFixture
    $out = & $script:NewTestOutputDir
    try {
      # Generate once
      & $script:SyncAllPs1 -InputRoot $src -OutputRoot $out -Tools cursor
      (Test-Path -LiteralPath (Join-Path $out '.cursor\agents\one.md')) | Should -BeTrue
      # Remove source agent and re-run with -Clean
      Remove-Item -LiteralPath (Join-Path $src 'agents\one.md') -Force
      & $script:SyncAllPs1 -InputRoot $src -OutputRoot $out -Tools cursor -Clean
      (Test-Path -LiteralPath (Join-Path $out '.cursor\agents\one.md')) | Should -BeFalse
    } finally {
      Remove-Item -LiteralPath $src, $out -Recurse -Force -ErrorAction SilentlyContinue
    }
  }

  It 'skill frontmatter translation: cursor strips applies-to; claude renames to paths' {
    $src = & $script:NewTestSourceFromFixture
    $out = & $script:NewTestOutputDir
    try {
      $skill = Join-Path $src 'skills\alpha\SKILL.md'
      Add-Content -LiteralPath $skill -Value @(
        ''
      )
      # Insert applies-to into frontmatter (after description line)
      $lines = Get-Content -LiteralPath $skill
      $idx = [Array]::IndexOf($lines, 'description: First test skill.')
      if ($idx -ge 0) {
        $lines = $lines[0..$idx] + @('applies-to: "**/*.java"') + $lines[($idx+1)..($lines.Count-1)]
        Set-Content -LiteralPath $skill -Value $lines -Encoding UTF8
      }

      & $script:SyncAllPs1 -InputRoot $src -OutputRoot $out -Tools cursor
      $c = Get-Content -LiteralPath (Join-Path $out '.cursor\skills\alpha\SKILL.md') -Raw
      $c | Should -Not -Match 'applies-to:'

      & $script:SyncAllPs1 -InputRoot $src -OutputRoot $out -Tools claude
      $cl = Get-Content -LiteralPath (Join-Path $out '.claude\skills\alpha\SKILL.md') -Raw
      $cl | Should -Match 'paths:\s*"\*\*/\*\.java"'
      $cl | Should -Not -Match 'applies-to:'
    } finally {
      Remove-Item -LiteralPath $src, $out -Recurse -Force -ErrorAction SilentlyContinue
    }
  }

  It 'Junie guidelines include merged rules in .junie/AGENTS.md' {
    $src = & $script:NewTestSourceFromFixture
    $out = & $script:NewTestOutputDir
    try {
      & $script:SyncAllPs1 -InputRoot $src -OutputRoot $out -Tools junie
      $j = Get-Content -LiteralPath (Join-Path $out '.junie\AGENTS.md') -Raw
      $j | Should -Match '## Project rules'
      $j | Should -Match '### `ra.md`'
      $j | Should -Match 'Rule A'
    } finally {
      Remove-Item -LiteralPath $src, $out -Recurse -Force -ErrorAction SilentlyContinue
    }
  }

  It 'with -Clean and skill removed from source drops stale skill dir' {
    $src = & $script:NewTestSourceFromFixture
    $out = & $script:NewTestOutputDir
    try {
      & $script:SyncAllPs1 -InputRoot $src -OutputRoot $out -Tools cursor
      (Test-Path -LiteralPath (Join-Path $out '.cursor\skills\beta')) | Should -BeTrue
      Remove-Item -LiteralPath (Join-Path $src 'skills\beta') -Recurse -Force
      & $script:SyncAllPs1 -InputRoot $src -OutputRoot $out -Tools cursor -Clean
      (Test-Path -LiteralPath (Join-Path $out '.cursor\skills\beta')) | Should -BeFalse
    } finally {
      Remove-Item -LiteralPath $src, $out -Recurse -Force -ErrorAction SilentlyContinue
    }
  }
}

Describe 'Per-tool .ps1' {
  It 'cursor\sync-rules.ps1 respects -Items' {
    $src = & $script:NewTestSourceFromFixture
    $out = & $script:NewTestOutputDir
    $r = Join-Path $script:RepoRoot 'scripts\cursor\sync-rules.ps1'
    try {
      & $r -InputPath (Join-Path $src 'rules') -OutputPath $out -Items ra
      (Test-Path -LiteralPath (Join-Path $out '.cursor\rules\ra.mdc')) | Should -BeTrue
      (Test-Path -LiteralPath (Join-Path $out '.cursor\rules\rb.mdc')) | Should -BeFalse
    } finally {
      Remove-Item -LiteralPath $src, $out -Recurse -Force -ErrorAction SilentlyContinue
    }
  }

  It 'claude\sync-rules.ps1 is a no-op' {
    $src = & $script:NewTestSourceFromFixture
    $out = & $script:NewTestOutputDir
    $r = Join-Path $script:RepoRoot 'scripts\claude\sync-rules.ps1'
    try {
      { & $r -InputPath (Join-Path $src 'rules') -OutputPath $out -Clean } | Should -Not -Throw
    } finally {
      Remove-Item -LiteralPath $src, $out -Recurse -Force -ErrorAction SilentlyContinue
    }
  }

  It 'copilot\sync-rules.ps1 -Clean empties instructions dir' {
    $src = & $script:NewTestSourceFromFixture
    $out = & $script:NewTestOutputDir
    $r = Join-Path $script:RepoRoot 'scripts\copilot\sync-rules.ps1'
    try {
      $inst = Join-Path $out '.github\instructions'
      New-Item -ItemType Directory -Force -Path $inst | Out-Null
      Set-Content -LiteralPath (Join-Path $inst 'stale.instructions.md') -Value 'stale' -Encoding UTF8
      & $r -InputPath (Join-Path $src 'rules') -OutputPath $out -Items ra -Clean
      (Test-Path -LiteralPath (Join-Path $inst 'stale.instructions.md')) | Should -BeFalse
      (Test-Path -LiteralPath (Join-Path $inst 'ra.instructions.md')) | Should -BeTrue
    } finally {
      Remove-Item -LiteralPath $src, $out -Recurse -Force -ErrorAction SilentlyContinue
    }
  }

  It 'cursor\sync-agent-guidelines.ps1 same root does not delete AGENTS.md (even with -Clean)' {
    $same = Join-Path ([System.IO.Path]::GetTempPath()) ("pester_same_" + [Guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Force -Path $same | Out-Null
    try {
      Copy-Item -LiteralPath (Join-Path $script:FixtureTwo 'AGENTS.md') -Destination (Join-Path $same 'AGENTS.md') -Force
      $g = Join-Path $script:RepoRoot 'scripts\cursor\sync-agent-guidelines.ps1'
      & $g -InputPath $same -OutputPath $same -Clean
      (Test-Path -LiteralPath (Join-Path $same 'AGENTS.md')) | Should -BeTrue
    } finally {
      Remove-Item -LiteralPath $same -Recurse -Force -ErrorAction SilentlyContinue
    }
  }
}
