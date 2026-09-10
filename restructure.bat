@echo off
setlocal enabledelayedexpansion
REM ============================================================================
REM  Path of Embers - repository flatten / restructure
REM
REM  Dissolves the redundant "Path-of-Embers\" folder inside the Godot project
REM  so its children (autoload, core, data, scenes, systems, art, audio, fonts,
REM  .claude, docs) sit directly at the project root, and rewrites every
REM  res://Path-of-Embers/... reference accordingly.
REM
REM  Safe to double-click. Refuses to run (and changes nothing) unless it is
REM  sitting next to project.godot AND a Path-of-Embers\ folder exists next to
REM  it. Re-running after a successful pass is therefore a safe no-op.
REM ============================================================================

echo ============================================================
echo  Path of Embers - repository flatten / restructure
echo ============================================================
echo.

if not exist "%~dp0project.godot" (
    echo ERROR: project.godot was not found next to this script.
    echo This script must sit directly in the Godot project root.
    echo Nothing was changed. Aborting.
    echo.
    pause
    exit /b 1
)

if not exist "%~dp0Path-of-Embers\" (
    echo No Path-of-Embers\ folder was found next to project.godot.
    echo Either the restructure has already been done, or this script
    echo is in the wrong place.
    echo Nothing to do - this is a safe no-op, not an error.
    echo.
    pause
    exit /b 0
)

cd /d "%~dp0"

REM Ordering guard. poe_update.tgz holds the latest code at the OLD paths, so it
REM must be unpacked BEFORE the restructure rewrites those paths -- and step 6
REM of this script deletes it as a leftover, so running this first would throw
REM the update away.
REM
REM Test whether the update actually LANDED, not whether the tarball is still
REM lying around: apply_update.bat unpacks but does not delete itself or the
REM tarball, so "the file exists" was a false alarm and blocked a correctly
REM updated repo. OWNER_ACCENT_COLORS only exists in the post-update CardWidget.
set "UPDATE_APPLIED=0"
if exist "%~dp0Path-of-Embers\core\ui\CardWidget.gd" (
    findstr /C:"OWNER_ACCENT_COLORS" "%~dp0Path-of-Embers\core\ui\CardWidget.gd" >nul 2>nul
    if not errorlevel 1 set "UPDATE_APPLIED=1"
)
if exist "%~dp0poe_update.tgz" (
    if "%UPDATE_APPLIED%"=="0" (
        echo ERROR: poe_update.tgz has not been unpacked yet.
        echo.
        echo Run apply_update.bat FIRST, then run this script. Otherwise the
        echo update would be deleted without ever landing.
        echo Nothing was changed. Aborting.
        echo.
        pause
        exit /b 1
    )
    echo Update already applied - poe_update.tgz will be cleaned up as a leftover.
)


echo This will run IN PLACE, in:
echo   %cd%
echo.
echo It will:
echo   1. Move Path-of-Embers\autoload, core, data, scenes, systems to the project root
echo   2. Move Path-of-Embers\Art Assets\ to art\, and Path-of-Embers\Audio\ to audio\
echo   3. Move Path-of-Embers\fonts to fonts\
echo   4. Move/merge Path-of-Embers\.claude into a root .claude\
echo   5. Move Path-of-Embers\GameDesign.md and other root docs into docs\
echo   6. Delete a short list of superseded docs and transfer leftovers
echo   7. Rewrite every res://Path-of-Embers/... reference in .gd/.tres/.tscn/.import/.cfg/project.godot
echo   8. Delete the .godot\ import cache (Godot regenerates it on next open)
echo.
echo IMPORTANT: commit or stash your current git working tree FIRST, so you
echo can inspect this change with "git status" / "git diff" and revert with
echo git if anything looks wrong. This script does not do that for you.
echo.
choice /M "Have you committed your working tree, and do you want to proceed"
if errorlevel 255 (
    echo.
    echo Could not read a response. Aborting without changes.
    exit /b 1
)
if errorlevel 2 (
    echo.
    echo Aborted by user. Nothing was changed.
    exit /b 0
)

REM Deliberately NOT using "git mv" / "git rm". Git detects renames by content
REM similarity when you commit, so history follows the files either way -- and
REM "git mv" fails outright on a directory containing untracked files, which the
REM art folder is full of (untracked .import sidecars). Plain move/del cannot
REM hit that failure. Run "git add -A" afterwards and git will record the moves.

echo.
echo --- Step 1/8: moving code folders to project root ---
call :MOVEDIR "Path-of-Embers\autoload" "autoload"
call :MOVEDIR "Path-of-Embers\core" "core"
call :MOVEDIR "Path-of-Embers\data" "data"
call :MOVEDIR "Path-of-Embers\scenes" "scenes"
call :MOVEDIR "Path-of-Embers\systems" "systems"

echo --- Step 2/8: moving art and audio ---
call :MOVEDIR "Path-of-Embers\Art Assets" "art"
call :MOVEDIR "Path-of-Embers\Audio" "audio"

