# Black-box CLI tests (master plan step 6 task 3).
#
# Runs the moon-evidence CLI against the bundled example packs and asserts
# the frozen contract: exit codes (0 pass / 1 fail / 2 usage-or-IO) plus key
# output lines for every command shape.
#
# Usage:
#   ./tools/cli-test.ps1                 # test the js artifact via node
#   ./tools/cli-test.ps1 -Target native  # test the native executable
#
# The script only tests; build the artifact first:
#   moon build --target js     (or native)

param(
  [ValidateSet("js", "native")]
  [string]$Target = "js"
)

$ErrorActionPreference = "Stop"
$repoRoot = Split-Path -Parent $PSScriptRoot
Set-Location $repoRoot

function Find-CliArtifact {
  param([string]$BuildTarget)

  $buildRoot = Join-Path $repoRoot "_build/$BuildTarget"
  if (-not (Test-Path $buildRoot)) {
    throw "Build directory '$buildRoot' not found. Run: moon build --target $BuildTarget"
  }
  $names = if ($BuildTarget -eq "js") { @("main.js") } else { @("main.exe", "main") }
  $candidates = Get-ChildItem $buildRoot -Recurse -File |
    Where-Object { $names -contains $_.Name -and $_.FullName -match "src[\\/]cmd[\\/]main" } |
    Sort-Object FullName
  if (@($candidates).Count -eq 0) {
    throw "CLI artifact not found under '$buildRoot'. Run: moon build --target $BuildTarget"
  }
  $release = $candidates | Where-Object { $_.FullName -match "[\\/]release[\\/]" } | Select-Object -First 1
  if ($release) { return $release.FullName }
  return $candidates[0].FullName
}

function Find-Node {
  $fromPath = Get-Command node -ErrorAction SilentlyContinue
  if ($fromPath) { return $fromPath.Source }
  # Local fallback documented in docs/ENVIRONMENT.md.
  $known = "D:\Programming_Language\Node\node.exe"
  if (Test-Path $known) { return $known }
  throw "node not found on PATH. Install Node.js or test -Target native instead."
}

$artifact = Find-CliArtifact -BuildTarget $Target
$node = if ($Target -eq "js") { Find-Node } else { $null }
Write-Host "artifact: $artifact"

function Invoke-Cli {
  param([string[]]$CliArgs)

  # The CLI prints everything assertable to stdout; stderr is dropped so
  # PowerShell 5.1 NativeCommandError noise cannot pollute assertions.
  if ($Target -eq "js") {
    $output = & $node $artifact @CliArgs 2>$null | Out-String
  } else {
    $output = & $artifact @CliArgs 2>$null | Out-String
  }
  [PSCustomObject]@{ ExitCode = $LASTEXITCODE; Output = $output }
}

$cases = @(
  @{ Name = "version flag";           CliArgs = @("--version");                                   Exit = 0; MustMatch = @("moon-evidence \d+\.\d+\.\d+") }
  @{ Name = "help flag";              CliArgs = @("--help");                                      Exit = 0; MustMatch = @("Usage:") }
  @{ Name = "verify valid pack dir";  CliArgs = @("verify", "examples/valid-pack");               Exit = 0; MustMatch = @("verification OK", "merkle root verified") }
  @{ Name = "verify valid manifest";  CliArgs = @("verify", "examples/valid-pack/manifest.json"); Exit = 0; MustMatch = @("verification OK") }
  @{ Name = "verify valid json";      CliArgs = @("verify", "--json", "examples/valid-pack");     Exit = 0; MustMatch = @('"ok":true') }
  @{ Name = "verify tampered pack";   CliArgs = @("verify", "examples/tampered-pack");            Exit = 1; MustMatch = @("verification FAILED", "\[E2003\] files/a\.txt") }
  @{ Name = "verify tampered json";   CliArgs = @("verify", "--json", "examples/tampered-pack");  Exit = 1; MustMatch = @('"ok":false', "E2003") }
  @{ Name = "explain tampered pack";  CliArgs = @("explain", "examples/tampered-pack");           Exit = 1; MustMatch = @("\[E2003\]") }
  @{ Name = "missing path";           CliArgs = @("verify", "examples/no-such-pack");             Exit = 2; MustMatch = @("\[E5001\]") }
  @{ Name = "verify without path";    CliArgs = @("verify");                                      Exit = 2; MustMatch = @("Usage:") }
  @{ Name = "unknown command";        CliArgs = @("frobnicate");                                  Exit = 2; MustMatch = @("Usage:") }
  @{ Name = "explain rejects --json"; CliArgs = @("explain", "--json", "examples/valid-pack");    Exit = 2; MustMatch = @("Usage:") }
)

$failed = 0
foreach ($case in $cases) {
  $result = Invoke-Cli -CliArgs $case.CliArgs
  $problems = @()
  if ($result.ExitCode -ne $case.Exit) {
    $problems += "exit code: expected $($case.Exit), got $($result.ExitCode)"
  }
  foreach ($pattern in $case.MustMatch) {
    if ($result.Output -notmatch $pattern) {
      $problems += "output missing pattern: $pattern"
    }
  }
  if ($problems.Count -eq 0) {
    Write-Host "PASS  $($case.Name)"
  } else {
    $failed += 1
    Write-Host "FAIL  $($case.Name)"
    foreach ($problem in $problems) { Write-Host "      $problem" }
    Write-Host "      args:   $($case.CliArgs -join ' ')"
    Write-Host "      output: $($result.Output.Trim())"
  }
}

Write-Host ""
Write-Host "cli-test ($Target): $(@($cases).Count - $failed)/$(@($cases).Count) passed"
if ($failed -gt 0) { exit 1 }
exit 0
