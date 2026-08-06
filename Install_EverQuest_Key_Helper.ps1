$ErrorActionPreference = "Stop"

$installRoot = Join-Path $env:USERPROFILE "Documents\AKHelper"
$legacyInstallRoot = Join-Path $env:USERPROFILE "Documents\EverQuest Key Helper"
$ahkScriptPath = Join-Path $installRoot "EverQuest_Key_Helper.ahk"
$updaterScriptPath = Join-Path $installRoot "Update_EverQuest_Key_Helper.ps1"
$startScriptPath = Join-Path $installRoot "Start_EverQuest_Key_Helper.ps1"
$stopScriptPath = Join-Path $installRoot "Stop_EverQuest_Key_Helper.ps1"
$desktopShortcutPath = Join-Path ([Environment]::GetFolderPath("Desktop")) "Start AKHelper.lnk"
$desktopStopShortcutPath = Join-Path ([Environment]::GetFolderPath("Desktop")) "Stop AKHelper.lnk"

function Write-Step {
    param([string]$Message)
    Write-Host ""
    Write-Host "==> $Message" -ForegroundColor Cyan
}

function Find-AutoHotkey {
    $candidates = @(
        "$env:ProgramFiles\AutoHotkey\v2\AutoHotkey64.exe",
        "$env:ProgramFiles\AutoHotkey\AutoHotkey64.exe",
        "$env:LOCALAPPDATA\Programs\AutoHotkey\v2\AutoHotkey64.exe",
        "$env:LOCALAPPDATA\Programs\AutoHotkey\AutoHotkey64.exe"
    )

    foreach ($candidate in $candidates) {
        if (Test-Path -LiteralPath $candidate) {
            return $candidate
        }
    }

    $command = Get-Command "AutoHotkey64.exe" -ErrorAction SilentlyContinue
    if ($command) {
        return $command.Source
    }

    $command = Get-Command "AutoHotkey.exe" -ErrorAction SilentlyContinue
    if ($command) {
        return $command.Source
    }

    return $null
}

Write-Host "AKHelper Installer" -ForegroundColor Green
Write-Host "This installs AutoHotkey v2 if needed, creates the helper script, and adds a Desktop shortcut."

Write-Step "Checking for AutoHotkey"
$autoHotkeyPath = Find-AutoHotkey

if (-not $autoHotkeyPath) {
    Write-Step "Installing AutoHotkey v2 with winget"

    $winget = Get-Command "winget.exe" -ErrorAction SilentlyContinue
    if (-not $winget) {
        Write-Host "winget was not found on this computer." -ForegroundColor Red
        Write-Host "Install AutoHotkey v2 manually from https://www.autohotkey.com/ and then run this installer again."
        Read-Host "Press Enter to exit"
        exit 1
    }

    winget install --id AutoHotkey.AutoHotkey --source winget --accept-package-agreements --accept-source-agreements
    Start-Sleep -Seconds 3
    $autoHotkeyPath = Find-AutoHotkey
}

if (-not $autoHotkeyPath) {
    Write-Host "AutoHotkey could not be found after install." -ForegroundColor Red
    Write-Host "Install AutoHotkey v2 manually from https://www.autohotkey.com/ and then run this installer again."
    Read-Host "Press Enter to exit"
    exit 1
}

Write-Host "AutoHotkey found at: $autoHotkeyPath" -ForegroundColor Green

Write-Step "Creating helper folder"
New-Item -ItemType Directory -Force -Path $installRoot | Out-Null

$configName = "EverQuest_Key_Helper_Config.ini"
$legacyConfigPath = Join-Path $legacyInstallRoot $configName
$configPath = Join-Path $installRoot $configName
if ((Test-Path -LiteralPath $legacyConfigPath) -and -not (Test-Path -LiteralPath $configPath)) {
    Write-Step "Migrating existing AKHelper profiles and settings"
    Copy-Item -Force -LiteralPath $legacyConfigPath -Destination $configPath
}