echo --- Step 3/8: moving fonts ---
call :MOVEDIR "Path-of-Embers\fonts" "fonts"

echo --- Step 4/8: merging .claude ---
if exist "Path-of-Embers\.claude\" (
    if exist ".claude\" (
        echo   root .claude\ already exists - copying files in from Path-of-Embers\.claude\ ...
        xcopy /E /I /Y "Path-of-Embers\.claude" ".claude\" >nul
        call :RMDIR "Path-of-Embers\.claude"
    ) else (
        call :MOVEDIR "Path-of-Embers\.claude" ".claude"
    )
)

echo --- Step 5/8: moving docs into docs\ ---
if not exist "docs\" mkdir "docs"
call :MOVEFILE "Path-of-Embers\GameDesign.md" "docs\GameDesign.md"
call :MOVEFILE "ART_ASSET_REQUESTS_FOR_IMAGE_TOOL.md" "docs\ART_ASSET_REQUESTS_FOR_IMAGE_TOOL.md"
call :MOVEFILE "ART_ASSET_REQUESTS_NOTES.md" "docs\ART_ASSET_REQUESTS_NOTES.md"
call :MOVEFILE "SMOKE_TEST.md" "docs\SMOKE_TEST.md"

echo --- Step 6/8: deleting superseded docs and transfer leftovers ---
call :DELFILE "code_snap.tgz"
call :DELFILE "code_sync.tgz"
call :DELFILE "_to_delete_blockouts.tgz"
call :DELFILE "err.txt"
call :DELFILE "poe_update.tgz"
call :DELFILE "apply_update.bat"
call :DELFILE "REFACTORING_SUMMARY.md"
call :DELFILE "INSTANCE_ID_REFACTOR_SUMMARY.md"
call :DELFILE "REWARD_IMPLEMENTATION_REPORT.md"
call :DELFILE "DEVELOPMENT_PLAN.md"
call :DELFILE "Path-of-Embers\Path-of-Embers-Review.md"
call :DELFILE "Path-of-Embers\.gitattributes"
call :RMDIR "Path-of-Embers\Scripts"
REM Matched by wildcard rather than a literal dash character, because the
REM real filenames use an em-dash (Path of Embers [em-dash] Master Design
REM Document...) which is unreliable to embed literally in a .bat file's
REM console code page. These are duplicate design-doc exports, not
REM referenced by anything else in the project.
for %%F in ("Path of Embers*Master Design Document.html") do call :DELFILE "%%~F"
for %%F in ("Path of Embers*Master Design Document.txt") do call :DELFILE "%%~F"
for /d %%F in ("Path of Embers*Master Design Document_files") do call :RMDIR "%%~F"
call :DELFILE "path-of-embers-GDD (1).html"
call :DELFILE "path-of-embers-GDD (1).txt"

if exist "Path-of-Embers\" (
    dir /b "Path-of-Embers\" 2>nul | findstr "^" >nul
    if errorlevel 1 (
        rmdir "Path-of-Embers"
        echo   removed now-empty Path-of-Embers\ folder
    ) else (
        echo   NOTE: Path-of-Embers\ still has files left in it - check it by hand:
        dir /b "Path-of-Embers\"
    )
)

echo --- Step 7/8: rewriting res://Path-of-Embers/ references in text files ---
set "PS1=%TEMP%\poe_restructure_rewrite.ps1"
if exist "%PS1%" del /f /q "%PS1%" >nul 2>nul

