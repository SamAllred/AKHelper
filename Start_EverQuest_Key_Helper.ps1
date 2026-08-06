$ErrorActionPreference = "Stop"
$workingDirectory = $PSScriptRoot
$ahkScriptPath = Join-Path $workingDirectory "EverQuest_Key_Helper.ahk"
$autoHotkeyCandidates = @(
    "$env:ProgramFiles\AutoHotkey\v2\AutoHotkey64.exe",
    "$env:ProgramFiles\AutoHotkey\AutoHotkey64.exe",
    "$env:LOCALAPPDATA\Programs\AutoHotkey\v2\AutoHotkey64.exe",
    "$env:LOCALAPPDATA\Programs\AutoHotkey\AutoHotkey64.exe"
)
$autoHotkeyPath = $autoHotkeyCandidates |
    Where-Object { Test-Path -LiteralPath $_ } |
    Select-Object -First 1

if (-not $autoHotkeyPath) {
    throw "AutoHotkey v2 was not found. Run the AKHelper installer first."
}

Start-Process -FilePath $autoHotkeyPath `
    -ArgumentList ('"' + $ahkScriptPath + '"') `
    -WorkingDirectory $workingDirectory `
    -WindowStyle Hidden
