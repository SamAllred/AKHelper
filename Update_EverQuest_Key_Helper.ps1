param(
    [Parameter(Mandatory = $true)]
    [string]$CurrentVersion,

    [Parameter(Mandatory = $true)]
    [string]$InstallRoot,

    [int]$HelperPid = 0,
    [switch]$AutoUpdate
)

$ErrorActionPreference = "Stop"
$repository = "SamAllred/EQHelper"
$releaseApi = "https://api.github.com/repos/$repository/releases/latest"
$assetName = "EverQuest_Key_Helper_Update.zip"
$logPath = Join-Path $InstallRoot "EverQuest_Key_Helper_Update.log"

function Write-UpdateLog {
    param([string]$Message)
    try {
        "{0:u} {1}" -f (Get-Date), $Message | Add-Content -LiteralPath $logPath -Encoding UTF8
    } catch {
        # Updating must never prevent the helper from starting.
    }
}

function Show-UpdatePrompt {
    param([string]$Version)
    Add-Type -AssemblyName PresentationFramework
    $message = "EverQuest Key Helper $Version is available.`n`nInstall it now? The helper will restart automatically."
    $result = [System.Windows.MessageBox]::Show(
        $message,
        "EverQuest Key Helper Update",
        [System.Windows.MessageBoxButton]::YesNo,
        [System.Windows.MessageBoxImage]::Information
    )
    return $result -eq [System.Windows.MessageBoxResult]::Yes
}

try {
    New-Item -ItemType Directory -Force -Path $InstallRoot | Out-Null
    $headers = @{ Accept = "application/vnd.github+json"; "User-Agent" = "EQHelper-Updater" }
    $release = Invoke-RestMethod -Uri $releaseApi -Headers $headers -TimeoutSec 12
    $latestText = ([string]$release.tag_name).TrimStart("v", "V")

    try {
        $current = [version]$CurrentVersion
        $latest = [version]$latestText
    } catch {
        Write-UpdateLog "Ignored release with invalid version. Current=$CurrentVersion Latest=$latestText"
        exit 0
    }

    if ($latest -le $current) {
        exit 0
    }

    $asset = $release.assets | Where-Object { $_.name -eq $assetName } | Select-Object -First 1
    if (-not $asset) {
        Write-UpdateLog "Release v$latestText does not contain $assetName."
        exit 0
    }

    if (-not $AutoUpdate -and -not (Show-UpdatePrompt -Version $latestText)) {
        Write-UpdateLog "User postponed v$latestText."
        exit 0
    }

    $tempRoot = Join-Path ([IO.Path]::GetTempPath()) ("EQHelperUpdate-" + [guid]::NewGuid())
    $zipPath = Join-Path $tempRoot $assetName
    $stagePath = Join-Path $tempRoot "stage"
    New-Item -ItemType Directory -Force -Path $stagePath | Out-Null

    Invoke-WebRequest -Uri $asset.browser_download_url -Headers $headers -OutFile $zipPath -TimeoutSec 60
    Expand-Archive -LiteralPath $zipPath -DestinationPath $stagePath -Force

    $requiredFiles = @(
        "EverQuest_Key_Helper.ahk",
        "Update_EverQuest_Key_Helper.ps1",
        "VERSION"
    )
    foreach ($file in $requiredFiles) {
        if (-not (Test-Path -LiteralPath (Join-Path $stagePath $file))) {
            throw "Downloaded update is missing $file."
        }
    }

    $packageVersion = (Get-Content -LiteralPath (Join-Path $stagePath "VERSION") -Raw).Trim().TrimStart("v", "V")
    if ([version]$packageVersion -ne $latest) {
        throw "Package version $packageVersion does not match release v$latestText."
    }

    if ($HelperPid -gt 0) {
        Stop-Process -Id $HelperPid -Force -ErrorAction SilentlyContinue
        Start-Sleep -Milliseconds 700
    }

    foreach ($file in $requiredFiles) {
        Copy-Item -Force -LiteralPath (Join-Path $stagePath $file) -Destination (Join-Path $InstallRoot $file)
    }

    $instructions = Join-Path $stagePath "EverQuest_Key_Helper_Final_Instructions.txt"
    if (Test-Path -LiteralPath $instructions) {
        Copy-Item -Force -LiteralPath $instructions -Destination (Join-Path $InstallRoot (Split-Path $instructions -Leaf))
    }

    Write-UpdateLog "Installed v$latestText."
    $startScript = Join-Path $InstallRoot "Start_EverQuest_Key_Helper.ps1"
    if (Test-Path -LiteralPath $startScript) {
        Start-Process powershell.exe -ArgumentList @(
            "-NoProfile", "-ExecutionPolicy", "Bypass", "-WindowStyle", "Hidden",
            "-File", ('"' + $startScript + '"')
        ) -WindowStyle Hidden
    }
} catch {
    Write-UpdateLog ("Update check failed: " + $_.Exception.Message)
} finally {
    if ($tempRoot -and (Test-Path -LiteralPath $tempRoot)) {
        Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
    }
}
