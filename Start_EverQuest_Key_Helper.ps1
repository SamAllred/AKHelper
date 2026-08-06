$ErrorActionPreference = "Stop"
$autoHotkeyPath = "C:\Users\Sam_A\AppData\Local\Programs\AutoHotkey\v2\AutoHotkey64.exe"
$ahkScriptPath = "C:\Users\Sam_A\Documents\EverQuest Key Helper\EverQuest_Key_Helper.ahk"
$workingDirectory = "C:\Users\Sam_A\Documents\EverQuest Key Helper"

Start-Process -FilePath $autoHotkeyPath `
    -ArgumentList ('"' + $ahkScriptPath + '"') `
    -WorkingDirectory $workingDirectory `
    -WindowStyle Hidden
