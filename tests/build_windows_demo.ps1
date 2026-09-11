param(
    [Parameter(Mandatory=$true)][string]$Godot,
    [Parameter(Mandatory=$true)][string]$TemplateDirectory,
    [string]$BuildId = ('candidate-' + (Get-Date -Format 'yyyyMMdd-HHmmss'))
)
$ErrorActionPreference = 'Stop'
if ($BuildId -notmatch '^[a-zA-Z0-9_-]+$') { throw 'BuildId must be a simple directory name' }
$projectRoot = Split-Path $PSScriptRoot -Parent
$buildRoot = Join-Path $projectRoot "builds/$BuildId"
if (Test-Path -LiteralPath $buildRoot) { throw 'Use a new BuildId; existing candidates are retained' }
$package = Join-Path $buildRoot 'Path of Embers'
$profile = Join-Path $buildRoot 'build-profile'
$templateTarget = Join-Path $profile 'Godot/export_templates/4.5.1.stable'
[IO.Directory]::CreateDirectory($package) | Out-Null
[IO.Directory]::CreateDirectory($templateTarget) | Out-Null
foreach ($name in @('windows_release_x86_64.exe', 'windows_debug_x86_64.exe', 'version.txt')) {
    Copy-Item -LiteralPath (Join-Path $TemplateDirectory $name) -Destination $templateTarget
}
$previousAppData = $env:APPDATA
$previousLocalAppData = $env:LOCALAPPDATA
try {
    $env:APPDATA = $profile
    $env:LOCALAPPDATA = $profile
    if ((& $Godot --version) -notmatch '^4\.5\.1\.') { throw 'Godot 4.5.1 is required' }
    $exportLog = Join-Path $buildRoot 'export.log'
    & $Godot --headless --path $projectRoot --editor --export-release 'Windows Friends Demo' (Join-Path $package 'Path of Embers.exe') *> $exportLog
    if ($LASTEXITCODE -ne 0 -or (Select-String -Path $exportLog -Pattern 'ERROR|Failed|res://(tests|assessment|addons|\.claude|\.cursor|builds)/' -Quiet)) {
        throw "Export or exclusion check failed; inspect $exportLog"
    }
    Copy-Item -LiteralPath (Join-Path $projectRoot 'docs/FRIENDS_README.md') -Destination (Join-Path $package 'README.md')
    & $Godot --headless --path $projectRoot --script res://tests/export_notices.gd -- (Join-Path $package 'GODOT-NOTICES.txt') *> (Join-Path $buildRoot 'notices.log')
    if ($LASTEXITCODE -ne 0 -or -not (Test-Path (Join-Path $package 'GODOT-NOTICES.txt'))) { throw 'Engine notices generation failed' }
    foreach ($font in @('Cinzel','Noto_Sans')) {
        Copy-Item -LiteralPath (Join-Path $projectRoot "fonts/$font/OFL.txt") -Destination (Join-Path $package "$font-LICENSE.txt")
    }
    $zipPath = Join-Path $buildRoot "Path-of-Embers-$BuildId.zip"
    Compress-Archive -LiteralPath $package -DestinationPath $zipPath
    $extracted = Join-Path $buildRoot 'extracted'
    Expand-Archive -LiteralPath $zipPath -DestinationPath $extracted
    $extractedPackage = Join-Path $extracted 'Path of Embers'
    foreach ($name in @('Path of Embers.exe','Path of Embers.pck','README.md')) {
        if ((Get-FileHash -LiteralPath (Join-Path $package $name)).Hash -ne (Get-FileHash -LiteralPath (Join-Path $extractedPackage $name)).Hash) {
            throw "Extracted file mismatch: $name"
        }
    }
    $env:APPDATA = Join-Path $buildRoot 'fresh-player-profile'
    $env:LOCALAPPDATA = $env:APPDATA
    [IO.Directory]::CreateDirectory($env:APPDATA) | Out-Null
    $smokeLog = Join-Path $buildRoot 'extracted-smoke.log'
    $launchArgs = '--headless --quit-after 120 --debug-mode --log-file "' + $smokeLog + '"'
    $process = Start-Process -FilePath (Join-Path $extractedPackage 'Path of Embers.exe') -WorkingDirectory $extractedPackage -ArgumentList $launchArgs -WindowStyle Hidden -PassThru -Wait
    $expected = 'DataRegistry: Loaded 31 cards, 9 enemies, 12 characters, 18 upgrades, 20 equipment, 3 milestones, 5 encounters, 6 abilities'
    # Known shutdown-only resource leaks are recorded, not confused with a
    # startup/content failure. Every other error remains a hard failure.
    $runtimeErrors = Get-Content -LiteralPath $smokeLog | Where-Object { $_ -match 'ERROR|DebugMode: ENABLED' -and $_ -notmatch '^ERROR: \d+ resources still in use at exit' }
    if ($process.ExitCode -ne 0 -or -not (Select-String -Path $smokeLog -SimpleMatch $expected -Quiet) -or $runtimeErrors) {
        throw "Extracted release startup failed; inspect $smokeLog"
    }
    Get-FileHash -LiteralPath $zipPath | Format-List | Out-File (Join-Path $buildRoot 'SHA256.txt')
    Write-Output "Candidate: $zipPath"
    Write-Output 'Extraction, fresh-profile startup, registry counts, and release debug-mode guard passed. Full-run and interactive acceptance checks remain required.'
} finally {
    $env:APPDATA = $previousAppData
    $env:LOCALAPPDATA = $previousLocalAppData
}
