# Run Pester tests. Requires: Install-Module Pester -Scope CurrentUser -Force (5+)
$ErrorActionPreference = 'Stop'
$TestDir = $PSScriptRoot
$RepoRoot = Split-Path -Parent $TestDir
Set-Location $RepoRoot
if (-not (Get-Module -ListAvailable -Name Pester | Where-Object Version -GE ([version]'5.0.0'))) {
  Write-Error 'Install Pester 5+: Install-Module Pester -Scope CurrentUser -MinimumVersion 5.0.0 -Force'
}
Import-Module Pester
Invoke-Pester -Path (Join-Path $TestDir 'pester') -Output Detailed
