# Windows junction traversal probe for the CLI.
#
# This is a manual release/security probe, not a normal CI gate. It exercises
# the real CLI through Windows directory junctions because MoonBit x/fs follows
# links and does not expose lstat/readlink-style APIs to the application.
#
# Expected current behavior on Windows:
# - create against a self-referential junction terminates with a safe IO error
#   and does not leave a manifest behind.
# - verify against a valid pack whose files/ directory contains a self-junction
#   terminates, keeps exit 0, and reports bounded W1001 unlisted-file warnings.

param(
  [ValidateSet("js", "native")]
  [string]$Target = "native"
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
  throw "node not found on PATH. Install Node.js or run -Target native instead."
}

function Invoke-Cli {
  param([string[]]$CliArgs)

  $oldErrorActionPreference = $ErrorActionPreference
  $ErrorActionPreference = "Continue"
  try {
    if ($Target -eq "js") {
      $output = & $script:node $script:artifact @CliArgs 2>&1 | Out-String
    } else {
      $output = & $script:artifact @CliArgs 2>&1 | Out-String
    }
    $exitCode = $LASTEXITCODE
  } finally {
    $ErrorActionPreference = $oldErrorActionPreference
  }

  [PSCustomObject]@{ ExitCode = $exitCode; Output = $output }
}

function New-Junction {
  param([string]$Link, [string]$TargetPath)

  $output = cmd /c mklink /J "$Link" "$TargetPath" 2>&1 | Out-String
  if ($LASTEXITCODE -ne 0) {
    throw "mklink /J failed: $output"
  }
}

function Remove-Junction {
  param([string]$Link)

  if (Test-Path -LiteralPath $Link) {
    cmd /c rmdir "$Link" | Out-Null
  }
}

$script:artifact = Find-CliArtifact -BuildTarget $Target
$script:node = if ($Target -eq "js") { Find-Node } else { $null }
Write-Host "artifact: $script:artifact"

$base = Join-Path $env:TEMP ("moon-evidence-junction-probe-" + [guid]::NewGuid().ToString("N"))
$cycleLink = $null
$verifyLink = $null
$failed = 0

try {
  New-Item -ItemType Directory -Path $base -Force | Out-Null

  # Probe 1: create must not hang or silently seal a self-junction cycle.
  $cycleDir = Join-Path $base "cycle-create"
  New-Item -ItemType Directory -Path $cycleDir -Force | Out-Null
  Set-Content -Path (Join-Path $cycleDir "payload.txt") -Value "junction-cycle-payload" -NoNewline -Encoding UTF8
  $cycleLink = Join-Path $cycleDir "loop"
  New-Junction -Link $cycleLink -TargetPath $cycleDir

  $create = Invoke-Cli -CliArgs @("create", $cycleDir, "--subject-id", "junction-cycle")
  $manifestPath = Join-Path $cycleDir "manifest.json"
  $createProblems = @()
  if ($create.ExitCode -ne 2) {
    $createProblems += "exit code: expected 2, got $($create.ExitCode)"
  }
  if ($create.Output -notmatch "E5002|file read failed|Failed to open directory") {
    $createProblems += "output missing safe IO failure marker"
  }
  if (Test-Path -LiteralPath $manifestPath) {
    $createProblems += "manifest should not be written after failed traversal"
  }
  if ($createProblems.Count -eq 0) {
    Write-Host "PASS  create: self-junction terminates with safe failure"
  } else {
    $failed += 1
    Write-Host "FAIL  create: self-junction"
    foreach ($problem in $createProblems) { Write-Host "      $problem" }
    Write-Host "      output: $($create.Output.Trim())"
  }

  Remove-Junction -Link $cycleLink
  $cycleLink = $null

  # Probe 2: verify must terminate when files/ contains a self-junction.
  $packDir = Join-Path $base "valid-pack"
  Copy-Item -Path (Join-Path $repoRoot "examples/valid-pack") -Destination $packDir -Recurse
  $filesDir = Join-Path $packDir "files"
  $verifyLink = Join-Path $filesDir "loop"
  New-Junction -Link $verifyLink -TargetPath $filesDir

  $verify = Invoke-Cli -CliArgs @("verify", $packDir)
  $warningCount = ([regex]::Matches($verify.Output, "\[W1001\]")).Count
  $verifyProblems = @()
  if ($verify.ExitCode -ne 0) {
    $verifyProblems += "exit code: expected 0, got $($verify.ExitCode)"
  }
  if ($verify.Output -notmatch "verification OK") {
    $verifyProblems += "output missing verification OK"
  }
  if ($warningCount -le 0) {
    $verifyProblems += "expected at least one bounded W1001 warning from the junction cycle"
  }
  if ($warningCount -gt 10000) {
    $verifyProblems += "warning count exceeded max_pack_files bound: $warningCount"
  }
  if ($verifyProblems.Count -eq 0) {
    Write-Host "PASS  verify: files self-junction terminates ($warningCount W1001 warnings)"
  } else {
    $failed += 1
    Write-Host "FAIL  verify: files self-junction"
    foreach ($problem in $verifyProblems) { Write-Host "      $problem" }
    Write-Host "      output: $($verify.Output.Trim())"
  }
} finally {
  if ($verifyLink) { Remove-Junction -Link $verifyLink }
  if ($cycleLink) { Remove-Junction -Link $cycleLink }
  if (Test-Path -LiteralPath $base) {
    Remove-Item -LiteralPath $base -Recurse -Force -ErrorAction SilentlyContinue
  }
}

Write-Host ""
if ($failed -gt 0) {
  Write-Host "symlink-junction-probe ($Target): failed"
  exit 1
}

Write-Host "symlink-junction-probe ($Target): passed"
exit 0
