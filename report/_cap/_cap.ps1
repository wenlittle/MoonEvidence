param(
  [Parameter(Mandatory=$true)][string]$Kind,
  [Parameter(Mandatory=$true)][string]$Out,
  [int]$Wait = 16
)
$run = Join-Path $PSScriptRoot "_run_$Kind.ps1"
$capwin = Join-Path $PSScriptRoot "_capwin.ps1"
$psargs = "-NoProfile -ExecutionPolicy Bypass -File `"$run`""
$p = Start-Process -FilePath powershell.exe -ArgumentList $psargs -PassThru
Write-Output "launched powershell pid=$($p.Id), waiting $Wait s for '$Kind' to render..."
Start-Sleep -Seconds $Wait
& $capwin -Title ("MEV-" + $Kind) -Out $Out
Stop-Process -Id $p.Id -Force -ErrorAction SilentlyContinue
Get-Process -Name powershell -ErrorAction SilentlyContinue |
  Where-Object { $_.MainWindowTitle -like "*MEV-$Kind*" } |
  Stop-Process -Force -ErrorAction SilentlyContinue