Write-Step "Writing AKHelper files"
$templateAhkPath = Join-Path $PSScriptRoot "EverQuest_Key_Helper.ahk"
if (-not (Test-Path -LiteralPath $templateAhkPath)) {
    Write-Host "Could not find EverQuest_Key_Helper.ahk next to the installer." -ForegroundColor Red
    Write-Host "Make sure the full package folder was extracted before running the installer."
    Read-Host "Press Enter to exit"
    exit 1
}
Copy-Item -Force -LiteralPath $templateAhkPath -Destination $ahkScriptPath

$templateUpdaterPath = Join-Path $PSScriptRoot "Update_EverQuest_Key_Helper.ps1"
if (-not (Test-Path -LiteralPath $templateUpdaterPath)) {
    Write-Host "Could not find Update_EverQuest_Key_Helper.ps1 next to the installer." -ForegroundColor Red
    Read-Host "Press Enter to exit"
    exit 1
}
Copy-Item -Force -LiteralPath $templateUpdaterPath -Destination $updaterScriptPath

Write-Step "Writing start and stop scripts"
@"
`$ErrorActionPreference = "Stop"
`$autoHotkeyPath = "$autoHotkeyPath"
`$ahkScriptPath = "$ahkScriptPath"
Start-Process -FilePath `$autoHotkeyPath ``
    -ArgumentList ('"' + `$ahkScriptPath + '"') ``
    -WorkingDirectory "$installRoot" ``
    -WindowStyle Hidden
"@ | Set-Content -LiteralPath $startScriptPath -Encoding UTF8

@'
$ErrorActionPreference = "SilentlyContinue"

$scriptName = "EverQuest_Key_Helper.ahk"
$processes = Get-CimInstance Win32_Process |
    Where-Object {
        $_.Name -match "AutoHotkey" -and
        $_.CommandLine -like "*$scriptName*"
    }

if (-not $processes) {
    Write-Host "AKHelper is not running."
    Start-Sleep -Seconds 2
    exit 0
}

foreach ($process in $processes) {
    Stop-Process -Id $process.ProcessId -Force
    Write-Host "Stopped AKHelper process $($process.ProcessId)."
}

Start-Sleep -Seconds 2
'@ | Set-Content -LiteralPath $stopScriptPath -Encoding UTF8

Write-Step "Creating Desktop shortcuts"
$shell = New-Object -ComObject WScript.Shell
$shortcut = $shell.CreateShortcut($desktopShortcutPath)
$shortcut.TargetPath = "powershell.exe"
$shortcut.Arguments = '-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File "' + $startScriptPath + '"'
$shortcut.WorkingDirectory = $installRoot
$shortcut.IconLocation = $autoHotkeyPath
$shortcut.Save()

$stopShortcut = $shell.CreateShortcut($desktopStopShortcutPath)
$stopShortcut.TargetPath = "powershell.exe"
$stopShortcut.Arguments = '-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File "' + $stopScriptPath + '"'
$stopShortcut.WorkingDirectory = $installRoot
$stopShortcut.IconLocation = "powershell.exe"
$stopShortcut.Save()

Write-Host ""
Write-Host "Done." -ForegroundColor Green
Write-Host "Shortcuts were created on the Desktop:"
Write-Host "  Start AKHelper"
Write-Host "  Stop AKHelper"
Write-Host ""
Write-Host "Controls:"
Write-Host "  F6      Test key press now"
Write-Host "  F7      Switch input method"
Write-Host "  Ctrl+Esc Stop helper"
Write-Host ""
Write-Host "Sequence Types:"
Write-Host "  Multiple        Every interval tick presses every configured key, 5 seconds apart."
Write-Host "  Interval Series Every interval tick presses the next configured key."
Write-Host ""
Write-Host "The helper runs without a PowerShell window."
Write-Host ""
Read-Host "Press Enter to close this installer"
