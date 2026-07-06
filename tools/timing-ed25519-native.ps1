param(
  [ValidateSet("verify", "sign-message", "sign-secret", "both")]
  [string]$Target = "both",
  [int]$Samples = 10000,
  [int]$Warmup = 512,
  [ValidateSet("debug", "release")]
  [string]$Config = "release",
  [string]$VcVars = "D:\software\VStudio2022\VC\Auxiliary\Build\vcvars64.bat"
)

$ErrorActionPreference = "Stop"

if ($Samples -lt 2 -or ($Samples % 2) -ne 0) {
  throw "Samples must be an even integer >= 2"
}
if ($Warmup -lt 0) {
  throw "Warmup must be non-negative"
}
if (-not (Test-Path -LiteralPath $VcVars)) {
  throw "vcvars64.bat not found: $VcVars"
}

$releaseFlag = if ($Config -eq "release") { "--release" } else { "" }
$exe = Join-Path (Get-Location) "_build\native\$Config\build\src\timing\timing.exe"

$commands = "call `"$VcVars`" >nul && moon version && where cl && moon build --target native $releaseFlag src/timing && `"$exe`" --target $Target --samples $Samples --warmup $Warmup"

Write-Host "timing_runner: tools/timing-ed25519-native.ps1"
Write-Host "timing_config: target=$Target samples=$Samples warmup=$Warmup config=$Config"
Write-Host "timing_vcvars: $VcVars"
Write-Host "timing_build_command: moon build --target native $releaseFlag src/timing"
Write-Host "timing_run_command: `"$exe`" --target $Target --samples $Samples --warmup $Warmup"

cmd /v:on /d /s /c $commands
if ($LASTEXITCODE -ne 0) {
  exit $LASTEXITCODE
}
