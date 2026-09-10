param(
    [Parameter(Mandatory=$true)][string]$Godot,
    [string]$OutputDirectory = (Join-Path $env:TEMP 'poe-release-verification')
)
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path $PSScriptRoot -Parent
$output = [IO.Path]::GetFullPath($OutputDirectory)
[IO.Directory]::CreateDirectory($output) | Out-Null
$profile = Join-Path $output ('profile-' + [guid]::NewGuid().ToString('N'))
[IO.Directory]::CreateDirectory($profile) | Out-Null
$previousAppData = $env:APPDATA
$previousLocalAppData = $env:LOCALAPPDATA
try {
    $env:APPDATA = $profile
    $env:LOCALAPPDATA = $profile
    $version = & $Godot --version
    if ($version -notmatch '^4\.5\.1\.') { throw "Expected Godot 4.5.1, got $version" }
    & $Godot --headless --path $projectRoot --editor --quit *> (Join-Path $output 'editor.log')
    if ($LASTEXITCODE -ne 0) { throw 'Editor failed' }
    if (Select-String -Path (Join-Path $output 'editor.log') -Pattern 'ERROR|Failed|not declared|does not exist' -Quiet) { throw 'Editor log contains errors' }
    $expected = [ordered]@{card_clock=94; signature_cards=49; card_preview=38; hex_playability=19; party_hud_stats=10; card_art=38; backpack=23; release_blockers=71}
    foreach ($suite in $expected.Keys) {
        $log = Join-Path $output "$suite.log"
        & $Godot --headless --path $projectRoot --quit-after 4000 "res://tests/$suite.tscn" -- --no-debug *> $log
        $summary = "--- ${suite} summary: $($expected[$suite]) passed, 0 failed ---"
        if ($LASTEXITCODE -ne 0 -or -not (Select-String -Path $log -SimpleMatch $summary -Quiet)) { throw "$suite failed or assertion count changed" }
        if (Select-String -Path $log -Pattern 'SCRIPT ERROR|Parse Error|Failed to load|does not exist|FAIL:' -Quiet) { throw "$suite contains runtime errors" }
        Write-Output $summary
    }
    & $Godot --headless --path $projectRoot res://tests/sim.tscn -- --party=warrior_1,warrior_2,golemancer --enemies=boss_act1:1 --act=1 --n=30 --policy=timed "--json=$output/sim.json" --no-debug *> (Join-Path $output 'sim.log')
    if ($LASTEXITCODE -ne 0) { throw 'Simulator failed' }
    Write-Output "Verified. Logs: $output. Profile retained for inspection: $profile"
    Write-Output 'Known limitation: some harnesses still report ObjectDB/resource cleanup leaks at exit.'
} finally {
    $env:APPDATA = $previousAppData
    $env:LOCALAPPDATA = $previousLocalAppData
}