echo $root = (Get-Location).Path>"%PS1%"
echo $extensions = @('.gd','.tres','.tscn','.import','.cfg')>>"%PS1%"
echo $replacements = [ordered]@{}>>"%PS1%"
echo $replacements['Path-of-Embers/Art Assets/'] = 'art/'>>"%PS1%"
echo $replacements['Path-of-Embers/Audio/'] = 'audio/'>>"%PS1%"
echo $replacements['Path-of-Embers/GameDesign.md'] = 'docs/GameDesign.md'>>"%PS1%"
echo $replacements['Path-of-Embers/'] = ''>>"%PS1%"
echo $allFiles = Get-ChildItem -Path $root -Recurse -File -ErrorAction SilentlyContinue>>"%PS1%"
echo $changed = 0>>"%PS1%"
echo foreach ($f in $allFiles) {>>"%PS1%"
echo     if ($f.FullName.Contains('\.godot\')) { continue }>>"%PS1%"
echo     if ($f.FullName.Contains('\.git\')) { continue }>>"%PS1%"
echo     $ext = $f.Extension.ToLower()>>"%PS1%"
echo     $isTarget = $false>>"%PS1%"
echo     foreach ($e in $extensions) { if ($ext -eq $e) { $isTarget = $true } }>>"%PS1%"
echo     if ($f.Name -eq 'project.godot') { $isTarget = $true }>>"%PS1%"
echo     if (-not $isTarget) { continue }>>"%PS1%"
echo     $bytes = [System.IO.File]::ReadAllBytes($f.FullName)>>"%PS1%"
echo     $text = [System.Text.Encoding]::UTF8.GetString($bytes)>>"%PS1%"
echo     if (-not $text.Contains('Path-of-Embers')) { continue }>>"%PS1%"
echo     $orig = $text>>"%PS1%"
echo     foreach ($k in $replacements.Keys) { $text = $text.Replace($k, $replacements[$k]) }>>"%PS1%"
echo     if ($text -ne $orig) {>>"%PS1%"
echo         $utf8NoBom = New-Object System.Text.UTF8Encoding($false)>>"%PS1%"
echo         [System.IO.File]::WriteAllText($f.FullName, $text, $utf8NoBom)>>"%PS1%"
echo         $changed = $changed + 1>>"%PS1%"
echo         Write-Host ('  rewrote: ' + $f.FullName)>>"%PS1%"
echo     }>>"%PS1%"
echo }>>"%PS1%"
echo Write-Host ('Rewrote ' + $changed + ' files.')>>"%PS1%"
echo $checkExt = @('.gd','.tres','.tscn','.import','.cfg','.md','.json','.txt')>>"%PS1%"
echo $stillBad = 0>>"%PS1%"
echo foreach ($f in $allFiles) {>>"%PS1%"
echo     if ($f.FullName.Contains('\.godot\')) { continue }>>"%PS1%"
echo     if ($f.FullName.Contains('\.git\')) { continue }>>"%PS1%"
echo     $ext2 = $f.Extension.ToLower()>>"%PS1%"
echo     $probablyText = $false>>"%PS1%"
echo     foreach ($e in $checkExt) { if ($ext2 -eq $e) { $probablyText = $true } }>>"%PS1%"
echo     if ($f.Name -eq 'project.godot') { $probablyText = $true }>>"%PS1%"
echo     if (-not $probablyText) { continue }>>"%PS1%"
echo     $bytes2 = [System.IO.File]::ReadAllBytes($f.FullName)>>"%PS1%"
echo     $text2 = [System.Text.Encoding]::UTF8.GetString($bytes2)>>"%PS1%"
echo     if ($text2.Contains('Path-of-Embers') -or $text2.Contains('Art%%20Assets')) {>>"%PS1%"
echo         Write-Host ('WARNING still contains an old path fragment: ' + $f.FullName)>>"%PS1%"
echo         $stillBad = $stillBad + 1>>"%PS1%"
echo     }>>"%PS1%"
echo }>>"%PS1%"
echo if ($stillBad -eq 0) { Write-Host 'No remaining Path-of-Embers / Art%%20Assets occurrences in scanned text files.' }>>"%PS1%"

powershell -NoProfile -ExecutionPolicy Bypass -File "%PS1%"
set "PS_EXIT=%errorlevel%"
del /f /q "%PS1%" >nul 2>nul
if not "%PS_EXIT%"=="0" (
    echo.
    echo WARNING: the PowerShell rewrite step reported an error (exit code %PS_EXIT%^).
    echo Review the output above before opening the project in Godot.
)

echo --- Step 8/8: deleting .godot\ import cache ---
call :RMDIR ".godot"

echo.
echo ============================================================
echo Done. Next steps:
echo   1. Open the project in Godot 4.5 and let it fully re-import
echo      (this can take a minute - it is regenerating .godot\)
echo   2. Check the Output panel for script/parse errors
echo   3. If you use git: "git add -A" then review "git status" and commit.
echo      Git records the moves as renames once the files are staged.
echo ============================================================
pause
exit /b 0

REM ---------------------------------------------------------------------------
REM  Helper subroutines
REM ---------------------------------------------------------------------------

:MOVEDIR
REM %~1 = source dir, %~2 = dest dir (args are passed quoted; %~1/%~2 strip the quotes)
if not exist "%~1\" (
    exit /b 0
)
if exist "%~2\" (
    echo   SKIP: "%~2\" already exists - not overwriting. Merge "%~1\" into it by hand.
    exit /b 0
)
move "%~1" "%~2" >nul
if errorlevel 1 (
    echo   ERROR: failed to move "%~1\" to "%~2\" - stopping so you can look.
    pause
    exit 1
)
echo   moved "%~1\" -^> "%~2\"
exit /b 0

:MOVEFILE
REM %~1 = source file, %~2 = dest file
if not exist "%~1" (
    exit /b 0
)
if exist "%~2" (
    echo   SKIP: "%~2" already exists - not overwriting "%~1"
    exit /b 0
)
move "%~1" "%~2" >nul
if errorlevel 1 (
    echo   ERROR: failed to move "%~1" to "%~2" - stopping so you can look.
    pause
    exit 1
)
echo   moved "%~1" -^> "%~2"
exit /b 0

:DELFILE
REM %~1 = file to delete
if not exist "%~1" (
    exit /b 0
)
del /f /q "%~1"
echo   deleted "%~1"
exit /b 0

:RMDIR
REM %~1 = directory to delete
if not exist "%~1\" (
    exit /b 0
)
rmdir /s /q "%~1"
echo   deleted "%~1\"
exit /b 0
