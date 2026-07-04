. "$PSScriptRoot\_termsetup.ps1"
# repo root = two levels up from report\_cap
Set-Location (Split-Path (Split-Path $PSScriptRoot))
$env:NODE_NO_WARNINGS = "1"
Init-Term -Cols 90 -Rows 18 -FontPx 16 -Title 'MEV-CLI'
Clear-Host
$cli = "_build/js/debug/build/src/cmd/main/main.js"
Prompt-Line 'node $cli verify examples/valid-pack'
node $cli verify examples/valid-pack
Prompt-Line 'node $cli explain examples/tampered-pack'
node $cli explain examples/tampered-pack
Write-Host ''
Start-Sleep -Seconds 300
