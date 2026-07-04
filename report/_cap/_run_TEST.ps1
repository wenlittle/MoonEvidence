. "$PSScriptRoot\_termsetup.ps1"
Set-Location (Split-Path (Split-Path $PSScriptRoot))
Init-Term -Cols 88 -Rows 14 -FontPx 16 -Title 'MEV-TEST'
Clear-Host
Prompt-Line 'moon test --target wasm-gc,js'
moon test --target wasm-gc,js
Write-Host ''
Start-Sleep -Seconds 300
