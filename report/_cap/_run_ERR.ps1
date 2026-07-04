. "$PSScriptRoot\_termsetup.ps1"
Set-Location (Split-Path (Split-Path $PSScriptRoot))
$env:NODE_NO_WARNINGS = "1"
Init-Term -Cols 104 -Rows 24 -FontPx 16 -Title 'MEV-ERR'
Clear-Host
$cli = "_build/js/debug/build/src/cmd/main/main.js"
Prompt-Line 'node $cli explain tests/fixtures/packs/bad-merkle-root'
node $cli explain tests/fixtures/packs/bad-merkle-root
Prompt-Line 'node $cli explain tests/fixtures/packs/chain-broken'
node $cli explain tests/fixtures/packs/chain-broken
Prompt-Line 'node $cli explain tests/fixtures/packs/chain-fork'
node $cli explain tests/fixtures/packs/chain-fork
Prompt-Line 'node $cli explain tests/fixtures/packs/unlisted-file'
node $cli explain tests/fixtures/packs/unlisted-file
Write-Host ''
Start-Sleep -Seconds 300
