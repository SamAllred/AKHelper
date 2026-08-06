#Requires AutoHotkey v2.0
#SingleInstance Force

; AKHelper configurable key-sequence assistant
; Sequence Type:
;   Multiple        = every interval tick, press every key in the list using per-key delays
;   Interval Series = every interval tick, press the next key in the list
; F6 = test using current settings
; F7 = switch input method
; Ctrl+Esc = stop

SetTitleMatchMode 2
OnExit CleanupOnExit

appVersion := "1.5.4"
parentPid := A_Args.Length >= 1 ? A_Args[1] : ""
modes := ["SendEvent", "SendInput", "ControlSend", "PostMessage"]
modeIndex := 1
isRunning := false
seriesIndex := 1
multipleResumeIndex := 1
nextTickAt := 0
mainActionBusy := false
sethActionBusy := false
heldSethKey := ""
logDirectory := "C:\Users\Public\Daybreak Game Company\Installed Games\EverQuest Legends\Logs"
configuredLogFilePath := ""
logFilePath := ""
logFileHandle := ""
logTextBuffer := ""
logReadOffset := 0
logLinesProcessed := 0
lastLogLineAt := 0
lastLogReadError := ""
lastLogEvent := "None"
reactionLastAt := Map()
reactionBusy := false
combatIdlePaused := false
combatLastActivityAt := 0
combatActiveWindowMs := 5000
combatState := "Waiting for combat activity"
lastCombatDirection := "None"
rotationActive := false
rotationDeadline := 0
rotationKey := "Left"
rotationNextActionAt := 0
rotationStartedAt := 0
rotationHoldingKey := false
targetAcquisitionActive := false
lastTargetConfirmedAt := 0
lastOutgoingPhysicalDamageAt := 0
logEventSequence := 0
lastCannotSeeLogTimestamp := 0
lastCannotSeeLogSequence := 0
lastOutgoingDamageLogTimestamp := 0
lastOutgoingDamageLogSequence := 0
lastPhysicalAttackLogTimestamp := 0
lastPhysicalAttackLogSequence := 0
pendingCannotSee := false
targetLockActive := false
targetLockName := ""
targetLockState := "Seeking target"
targetLockLastConfirmedAt := 0
lastAttackAttemptAt := 0
attackState := "Not attacking"
attackTargetName := ""
whenActions := ["Do Nothing", "Stop Helper", "Send Command", "Press Key", "Rotate Slowly Until Target"]
sethCycleStartedAt := 0
sethTriggerAt := 0
sethCycleEndsAt := 0
sethSelectedAction := ""
sethActionQueued := false
sethQueue := []
lastMessage := "Configure settings, then click Start."
keyVisualControls := []
keyVisualTimingControls := []
keyVisualConnectorControls := []
keyVisualStartY := 0
profileLoading := false
sequenceEditorGui := ""
sequenceEditorList := ""
sequenceEditorKeyEdit := ""
sequenceEditorBeforeEdit := ""
sequenceEditorAfterEdit := ""
whenRulesGui := ""
whenDeathActionDropDown := ""
whenDeathValueEdit := ""
whenManaActionDropDown := ""
whenManaValueEdit := ""
whenCannotSeeActionDropDown := ""
whenCannotSeeValueEdit := ""
whenRotationSecondsEdit := ""
combatIdlePauseCheckBox := ""
combatIdleSecondsEdit := ""

configPath := A_ScriptDir "\EverQuest_Key_Helper_Config.ini"

profileNames := LoadProfileNames()
currentProfile := IniRead(configPath, "Profiles", "CurrentProfile", profileNames[1])
if (!ProfileExists(currentProfile)) {
    currentProfile := profileNames[1]
}

windowTitle := ReadProfileSetting(currentProfile, "WindowTitle", "EverQuest Legends")
sequenceType := ReadProfileSetting(currentProfile, "SequenceType", "Multiple")
keyListText := ReadProfileSetting(currentProfile, "Keys", "7")
intervalSeconds := Integer(ReadProfileSetting(currentProfile, "IntervalSeconds", "15"))
if (intervalSeconds < 1) {
    intervalSeconds := 15
}
beforeKeyDelayText := ReadProfileSetting(currentProfile, "BeforeKeyDelaySeconds", "0")
afterKeyDelayText := ReadProfileSetting(currentProfile, "AfterKeyDelaySeconds", "5")
connectorFontSize := Integer(ReadProfileSetting(currentProfile, "ConnectorDelayFontSize", "6"))
if (connectorFontSize < 6 || connectorFontSize > 14) {
    connectorFontSize := 6
}
sleeperMode := Integer(ReadProfileSetting(currentProfile, "SleeperMode", "0")) = 1
sethMode := Integer(ReadProfileSetting(currentProfile, "SethMode", "0")) = 1
simpleSethMode := Integer(ReadProfileSetting(currentProfile, "SimpleSethMode", "0")) = 1
whenDeathAction := ReadProfileSetting(currentProfile, "WhenDeathAction", "Do Nothing")
whenDeathValue := ReadProfileSetting(currentProfile, "WhenDeathValue", "/camp")
whenManaAction := ReadProfileSetting(currentProfile, "WhenManaAction", "Do Nothing")
whenManaValue := ReadProfileSetting(currentProfile, "WhenManaValue", "")
whenCannotSeeAction := ReadProfileSetting(currentProfile, "WhenCannotSeeAction", "Do Nothing")
whenCannotSeeValue := ReadProfileSetting(currentProfile, "WhenCannotSeeValue", "Left")
whenRotationSeconds := Integer(ReadProfileSetting(currentProfile, "WhenRotationSeconds", "10"))
if (whenRotationSeconds < 1 || whenRotationSeconds > 60) {
    whenRotationSeconds := 10
}
combatIdlePauseEnabled := Integer(ReadProfileSetting(currentProfile, "CombatIdlePauseEnabled", "0")) = 1
combatIdleSeconds := Integer(ReadProfileSetting(currentProfile, "CombatIdleSeconds", "15"))
if (combatIdleSeconds < 1 || combatIdleSeconds > 600) {
    combatIdleSeconds := 15
}
configuredLogFilePath := ReadProfileSetting(currentProfile, "LogFilePath", "")
savedInputMethod := ReadProfileSetting(currentProfile, "InputMethod", "SendEvent")
modeIndex := FindModeIndex(savedInputMethod)

helperGui := Gui("+AlwaysOnTop +ToolWindow", "AKHelper v" appVersion)
helperGui.SetFont("s9", "Segoe UI")

helperGui.AddText("xm ym", "Profile")
profileDropDown := helperGui.AddDropDownList("xm w210", profileNames)
profileDropDown.Text := currentProfile
newProfileButton := helperGui.AddButton("x+8 yp-1 w62", "New")
renameProfileButton := helperGui.AddButton("x+6 w72", "Rename")
deleteProfileButton := helperGui.AddButton("x+6 w62", "Delete")

settingsGui := Gui("+Owner" helperGui.Hwnd " +AlwaysOnTop +ToolWindow", "AKHelper v" appVersion " - Settings")
settingsGui.SetFont("s9", "Segoe UI")
settingsHeading := settingsGui.AddText("xm ym", "Profile configuration")
settingsHeading.SetFont("s10 bold c374151", "Segoe UI")
settingsProfileLabel := settingsGui.AddText("xm y+3 c64748B", "Editing profile: " currentProfile)

settingsGui.AddText("xm y+14", "Window title contains")
windowTitleEdit := settingsGui.AddEdit("xm w390", windowTitle)

settingsGui.AddText("xm y+10", "Sequence type")
sequenceTypeDropDown := settingsGui.AddDropDownList("xm w180", ["Multiple", "Interval Series"])
sequenceTypeDropDown.Text := sequenceType

settingsGui.AddText("x+20 yp", "Interval seconds")
intervalEdit := settingsGui.AddEdit("x+0 w80", intervalSeconds)

settingsGui.AddText("xm y+10", "Keys")
keyListEdit := settingsGui.AddEdit("xm w275", keyListText)
sequenceEditorButton := settingsGui.AddButton("x+8 yp-1 w112", "Edit Sequence")
settingsGui.AddText("xm y+2 cGray", "Examples: 7    or    1,2,3    or    F1,F2,7")
settingsGui.AddText("xm y+2 cGray", "Configure each key's before and after timing with Edit Sequence.")

optionsLabel := settingsGui.AddText("xm y+12", "Profile options")
optionsLabel.SetFont("s9 bold c374151", "Segoe UI")
sleeperModeCheckBox := settingsGui.AddCheckbox("xm y+7", "Sleeper mode (bring EverQuest forward when the sequence is due)")
sleeperModeCheckBox.Value := sleeperMode ? 1 : 0
sethModeCheckBox := settingsGui.AddCheckbox("xm y+6", "Seth Mode")
sethModeCheckBox.Value := sethMode ? 1 : 0
simpleSethModeCheckBox := settingsGui.AddCheckbox("x+18 yp", "Simple Seth Mode (Space only)")
simpleSethModeCheckBox.Value := simpleSethMode ? 1 : 0
settingsGui.AddText("xm y+9", "Connector delay font size")
connectorFontSizeEdit := settingsGui.AddEdit("x+8 yp-3 w55 Number", connectorFontSize)
settingsGui.AddText("x+8 yp+3 cGray", "Size of the delay arrows shown between sequence keys (6-14).")

settingsGui.AddText("xm y+12", "EverQuest log file")
logFilePathEdit := settingsGui.AddEdit("xm w390", configuredLogFilePath)
logFileBrowseButton := settingsGui.AddButton("x+8 yp-1 w70", "Browse")
settingsGui.AddText("xm y+2 cGray", "Leave blank to automatically use the newest eqlog_*.txt file.")

whenRulesButton := settingsGui.AddButton("xm y+14 w180", "When... Happens")
settingsGui.AddText("x+8 yp+3 cGray", "Configure log-triggered responses for this profile.")

settingsSaveButton := settingsGui.AddButton("xm y+18 w100 Default", "Save")
settingsSaveCloseButton := settingsGui.AddButton("x+8 w110", "Save && Close")
settingsCancelButton := settingsGui.AddButton("x+8 w90", "Close")

keyActivityLabel := helperGui.AddText("xm y+16", "Key activity")
keyActivityLabel.SetFont("s9 bold c374151")
keyActivityLabel.GetPos(&keyActivityX, &keyActivityY, &keyActivityW, &keyActivityH)
keyVisualStartY := keyActivityY + keyActivityH + 6

startButton := helperGui.AddButton("xm y+70 w90", "Start")
stopButton := helperGui.AddButton("x+8 w90", "Stop")
applyButton := helperGui.AddButton("x+8 w90", "Settings")
testButton := helperGui.AddButton("x+8 w90", "Test F6")

statusText := helperGui.AddEdit("xm y+12 w520 h215 ReadOnly -Wrap +VScroll", "")

; Hidden compatibility controls retain the profile's delay lists. Per-key timing is
; edited exclusively through the Visual Sequence Editor.
beforeKeyDelayEdit := settingsGui.AddEdit("x0 y0 w1 h1 Hidden", beforeKeyDelayText)
afterKeyDelayEdit := settingsGui.AddEdit("x0 y0 w1 h1 Hidden", afterKeyDelayText)

startButton.OnEvent("Click", (*) => StartHelper())
stopButton.OnEvent("Click", (*) => StopHelper())
applyButton.OnEvent("Click", (*) => OpenSettings())
testButton.OnEvent("Click", (*) => TestNow())
profileDropDown.OnEvent("Change", (*) => SelectProfile())
newProfileButton.OnEvent("Click", (*) => CreateProfile())
renameProfileButton.OnEvent("Click", (*) => RenameProfile())
deleteProfileButton.OnEvent("Click", (*) => DeleteProfile())
sequenceEditorButton.OnEvent("Click", (*) => OpenSequenceEditor())
logFileBrowseButton.OnEvent("Click", (*) => BrowseLogFile())
whenRulesButton.OnEvent("Click", (*) => OpenWhenRules())
settingsSaveButton.OnEvent("Click", (*) => SaveSettings())
settingsSaveCloseButton.OnEvent("Click", (*) => SaveAndCloseSettings())
settingsCancelButton.OnEvent("Click", CloseSettings)
settingsGui.OnEvent("Close", CloseSettings)
helperGui.OnEvent("Close", (*) => ExitApp())

BuildKeyVisuals()
helperGui.Show("x40 y40")
UpdateStatus()
SetTimer RefreshLiveStatus, 250
SetTimer CheckForApplicationUpdate, -1500

if (parentPid != "") {
    SetTimer CheckParentStillRunning, 1000
}

CheckForApplicationUpdate() {
    global appVersion

    updaterPath := A_ScriptDir "\Update_EverQuest_Key_Helper.ps1"
    if (!FileExist(updaterPath)) {
        return
    }

    command := "powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "
        . QuoteCommandArgument(updaterPath)
        . " -CurrentVersion " . QuoteCommandArgument(appVersion)
        . " -InstallRoot " . QuoteCommandArgument(A_ScriptDir)
        . " -HelperPid " . ProcessExist()

    try Run(command, A_ScriptDir, "Hide")
}

QuoteCommandArgument(value) {
    return Chr(34) . StrReplace(value, Chr(34), Chr(34) Chr(34)) . Chr(34)
}

ProfileSection(profileName) {
    return "Profile." profileName
}

LoadProfileNames() {
    global configPath

    namesText := IniRead(configPath, "Profiles", "Names", "")
    names := []
    for rawName in StrSplit(namesText, "|") {
        name := Trim(rawName)
        if (name != "") {
            names.Push(name)
        }
    }

    if (names.Length = 0) {
        names.Push("Default")
    }

    return names
}

SaveProfileList() {
    global configPath, profileNames, currentProfile

    namesText := ""
    for name in profileNames {
        namesText .= (namesText = "" ? "" : "|") name
    }

    IniWrite namesText, configPath, "Profiles", "Names"
    IniWrite currentProfile, configPath, "Profiles", "CurrentProfile"
}

ProfileExists(profileName) {
    global profileNames

    for name in profileNames {
        if (name = profileName) {
            return true
        }
    }
    return false
}

ReadProfileSetting(profileName, keyName, defaultValue) {
    global configPath

    profileValue := IniRead(configPath, ProfileSection(profileName), keyName, "__MISSING__")
    if (profileValue != "__MISSING__") {
        return profileValue
    }

    ; The Default profile inherits old single-profile settings on first use.
    if (profileName = "Default") {
        return IniRead(configPath, "Settings", keyName, defaultValue)
    }

    return defaultValue
}

FindModeIndex(modeName) {
    global modes

    for index, mode in modes {
        if (mode = modeName) {
            return index
        }
    }
    return 1
}

ProfileNameIsValid(profileName) {
    return profileName != ""
        && !InStr(profileName, "|")
        && !InStr(profileName, "[")
        && !InStr(profileName, "]")
        && !InStr(profileName, "=")
}

RefreshProfileDropDown(selectedName) {
    global profileDropDown, profileNames, profileLoading

    profileLoading := true
    profileDropDown.Delete()
    profileDropDown.Add(profileNames)
    profileDropDown.Text := selectedName
    profileLoading := false
}

LoadProfileIntoControls(profileName) {
    global currentProfile, windowTitle, sequenceType, keyListText, intervalSeconds
    global beforeKeyDelayText, afterKeyDelayText, connectorFontSize
    global sleeperMode, sethMode, simpleSethMode, modeIndex
    global whenDeathAction, whenDeathValue, whenManaAction, whenManaValue
    global whenCannotSeeAction, whenCannotSeeValue, whenRotationSeconds
    global combatIdlePauseEnabled, combatIdleSeconds
    global combatIdlePauseEnabled, combatIdleSeconds
    global configuredLogFilePath
    global windowTitleEdit, sequenceTypeDropDown, keyListEdit, intervalEdit
    global beforeKeyDelayEdit, afterKeyDelayEdit, connectorFontSizeEdit
    global sleeperModeCheckBox, sethModeCheckBox
    global simpleSethModeCheckBox, settingsProfileLabel, logFilePathEdit, lastMessage

    currentProfile := profileName
    windowTitle := ReadProfileSetting(profileName, "WindowTitle", "EverQuest Legends")
    sequenceType := ReadProfileSetting(profileName, "SequenceType", "Multiple")
    keyListText := ReadProfileSetting(profileName, "Keys", "7")
    intervalSeconds := Integer(ReadProfileSetting(profileName, "IntervalSeconds", "15"))
    if (intervalSeconds < 1) {
        intervalSeconds := 15
    }
    beforeKeyDelayText := ReadProfileSetting(profileName, "BeforeKeyDelaySeconds", "0")
    afterKeyDelayText := ReadProfileSetting(profileName, "AfterKeyDelaySeconds", "5")
    connectorFontSize := Integer(ReadProfileSetting(profileName, "ConnectorDelayFontSize", "6"))
    if (connectorFontSize < 6 || connectorFontSize > 14) {
        connectorFontSize := 6
    }
    sleeperMode := Integer(ReadProfileSetting(profileName, "SleeperMode", "0")) = 1
    sethMode := Integer(ReadProfileSetting(profileName, "SethMode", "0")) = 1
    simpleSethMode := Integer(ReadProfileSetting(profileName, "SimpleSethMode", "0")) = 1
    whenDeathAction := ReadProfileSetting(profileName, "WhenDeathAction", "Do Nothing")
    whenDeathValue := ReadProfileSetting(profileName, "WhenDeathValue", "/camp")
    whenManaAction := ReadProfileSetting(profileName, "WhenManaAction", "Do Nothing")
    whenManaValue := ReadProfileSetting(profileName, "WhenManaValue", "")
    whenCannotSeeAction := ReadProfileSetting(profileName, "WhenCannotSeeAction", "Do Nothing")
    whenCannotSeeValue := ReadProfileSetting(profileName, "WhenCannotSeeValue", "Left")
    whenRotationSeconds := Integer(ReadProfileSetting(profileName, "WhenRotationSeconds", "10"))
    if (whenRotationSeconds < 1 || whenRotationSeconds > 60) {
        whenRotationSeconds := 10
    }
    combatIdlePauseEnabled := Integer(ReadProfileSetting(profileName, "CombatIdlePauseEnabled", "0")) = 1
    combatIdleSeconds := Integer(ReadProfileSetting(profileName, "CombatIdleSeconds", "15"))
    if (combatIdleSeconds < 1 || combatIdleSeconds > 600) {
        combatIdleSeconds := 15
    }
    configuredLogFilePath := ReadProfileSetting(profileName, "LogFilePath", "")
    modeIndex := FindModeIndex(ReadProfileSetting(profileName, "InputMethod", "SendEvent"))

    windowTitleEdit.Value := windowTitle
    sequenceTypeDropDown.Text := sequenceType
    keyListEdit.Value := keyListText
    intervalEdit.Value := intervalSeconds
    beforeKeyDelayEdit.Value := beforeKeyDelayText
    afterKeyDelayEdit.Value := afterKeyDelayText
    connectorFontSizeEdit.Value := connectorFontSize
    sleeperModeCheckBox.Value := sleeperMode ? 1 : 0
    sethModeCheckBox.Value := sethMode ? 1 : 0
    simpleSethModeCheckBox.Value := simpleSethMode ? 1 : 0
    settingsProfileLabel.Value := "Editing profile: " profileName
    logFilePathEdit.Value := configuredLogFilePath
    RefreshWhenRuleControls()
    BuildKeyVisuals()
    SaveProfileList()
    lastMessage := "Loaded profile: " profileName "."
    UpdateStatus()
}

SelectProfile() {
    global profileDropDown, profileLoading, isRunning

    if (profileLoading || profileDropDown.Text = "") {
        return
    }

    if (isRunning) {
        StopHelper()
    }
    LoadProfileIntoControls(profileDropDown.Text)
}

CreateProfile() {
    global profileNames, currentProfile, profileDropDown, lastMessage

    result := InputBox("Enter a name for the new profile.", "New Profile", "w360 h130")
    if (result.Result != "OK") {
        return
    }

    profileName := Trim(result.Value)
    if (!ProfileNameIsValid(profileName)) {
        MsgBox "Profile names cannot be blank or contain |, [, ], or =.", "AKHelper"
        return
    }
    if (ProfileExists(profileName)) {
        MsgBox "A profile with that name already exists.", "AKHelper"
        return
    }

    profileNames.Push(profileName)
    currentProfile := profileName
    RefreshProfileDropDown(profileName)
    SaveProfileList()
    if (SaveSettings()) {
        lastMessage := "Created profile: " profileName "."
        UpdateStatus()
    }
}

RenameProfile() {
    global configPath, profileNames, currentProfile, lastMessage

    result := InputBox("Enter a new name for this profile.", "Rename Profile", "w360 h130", currentProfile)
    if (result.Result != "OK") {
        return
    }

    newName := Trim(result.Value)
    if (newName = currentProfile) {
        return
    }
    if (!ProfileNameIsValid(newName)) {
        MsgBox "Profile names cannot be blank or contain |, [, ], or =.", "AKHelper"
        return
    }
    if (ProfileExists(newName)) {
        MsgBox "A profile with that name already exists.", "AKHelper"
        return
    }

    oldName := currentProfile
    for index, name in profileNames {
        if (name = oldName) {
            profileNames[index] := newName
            break
        }
    }
    currentProfile := newName
    IniDelete configPath, ProfileSection(oldName)
    RefreshProfileDropDown(newName)
    SaveProfileList()
    SaveSettings()
    lastMessage := "Renamed profile to: " newName "."
    UpdateStatus()
}

DeleteProfile() {
    global configPath, profileNames, currentProfile, isRunning, lastMessage

    if (profileNames.Length = 1) {
        MsgBox "At least one profile must remain.", "AKHelper"
        return
    }
    if (MsgBox("Delete profile '" currentProfile "'?", "AKHelper", "YesNo Icon!") != "Yes") {
        return
    }

    if (isRunning) {
        StopHelper()
    }
    deletedName := currentProfile
    for index, name in profileNames {
        if (name = deletedName) {
            profileNames.RemoveAt(index)
            break
        }
    }
    IniDelete configPath, ProfileSection(deletedName)
    currentProfile := profileNames[1]
    RefreshProfileDropDown(currentProfile)
    LoadProfileIntoControls(currentProfile)
    lastMessage := "Deleted profile: " deletedName "."
    UpdateStatus()
}

GetDelaySecondsTextFor(delayText, positionIndex) {
    parts := ParseDelayList(delayText)
    if (parts.Length = 0) {
        return "0"
    }
    if (parts.Length = 1) {
        return parts[1]
    }
    if (positionIndex <= parts.Length) {
        return parts[positionIndex]
    }
    return "0"
}

OpenSettings() {
    global settingsGui, settingsProfileLabel, currentProfile

    settingsProfileLabel.Value := "Editing profile: " currentProfile
    settingsGui.Show("AutoSize Center")
}

BrowseLogFile() {
    global logDirectory, logFilePathEdit

    selectedPath := FileSelect(1, logDirectory, "Select EverQuest log file", "Text files (*.txt)")
    if (selectedPath != "") {
        logFilePathEdit.Value := selectedPath
    }
}

OpenWhenRules() {
    global settingsGui, whenRulesGui, whenActions
    global whenDeathActionDropDown, whenDeathValueEdit
    global whenManaActionDropDown, whenManaValueEdit
    global whenCannotSeeActionDropDown, whenCannotSeeValueEdit, whenRotationSecondsEdit
    global combatIdlePauseCheckBox, combatIdleSecondsEdit

    if (!IsObject(whenRulesGui)) {
        whenRulesGui := Gui("+Owner" settingsGui.Hwnd " +AlwaysOnTop +ToolWindow", "When... Happens")
        whenRulesGui.SetFont("s9", "Segoe UI")
        heading := whenRulesGui.AddText("xm ym", "Log-triggered responses")
        heading.SetFont("s10 bold c374151", "Segoe UI")
        whenRulesGui.AddText("xm y+3 w650 c64748B",
            "Rules watch new lines in the active eqlog file. Do Nothing disables a rule.")

        whenRulesGui.AddText("xm y+14 w205", "When this happens")
        whenRulesGui.AddText("x+8 yp w190", "Do this")
        whenRulesGui.AddText("x+8 yp w210", "Command, key, or rotation key")

        whenRulesGui.AddText("xm y+8 w205", "Death")
        whenDeathActionDropDown := whenRulesGui.AddDropDownList("x+8 yp-3 w190", whenActions)
        whenDeathValueEdit := whenRulesGui.AddEdit("x+8 yp w210")

        whenRulesGui.AddText("xm y+10 w205", "Insufficient Mana to cast this spell")
        whenManaActionDropDown := whenRulesGui.AddDropDownList("x+8 yp-3 w190", whenActions)
        whenManaValueEdit := whenRulesGui.AddEdit("x+8 yp w210")

        whenRulesGui.AddText("xm y+10 w205", "You cannot see your target")
        whenCannotSeeActionDropDown := whenRulesGui.AddDropDownList("x+8 yp-3 w190", whenActions)
        whenCannotSeeValueEdit := whenRulesGui.AddEdit("x+8 yp w210")

        whenRulesGui.AddText("xm y+14", "Maximum slow-rotation time")
        whenRotationSecondsEdit := whenRulesGui.AddEdit("x+8 yp-3 w55 Number")
        whenRulesGui.AddText("x+8 yp+3 cGray", "seconds (1-60); stops on outgoing damage or a Targeted (...) line")
        whenRulesGui.AddText("xm y+12 w650 c64748B",
            "Value examples: /camp for Send Command, 5 for Press Key, Left or Right for rotation.")

        combatHeading := whenRulesGui.AddText("xm y+16", "Combat activity timeout")
        combatHeading.SetFont("s9 bold c374151", "Segoe UI")
        combatIdlePauseCheckBox := whenRulesGui.AddCheckbox("xm y+8", "Pause the main sequence after no player combat activity for")
        combatIdleSecondsEdit := whenRulesGui.AddEdit("x+8 yp-3 w55 Number")
        whenRulesGui.AddText("x+8 yp+3", "seconds")
        whenRulesGui.AddText("xm y+3 w650 c64748B",
            "Incoming or outgoing player damage automatically resumes the sequence from its queued position.")

        saveButton := whenRulesGui.AddButton("xm y+16 w100 Default", "Save Rules")
        closeButton := whenRulesGui.AddButton("x+8 w90", "Close")
        saveButton.OnEvent("Click", (*) => SaveWhenRules())
        closeButton.OnEvent("Click", CloseWhenRules)
        whenRulesGui.OnEvent("Close", CloseWhenRules)
    }

    RefreshWhenRuleControls()
    whenRulesGui.Show("AutoSize Center")
}

RefreshWhenRuleControls() {
    global whenRulesGui, whenDeathAction, whenDeathValue, whenManaAction, whenManaValue
    global whenCannotSeeAction, whenCannotSeeValue, whenRotationSeconds
    global combatIdlePauseEnabled, combatIdleSeconds
    global whenDeathActionDropDown, whenDeathValueEdit
    global whenManaActionDropDown, whenManaValueEdit
    global whenCannotSeeActionDropDown, whenCannotSeeValueEdit, whenRotationSecondsEdit
    global combatIdlePauseCheckBox, combatIdleSecondsEdit

    if (!IsObject(whenRulesGui)) {
        return
    }
    whenDeathActionDropDown.Text := whenDeathAction
    whenDeathValueEdit.Value := whenDeathValue
    whenManaActionDropDown.Text := whenManaAction
    whenManaValueEdit.Value := whenManaValue
    whenCannotSeeActionDropDown.Text := whenCannotSeeAction
    whenCannotSeeValueEdit.Value := whenCannotSeeValue
    whenRotationSecondsEdit.Value := whenRotationSeconds
    combatIdlePauseCheckBox.Value := combatIdlePauseEnabled ? 1 : 0
    combatIdleSecondsEdit.Value := combatIdleSeconds
}

SaveWhenRules() {
    global whenDeathAction, whenDeathValue, whenManaAction, whenManaValue
    global whenCannotSeeAction, whenCannotSeeValue, whenRotationSeconds
    global combatIdlePauseEnabled, combatIdleSeconds
    global configuredLogFilePath, logFilePathEdit
    global whenDeathActionDropDown, whenDeathValueEdit
    global whenManaActionDropDown, whenManaValueEdit
    global whenCannotSeeActionDropDown, whenCannotSeeValueEdit, whenRotationSecondsEdit
    global combatIdlePauseCheckBox, combatIdleSecondsEdit

    try rotationSeconds := Integer(Trim(whenRotationSecondsEdit.Value))
    catch {
        rotationSeconds := 0
    }
    if (rotationSeconds < 1 || rotationSeconds > 60) {
        MsgBox "Maximum slow-rotation time must be between 1 and 60 seconds.", "When... Happens"
        return false
    }
    try enteredCombatIdleSeconds := Integer(Trim(combatIdleSecondsEdit.Value))
    catch {
        enteredCombatIdleSeconds := 0
    }
    if (enteredCombatIdleSeconds < 1 || enteredCombatIdleSeconds > 600) {
        MsgBox "Combat inactivity time must be between 1 and 600 seconds.", "When... Happens"
        return false
    }

    whenDeathAction := whenDeathActionDropDown.Text
    whenDeathValue := Trim(whenDeathValueEdit.Value)
    whenManaAction := whenManaActionDropDown.Text
    whenManaValue := Trim(whenManaValueEdit.Value)
    whenCannotSeeAction := whenCannotSeeActionDropDown.Text
    whenCannotSeeValue := Trim(whenCannotSeeValueEdit.Value)
    whenRotationSeconds := rotationSeconds
    combatIdlePauseEnabled := combatIdlePauseCheckBox.Value = 1
    combatIdleSeconds := enteredCombatIdleSeconds

    if (!ValidateWhenRuleValue(whenDeathAction, whenDeathValue)
        || !ValidateWhenRuleValue(whenManaAction, whenManaValue)
        || !ValidateWhenRuleValue(whenCannotSeeAction, whenCannotSeeValue)) {
        MsgBox "Send Command, Press Key, and Rotate actions require a value.", "When... Happens"
        return false
    }

    return SaveSettings()
}

ValidateWhenRuleValue(action, value) {
    return (action = "Do Nothing" || action = "Stop Helper" || value != "")
}

CloseWhenRules(*) {
    global whenRulesGui
    whenRulesGui.Hide()
    return true
}

SaveAndCloseSettings() {
    global settingsGui

    if (SaveSettings()) {
        settingsGui.Hide()
    }
}

CloseSettings(*) {
    global settingsGui

    settingsGui.Hide()
    return true
}

OpenSequenceEditor() {
    global settingsGui, sequenceEditorGui, sequenceEditorList
    global sequenceEditorKeyEdit, sequenceEditorBeforeEdit, sequenceEditorAfterEdit
    global beforeKeyDelayEdit, afterKeyDelayEdit

    if (IsObject(sequenceEditorGui)) {
        try sequenceEditorGui.Destroy()
    }

    sequenceEditorGui := Gui("+Owner" settingsGui.Hwnd " +AlwaysOnTop", "Visual Sequence Editor")
    sequenceEditorGui.SetFont("s9", "Segoe UI")
    sequenceEditorGui.AddText("xm ym w590", "Build the sequence in order. Select a row to edit its key and timing.")

    sequenceEditorList := sequenceEditorGui.AddListView("xm y+10 w590 r9 Grid -Multi", ["Position", "Key", "Before (sec)", "After (sec)"])
    sequenceEditorList.ModifyCol(1, 68)
    sequenceEditorList.ModifyCol(2, 180)
    sequenceEditorList.ModifyCol(3, 145)
    sequenceEditorList.ModifyCol(4, 145)
    sequenceEditorList.OnEvent("ItemSelect", SequenceEditorItemSelected)
    sequenceEditorList.OnEvent("DoubleClick", SequenceEditorDoubleClick)

    sequenceEditorGui.AddText("xm y+12", "Key")
    sequenceEditorKeyEdit := sequenceEditorGui.AddEdit("xm w180")
    sequenceEditorGui.AddText("x+12 yp", "Before delay")
    sequenceEditorBeforeEdit := sequenceEditorGui.AddEdit("x+0 w100", "0")
    sequenceEditorGui.AddText("x+12 yp", "After delay")
    sequenceEditorAfterEdit := sequenceEditorGui.AddEdit("x+0 w100", "0")
    updateRowButton := sequenceEditorGui.AddButton("x+12 yp-1 w86", "Update")

    addRowButton := sequenceEditorGui.AddButton("xm y+14 w86", "Add Key")
    removeRowButton := sequenceEditorGui.AddButton("x+8 w86", "Remove")
    moveUpButton := sequenceEditorGui.AddButton("x+8 w86", "Move Up")
    moveDownButton := sequenceEditorGui.AddButton("x+8 w86", "Move Down")
    applyEditorButton := sequenceEditorGui.AddButton("x+32 w90 Default", "Apply")
    cancelEditorButton := sequenceEditorGui.AddButton("x+8 w80", "Cancel")

    updateRowButton.OnEvent("Click", (*) => UpdateSequenceEditorRow())
    addRowButton.OnEvent("Click", (*) => AddSequenceEditorRow())
    removeRowButton.OnEvent("Click", (*) => RemoveSequenceEditorRow())
    moveUpButton.OnEvent("Click", (*) => MoveSequenceEditorRow(-1))
    moveDownButton.OnEvent("Click", (*) => MoveSequenceEditorRow(1))
    applyEditorButton.OnEvent("Click", (*) => ApplySequenceEditor())
    cancelEditorButton.OnEvent("Click", (*) => CloseSequenceEditor())
    sequenceEditorGui.OnEvent("Close", (*) => CloseSequenceEditor())

    keys := GetConfiguredKeys()
    beforeText := beforeKeyDelayEdit.Value
    afterText := afterKeyDelayEdit.Value
    for index, key in keys {
        sequenceEditorList.Add("", index, key,
            GetDelaySecondsTextFor(beforeText, index),
            GetDelaySecondsTextFor(afterText, index))
    }
    if (keys.Length = 0) {
        sequenceEditorList.Add("", 1, "7", "0", "0")
    }

    sequenceEditorList.Modify(1, "Select Focus Vis")
    LoadSequenceEditorRow(1)
    sequenceEditorGui.Show("AutoSize Center")
}

CloseSequenceEditor() {
    global sequenceEditorGui
    if (IsObject(sequenceEditorGui)) {
        try sequenceEditorGui.Destroy()
    }
    sequenceEditorGui := ""
}

SequenceEditorItemSelected(listControl, rowNumber, selected) {
    if (selected && rowNumber > 0) {
        LoadSequenceEditorRow(rowNumber)
    }
}

SequenceEditorDoubleClick(listControl, rowNumber) {
    global sequenceEditorKeyEdit

    if (rowNumber > 0) {
        LoadSequenceEditorRow(rowNumber)
        sequenceEditorKeyEdit.Focus()
    }
}

LoadSequenceEditorRow(rowNumber) {
    global sequenceEditorList, sequenceEditorKeyEdit
    global sequenceEditorBeforeEdit, sequenceEditorAfterEdit

    if (!IsObject(sequenceEditorList) || rowNumber < 1 || rowNumber > sequenceEditorList.GetCount()) {
        return
    }
    sequenceEditorKeyEdit.Value := sequenceEditorList.GetText(rowNumber, 2)
    sequenceEditorBeforeEdit.Value := sequenceEditorList.GetText(rowNumber, 3)
    sequenceEditorAfterEdit.Value := sequenceEditorList.GetText(rowNumber, 4)
}

ValidateEditorFields(showMessage := true) {
    global sequenceEditorKeyEdit, sequenceEditorBeforeEdit, sequenceEditorAfterEdit

    if (Trim(sequenceEditorKeyEdit.Value) = "") {
        if (showMessage) {
            MsgBox "Enter a key for this position.", "Visual Sequence Editor"
        }
        return false
    }
    if (!ValidateDelayList(sequenceEditorBeforeEdit.Value) || !ValidateDelayList(sequenceEditorAfterEdit.Value)) {
        if (showMessage) {
            MsgBox "Before and after delays must be numbers 0 or greater.", "Visual Sequence Editor"
        }
        return false
    }
    return true
}

UpdateSequenceEditorRow() {
    global sequenceEditorList, sequenceEditorKeyEdit
    global sequenceEditorBeforeEdit, sequenceEditorAfterEdit

    row := sequenceEditorList.GetNext()
    if (row = 0 || !ValidateEditorFields()) {
        return false
    }

    beforeValue := NormalizeDelayListText(sequenceEditorBeforeEdit.Value)
    afterValue := NormalizeDelayListText(sequenceEditorAfterEdit.Value)
    if (InStr(beforeValue, ",") || InStr(afterValue, ",")) {
        MsgBox "Enter one delay value for each row.", "Visual Sequence Editor"
        return false
    }

    sequenceEditorList.Modify(row, "", row, Trim(sequenceEditorKeyEdit.Value), beforeValue, afterValue)
    return true
}

AddSequenceEditorRow() {
    global sequenceEditorList, sequenceEditorKeyEdit
    global sequenceEditorBeforeEdit, sequenceEditorAfterEdit

    if (!ValidateEditorFields()) {
        return
    }

    beforeValue := NormalizeDelayListText(sequenceEditorBeforeEdit.Value)
    afterValue := NormalizeDelayListText(sequenceEditorAfterEdit.Value)
    if (InStr(beforeValue, ",") || InStr(afterValue, ",")) {
        MsgBox "Enter one delay value for each row.", "Visual Sequence Editor"
        return
    }

    row := sequenceEditorList.Add("",
        sequenceEditorList.GetCount() + 1,
        Trim(sequenceEditorKeyEdit.Value),
        beforeValue,
        afterValue)
    sequenceEditorList.Modify(row, "Select Focus Vis")
    LoadSequenceEditorRow(row)
}

RemoveSequenceEditorRow() {
    global sequenceEditorList

    row := sequenceEditorList.GetNext()
    if (row = 0) {
        return
    }
    if (sequenceEditorList.GetCount() = 1) {
        MsgBox "The sequence must contain at least one key.", "Visual Sequence Editor"
        return
    }

    sequenceEditorList.Delete(row)
    RenumberSequenceEditorRows()
    nextRow := Min(row, sequenceEditorList.GetCount())
    sequenceEditorList.Modify(nextRow, "Select Focus Vis")
    LoadSequenceEditorRow(nextRow)
}

MoveSequenceEditorRow(direction) {
    global sequenceEditorList

    row := sequenceEditorList.GetNext()
    target := row + direction
    if (row = 0 || target < 1 || target > sequenceEditorList.GetCount()) {
        return
    }

    rowKey := sequenceEditorList.GetText(row, 2)
    rowBefore := sequenceEditorList.GetText(row, 3)
    rowAfter := sequenceEditorList.GetText(row, 4)
    targetKey := sequenceEditorList.GetText(target, 2)
    targetBefore := sequenceEditorList.GetText(target, 3)
    targetAfter := sequenceEditorList.GetText(target, 4)

    sequenceEditorList.Modify(row, "", row, targetKey, targetBefore, targetAfter)
    sequenceEditorList.Modify(target, "", target, rowKey, rowBefore, rowAfter)
    sequenceEditorList.Modify(target, "Select Focus Vis")
    LoadSequenceEditorRow(target)
}

RenumberSequenceEditorRows() {
    global sequenceEditorList
    Loop sequenceEditorList.GetCount() {
        sequenceEditorList.Modify(A_Index, "", A_Index)
    }
}

ApplySequenceEditor() {
    global sequenceEditorList, keyListEdit, beforeKeyDelayEdit, afterKeyDelayEdit
    global lastMessage

    selectedRow := sequenceEditorList.GetNext()
    if (selectedRow > 0 && !UpdateSequenceEditorRow()) {
        return
    }

    keysText := ""
    beforeText := ""
    afterText := ""
    Loop sequenceEditorList.GetCount() {
        key := Trim(sequenceEditorList.GetText(A_Index, 2))
        beforeValue := sequenceEditorList.GetText(A_Index, 3)
        afterValue := sequenceEditorList.GetText(A_Index, 4)
        if (key = "") {
            MsgBox "Every sequence position must contain a key.", "Visual Sequence Editor"
            return
        }
        keysText .= (keysText = "" ? "" : ",") key
        beforeText .= (beforeText = "" ? "" : ",") beforeValue
        afterText .= (afterText = "" ? "" : ",") afterValue
    }

    keyListEdit.Value := keysText
    beforeKeyDelayEdit.Value := beforeText
    afterKeyDelayEdit.Value := afterText
    if (!SaveSettings()) {
        return
    }

    lastMessage := "Visual sequence applied and profile saved."
    UpdateStatus()
    CloseSequenceEditor()
}

CheckParentStillRunning() {
    global parentPid

    if (parentPid != "" && !ProcessExist(Integer(parentPid))) {
        ExitApp
    }
}

CleanupOnExit(*) {
    global heldSethKey, rotationActive, rotationKey

    SetTimer Tick, 0
    SetTimer SethScheduler, 0
    SetTimer SlowRotationTick, 0
    if (heldSethKey != "") {
        try SendGameKeyState(heldSethKey, false)
        heldSethKey := ""
    }
    if (rotationActive && rotationKey != "") {
        try SendGameKeyState(rotationKey, false)
    }
    StopLogMonitor()
}

StartHelper() {
    global isRunning, seriesIndex, multipleResumeIndex, nextTickAt, lastMessage, sethMode
    global targetLockActive, targetLockName, targetLockState, targetLockLastConfirmedAt
    global targetAcquisitionActive
    global lastAttackAttemptAt, attackState, attackTargetName
    global lastCannotSeeLogTimestamp, lastCannotSeeLogSequence
    global lastOutgoingDamageLogTimestamp, lastOutgoingDamageLogSequence
    global lastPhysicalAttackLogTimestamp, lastPhysicalAttackLogSequence

    if (!SaveSettings()) {
        return
    }

    isRunning := true
    targetLockActive := false
    targetAcquisitionActive := false
    targetLockName := ""
    targetLockState := "Seeking target"
    targetLockLastConfirmedAt := 0
    lastAttackAttemptAt := 0
    lastCannotSeeLogTimestamp := 0
    lastCannotSeeLogSequence := 0
    lastOutgoingDamageLogTimestamp := 0
    lastOutgoingDamageLogSequence := 0
    lastPhysicalAttackLogTimestamp := 0
    lastPhysicalAttackLogSequence := 0
    attackState := "Not attacking"
    attackTargetName := ""
    seriesIndex := 1
    multipleResumeIndex := 1
    nextTickAt := A_TickCount + GetIntervalMs()
    SetTimer Tick, 0
    SetTimer Tick, GetIntervalMs()
    if (sethMode) {
        StartNewSethCycle()
        SetTimer SethScheduler, 250
    } else {
        ClearSethScheduler()
    }
    StartLogMonitor()
    lastMessage := "Started."
    UpdateStatus()
}

StopHelper() {
    global isRunning, nextTickAt, mainActionBusy, sethActionBusy, heldSethKey, lastMessage

    isRunning := false
    nextTickAt := 0
    mainActionBusy := false
    if (heldSethKey != "") {
        SendGameKeyState(heldSethKey, false)
        heldSethKey := ""
    }
    sethActionBusy := false
    SetTimer Tick, 0
    ClearSethScheduler()
    StopLogMonitor()
    lastMessage := "Stopped."
    UpdateStatus()
}

SaveSettings() {
    global configPath, currentProfile, windowTitle, sequenceType, keyListText, intervalSeconds
    global beforeKeyDelayText, afterKeyDelayText, connectorFontSize
    global sleeperMode, sethMode, simpleSethMode
    global whenDeathAction, whenDeathValue, whenManaAction, whenManaValue
    global whenCannotSeeAction, whenCannotSeeValue, whenRotationSeconds
    global combatIdlePauseEnabled, combatIdleSeconds, configuredLogFilePath
    global windowTitleEdit, sequenceTypeDropDown, keyListEdit, intervalEdit
    global beforeKeyDelayEdit, afterKeyDelayEdit, connectorFontSizeEdit
    global sleeperModeCheckBox, sethModeCheckBox
    global simpleSethModeCheckBox, lastMessage
    global isRunning, nextTickAt, modes, modeIndex

    enteredInterval := Integer(Trim(intervalEdit.Value))
    if (enteredInterval < 1) {
        MsgBox "Interval seconds must be 1 or greater.", "AKHelper"
        return false
    }

    enteredBeforeDelayText := Trim(beforeKeyDelayEdit.Value)
    if (!ValidateDelayList(enteredBeforeDelayText)) {
        MsgBox "Delay before each key must contain only numbers 0 or greater. Use one number or a comma list like 0,5,10.", "AKHelper"
        return false
    }

    enteredAfterDelayText := Trim(afterKeyDelayEdit.Value)
    if (!ValidateDelayList(enteredAfterDelayText)) {
        MsgBox "Delay after each key must contain only numbers 0 or greater. Use one number or a comma list like 5,10,0.", "AKHelper"
        return false
    }

    parsedKeys := GetConfiguredKeys()
    if (parsedKeys.Length = 0) {
        MsgBox "Enter at least one key.", "AKHelper"
        return false
    }

    enteredConnectorFontSize := Integer(Trim(connectorFontSizeEdit.Value))
    if (enteredConnectorFontSize < 6 || enteredConnectorFontSize > 14) {
        MsgBox "Connector delay font size must be between 6 and 14.", "AKHelper"
        return false
    }

    windowTitle := Trim(windowTitleEdit.Value)
    sequenceType := sequenceTypeDropDown.Text
    keyListText := Trim(keyListEdit.Value)
    intervalSeconds := enteredInterval
    beforeKeyDelayText := NormalizeDelayListText(enteredBeforeDelayText)
    afterKeyDelayText := NormalizeDelayListText(enteredAfterDelayText)
    connectorFontSize := enteredConnectorFontSize
    sleeperMode := sleeperModeCheckBox.Value = 1
    previousSethMode := sethMode
    previousSimpleSethMode := simpleSethMode
    sethMode := sethModeCheckBox.Value = 1
    simpleSethMode := simpleSethModeCheckBox.Value = 1
    configuredLogFilePath := Trim(logFilePathEdit.Value)
    beforeKeyDelayEdit.Value := beforeKeyDelayText
    afterKeyDelayEdit.Value := afterKeyDelayText
    BuildKeyVisuals()

    section := ProfileSection(currentProfile)
    IniWrite windowTitle, configPath, section, "WindowTitle"
    IniWrite sequenceType, configPath, section, "SequenceType"
    IniWrite keyListText, configPath, section, "Keys"
    IniWrite intervalSeconds, configPath, section, "IntervalSeconds"
    IniWrite beforeKeyDelayText, configPath, section, "BeforeKeyDelaySeconds"
    IniWrite afterKeyDelayText, configPath, section, "AfterKeyDelaySeconds"
    IniWrite connectorFontSize, configPath, section, "ConnectorDelayFontSize"
    IniWrite sleeperMode ? 1 : 0, configPath, section, "SleeperMode"
    IniWrite sethMode ? 1 : 0, configPath, section, "SethMode"
    IniWrite simpleSethMode ? 1 : 0, configPath, section, "SimpleSethMode"
    IniWrite whenDeathAction, configPath, section, "WhenDeathAction"
    IniWrite whenDeathValue, configPath, section, "WhenDeathValue"
    IniWrite whenManaAction, configPath, section, "WhenManaAction"
    IniWrite whenManaValue, configPath, section, "WhenManaValue"
    IniWrite whenCannotSeeAction, configPath, section, "WhenCannotSeeAction"
    IniWrite whenCannotSeeValue, configPath, section, "WhenCannotSeeValue"
    IniWrite whenRotationSeconds, configPath, section, "WhenRotationSeconds"
    IniWrite combatIdlePauseEnabled ? 1 : 0, configPath, section, "CombatIdlePauseEnabled"
    IniWrite combatIdleSeconds, configPath, section, "CombatIdleSeconds"
    IniWrite configuredLogFilePath, configPath, section, "LogFilePath"
    IniWrite modes[modeIndex], configPath, section, "InputMethod"
    SaveProfileList()

    if (isRunning) {
        SetTimer Tick, 0
        SetTimer Tick, GetIntervalMs()
        nextTickAt := A_TickCount + GetIntervalMs()
        if (!sethMode) {
            ClearSethScheduler()
        } else if (!previousSethMode || previousSimpleSethMode != simpleSethMode) {
            ClearSethScheduler()
            StartNewSethCycle()
            SetTimer SethScheduler, 250
        }
        StartLogMonitor()
    }

    lastMessage := "Profile saved: " currentProfile "."
    UpdateStatus()
    return true
}

GetIntervalMs() {
    global intervalSeconds
    return Max(1, intervalSeconds) * 1000
}

ParseSeconds(value, fallbackValue) {
    try {
        text := Trim(value)
        if (text = "") {
            return fallbackValue
        }
        return Number(text)
    } catch {
        return fallbackValue
    }
}

ValidateDelayList(value) {
    parts := ParseDelayList(value)
    if (parts.Length = 0) {
        return true
    }

    for delaySeconds in parts {
        if (delaySeconds < 0) {
            return false
        }
    }

    return true
}

NormalizeDelayListText(value) {
    parts := ParseDelayList(value)
    if (parts.Length = 0) {
        return "0"
    }

    output := ""
    for delaySeconds in parts {
        output .= (output = "" ? "" : ",") delaySeconds
    }

    return output
}

ParseDelayList(value) {
    text := Trim(value)
    text := StrReplace(text, "`r", ",")
    text := StrReplace(text, "`n", ",")
    text := StrReplace(text, ";", ",")
    text := RegExReplace(text, "\s+", ",")
    rawParts := StrSplit(text, ",")
    parts := []

    for rawPart in rawParts {
        part := Trim(rawPart)
        if (part = "") {
            continue
        }

        parsed := ParseSeconds(part, -1)
        parts.Push(parsed)
    }

    return parts
}

GetDelayMsFor(delayText, positionIndex) {
    parts := ParseDelayList(delayText)
    if (parts.Length = 0) {
        return 0
    }

    if (parts.Length = 1) {
        return Round(Max(0, parts[1]) * 1000)
    }

    if (positionIndex > parts.Length) {
        return 0
    }

    return Round(Max(0, parts[positionIndex]) * 1000)
}

GetConfiguredKeys() {
    global keyListEdit

    text := Trim(keyListEdit.Value)
    text := StrReplace(text, "`r", ",")
    text := StrReplace(text, "`n", ",")
    text := StrReplace(text, ";", ",")
    text := RegExReplace(text, "\s+", ",")
    rawParts := StrSplit(text, ",")
    keys := []

    for rawKey in rawParts {
        key := Trim(rawKey)
        if (key != "") {
            keys.Push(key)
        }
    }

    return keys
}

WhenRulesEnabled() {
    global whenDeathAction, whenManaAction, whenCannotSeeAction, combatIdlePauseEnabled
    return whenDeathAction != "Do Nothing"
        || whenManaAction != "Do Nothing"
        || whenCannotSeeAction != "Do Nothing"
        || combatIdlePauseEnabled
}

FindNewestEqLog() {
    global logDirectory

    newestPath := ""
    newestTime := ""
    Loop Files logDirectory "\eqlog_*.txt", "F" {
        if (newestTime = "" || A_LoopFileTimeModified > newestTime) {
            newestTime := A_LoopFileTimeModified
            newestPath := A_LoopFileFullPath
        }
    }
    return newestPath
}

StartLogMonitor() {
    global isRunning, configuredLogFilePath, logFilePath, logFileHandle, lastLogEvent, logTextBuffer
    global logReadOffset, logLinesProcessed, lastLogLineAt, lastLogReadError
    global combatLastActivityAt, combatIdlePaused, combatState

    StopLogMonitor()
    if (!isRunning || !WhenRulesEnabled()) {
        return
    }

    logFilePath := configuredLogFilePath != "" ? configuredLogFilePath : FindNewestEqLog()
    if (logFilePath = "") {
        lastLogEvent := "Log monitor could not find an eqlog file."
        return
    }
    if (!FileExist(logFilePath)) {
        lastLogEvent := "Configured log file was not found: " logFilePath
        logFilePath := ""
        return
    }

    try {
        logFileHandle := FileOpen(logFilePath, "r")
        logReadOffset := FileGetSize(logFilePath)
        logFileHandle.Close()
        logFileHandle := ""
    } catch as error {
        logFileHandle := ""
        lastLogReadError := error.Message
        lastLogEvent := "Log monitor could not open: " logFilePath
        return
    }

    logTextBuffer := ""
    logLinesProcessed := 0
    lastLogLineAt := 0
    lastLogReadError := ""
    combatLastActivityAt := 0
    combatIdlePaused := false
    combatState := "Idle"
    lastLogEvent := "Watching " RegExReplace(logFilePath, ".*\\", "")
    SetTimer PollEverQuestLog, 100
}

StopLogMonitor() {
    global logFileHandle, logTextBuffer, rotationActive, reactionBusy, pendingCannotSee
    global logReadOffset, logLinesProcessed, lastLogLineAt, lastLogReadError
    global targetAcquisitionActive
    global combatIdlePaused, combatLastActivityAt, combatState

    SetTimer PollEverQuestLog, 0
    SetTimer DeferredCannotSeeCheck, 0
    StopSlowRotation("Log monitor stopped.", false)
    if (IsObject(logFileHandle)) {
        try logFileHandle.Close()
    }
    logFileHandle := ""
    logTextBuffer := ""
    logReadOffset := 0
    logLinesProcessed := 0
    lastLogLineAt := 0
    lastLogReadError := ""
    rotationActive := false
    targetAcquisitionActive := false
    reactionBusy := false
    pendingCannotSee := false
    combatIdlePaused := false
    combatLastActivityAt := 0
    combatState := "Log monitor stopped"
}

PollEverQuestLog() {
    global isRunning, logFilePath, logFileHandle, logTextBuffer
    global logReadOffset, logLinesProcessed, lastLogLineAt, lastLogReadError
    global lastLogEvent

    if (!isRunning || logFilePath = "") {
        return
    }

    try currentSize := FileGetSize(logFilePath)
    catch as error {
        lastLogReadError := error.Message
        lastLogEvent := "Could not inspect the active log file."
        QueueStatusRefresh()
        return
    }
    if (currentSize < logReadOffset) {
        ; EverQuest replaced or truncated the log. Resume from its new start.
        logReadOffset := 0
        logTextBuffer := ""
    }
    if (currentSize <= logReadOffset) {
        CheckCombatIdleTimeout()
        return
    }

    try {
        logFileHandle := FileOpen(logFilePath, "r")
        logFileHandle.Pos := logReadOffset
        newText := logFileHandle.Read(currentSize - logReadOffset)
        logReadOffset := logFileHandle.Pos
        logFileHandle.Close()
        logFileHandle := ""
        lastLogReadError := ""
    } catch as error {
        if (IsObject(logFileHandle)) {
            try logFileHandle.Close()
        }
        logFileHandle := ""
        lastLogReadError := error.Message
        lastLogEvent := "Could not read newly appended log data."
        QueueStatusRefresh()
        return
    }
    if (newText = "") {
        CheckCombatIdleTimeout()
        return
    }

    logTextBuffer .= newText
    lines := StrSplit(logTextBuffer, "`n")
    logTextBuffer := lines.Pop()
    for line in lines {
        ProcessEverQuestLogLine(Trim(line, " `t`r`n"))
        logLinesProcessed += 1
        lastLogLineAt := A_TickCount
    }
    CheckCombatIdleTimeout()
}

ProcessEverQuestLogLine(line) {
    global lastLogEvent, rotationActive, lastTargetConfirmedAt, pendingCannotSee
    global targetAcquisitionActive
    global lastOutgoingPhysicalDamageAt
    global logEventSequence, lastCannotSeeLogTimestamp, lastCannotSeeLogSequence
    global lastOutgoingDamageLogTimestamp, lastOutgoingDamageLogSequence
    global lastPhysicalAttackLogTimestamp, lastPhysicalAttackLogSequence
    global targetLockActive, targetLockName, targetLockState, targetLockLastConfirmedAt
    global lastAttackAttemptAt, attackState, attackTargetName
    global whenDeathAction, whenDeathValue, whenManaAction, whenManaValue
    global whenCannotSeeAction, whenCannotSeeValue

    if (line = "") {
        return
    }

    logEventSequence += 1
    logTimestamp := ExtractEverQuestLogTimestamp(line)

    outgoingDamage := IsOutgoingDamageLine(line)
    if (outgoingDamage) {
        outgoingPhysicalDamage := IsOutgoingPhysicalDamageLine(line)
        RecordCombatActivity("Outgoing damage")
        lastOutgoingDamageLogTimestamp := logTimestamp
        lastOutgoingDamageLogSequence := logEventSequence
        lastTargetConfirmedAt := A_TickCount
        targetLockActive := true
        targetLockLastConfirmedAt := A_TickCount
        detectedTarget := ExtractOutgoingDamageTarget(line)
        if (detectedTarget != "") {
            targetLockName := detectedTarget
            attackTargetName := detectedTarget
        }
        lastAttackAttemptAt := A_TickCount
        attackState := "Attacking - outgoing damage confirmed"
        targetLockState := "Target acquired - outgoing damage confirmed"
        lastLogEvent := targetLockState
        pendingCannotSee := false
        SetTimer DeferredCannotSeeCheck, 0
        if (outgoingPhysicalDamage) {
            lastOutgoingPhysicalDamageAt := A_TickCount
            lastPhysicalAttackLogTimestamp := logTimestamp
            lastPhysicalAttackLogSequence := logEventSequence
        }
        if (outgoingPhysicalDamage) {
            StopRotationAfterLaterPhysicalAttack(logTimestamp, logEventSequence,
                "Outgoing physical damage confirmed target acquisition; rotation stopped.")
        }
        QueueStatusRefresh()
        return
    } else if (IsOutgoingAttackAttemptLine(line)) {
        RecordCombatActivity("Outgoing physical attack attempt")
        lastAttackAttemptAt := A_TickCount
        lastPhysicalAttackLogTimestamp := logTimestamp
        lastPhysicalAttackLogSequence := logEventSequence
        targetLockActive := true
        targetLockLastConfirmedAt := A_TickCount
        attemptedTarget := ExtractOutgoingAttackTarget(line)
        if (attemptedTarget != "") {
            attackTargetName := attemptedTarget
            targetLockName := attemptedTarget
        }
        attackState := "Attacking - melee attempt detected"
        targetLockState := "Target acquired - physical attack attempted"
        lastLogEvent := targetLockState
        StopRotationAfterLaterPhysicalAttack(logTimestamp, logEventSequence,
            "Outgoing physical attack attempt confirmed target acquisition; rotation stopped.")
        QueueStatusRefresh()
    } else if (IsPlayerCombatActivityLine(line)) {
        RecordCombatActivity("Incoming damage")
    }

    if (InStr(line, "You have slain ")) {
        ReleaseTargetLock("Target defeated - seeking next target")
    } else if (InStr(line, "You must first select a target")) {
        ReleaseTargetLock("No target selected - seeking target")
    } else if (InStr(line, "You have been slain by") || InStr(line, "You died.")) {
        ReleaseTargetLock("Player died - seeking target")
        lastLogEvent := "Death detected"
        RunWhenRule("Death", whenDeathAction, whenDeathValue)
    } else if (InStr(line, "Insufficient Mana to cast this spell")) {
        lastLogEvent := "Insufficient mana detected"
        RunWhenRule("Mana", whenManaAction, whenManaValue)
    } else if (InStr(line, "You cannot see your target.")) {
        if (targetAcquisitionActive) {
            ; The first visibility-loss event owns this acquisition cycle.
            ; Later copies must not move its timestamp or restart rotation.
            return
        }
        if (targetLockActive) {
            targetLockState := "Target retained - visibility lost"
            QueueStatusRefresh()
        }
        ; This line establishes a fixed visibility-loss epoch. Only outgoing
        ; damage logged after this exact event may end the acquisition cycle.
        lastCannotSeeLogTimestamp := logTimestamp
        lastCannotSeeLogSequence := logEventSequence
        pendingCannotSee := false
        SetTimer DeferredCannotSeeCheck, 0
        lastLogEvent := "Target cannot be seen"
        RunWhenRule("CannotSee", whenCannotSeeAction, whenCannotSeeValue)
    }
}

ExtractEverQuestLogTimestamp(line) {
    static months := Map(
        "Jan", "01", "Feb", "02", "Mar", "03", "Apr", "04",
        "May", "05", "Jun", "06", "Jul", "07", "Aug", "08",
        "Sep", "09", "Oct", "10", "Nov", "11", "Dec", "12")

    if (!RegExMatch(line,
        "^\[[A-Za-z]{3}\s+([A-Za-z]{3})\s+([0-9]{1,2})\s+([0-9]{2}):([0-9]{2}):([0-9]{2})\s+([0-9]{4})\]",
        &match)) {
        return 0
    }
    monthName := match[1]
    if (!months.Has(monthName)) {
        return 0
    }
    return Integer(match[6] months[monthName] Format("{:02}", Integer(match[2]))
        match[3] match[4] match[5])
}

StopRotationAfterLaterPhysicalAttack(logTimestamp, logSequence, reason) {
    global rotationActive, lastCannotSeeLogTimestamp, lastCannotSeeLogSequence

    if (lastCannotSeeLogSequence <= 0 || logSequence <= lastCannotSeeLogSequence) {
        return false
    }
    ; Sequence resolves multiple events written during the same one-second log
    ; timestamp. A parsed earlier timestamp is never allowed to clear the epoch.
    if (logTimestamp > 0 && lastCannotSeeLogTimestamp > 0
        && logTimestamp < lastCannotSeeLogTimestamp) {
        return false
    }

    lastCannotSeeLogTimestamp := 0
    lastCannotSeeLogSequence := 0
    CompleteTargetAcquisitionPhase(reason)
    if (rotationActive) {
        StopSlowRotation(reason)
    }
    return true
}

HasPhysicalAttackAfterVisibilityLoss() {
    global lastCannotSeeLogTimestamp, lastCannotSeeLogSequence
    global lastPhysicalAttackLogTimestamp, lastPhysicalAttackLogSequence

    if (lastCannotSeeLogSequence <= 0
        || lastPhysicalAttackLogSequence <= lastCannotSeeLogSequence) {
        return false
    }
    return !(lastPhysicalAttackLogTimestamp > 0 && lastCannotSeeLogTimestamp > 0
        && lastPhysicalAttackLogTimestamp < lastCannotSeeLogTimestamp)
}

StopRotationAtCheckBoundary(reason) {
    global rotationActive
    if (!rotationActive || !HasPhysicalAttackAfterVisibilityLoss()) {
        return false
    }
    CompleteTargetAcquisitionPhase(reason)
    StopSlowRotation(reason)
    return true
}

BeginTargetAcquisitionPhase() {
    global targetAcquisitionActive, targetLockActive, targetLockState
    global attackState, lastMessage

    targetAcquisitionActive := true
    targetLockActive := false
    targetLockState := "Acquisition phase - correcting facing"
    attackState := "Acquiring target - waiting for a physical attack"
    lastMessage := "Target acquisition started after visibility loss."
    UpdateStatus()
}

CompleteTargetAcquisitionPhase(reason) {
    global targetAcquisitionActive, targetLockActive, targetLockState
    global targetLockLastConfirmedAt, attackState, lastMessage, nextTickAt

    targetAcquisitionActive := false
    targetLockActive := true
    targetLockLastConfirmedAt := A_TickCount
    targetLockState := "Target acquired - physical attack confirmed"
    attackState := "Attacking - acquisition confirmed"
    lastMessage := reason
    nextTickAt := A_TickCount + 250
    QueueStatusRefresh()
}

FailTargetAcquisitionPhase(reason) {
    global targetAcquisitionActive, targetLockActive, targetLockState
    global attackState, lastMessage, nextTickAt

    targetAcquisitionActive := false
    targetLockActive := false
    targetLockState := "Acquisition ended - seeking target"
    attackState := "Not attacking"
    lastMessage := reason
    nextTickAt := A_TickCount + GetIntervalMs()
    QueueStatusRefresh()
}

QueueStatusRefresh() {
    ; Combat logs can emit many lines in one second. Coalesce them into one
    ; near-immediate repaint without replacing the permanent live-status timer.
    SetTimer FlushQueuedStatusRefresh, -50
}

FlushQueuedStatusRefresh() {
    UpdateStatus()
}

ReleaseTargetLock(reason) {
    global targetLockActive, targetLockName, targetLockState, lastLogEvent
    global lastAttackAttemptAt, attackState, attackTargetName
    global targetAcquisitionActive, rotationActive

    targetAcquisitionActive := false
    if (rotationActive) {
        StopSlowRotation(reason, false)
    }

    targetLockActive := false
    targetLockName := ""
    targetLockState := reason
    lastAttackAttemptAt := 0
    attackState := "Not attacking"
    attackTargetName := ""
    lastLogEvent := reason
    UpdateStatus()
}

GetCombatMode() {
    global isRunning, targetAcquisitionActive
    global combatLastActivityAt, combatActiveWindowMs

    if (!isRunning || combatLastActivityAt <= 0) {
        return targetAcquisitionActive ? "Acquiring" : "Idle"
    }
    if (targetAcquisitionActive) {
        return "Acquiring"
    }
    return A_TickCount - combatLastActivityAt <= combatActiveWindowMs ? "Attacking" : "Idle"
}

GetCombatModeDescription(combatMode) {
    if (combatMode = "Acquiring") {
        return "Combat detected; correcting line of sight"
    }
    if (combatMode = "Attacking") {
        return "Combat detected; actively fighting or casting"
    }
    return "No combat detected"
}

IsOutgoingAttackAttemptLine(line) {
    return IsOutgoingDamageLine(line)
        || RegExMatch(line, "i\] You try to (?:hit|slash|crush|pierce|punch|kick|bash|reave|frenzy on) .+?, but .+!$")
}

ExtractOutgoingAttackTarget(line) {
    if (RegExMatch(line, "i\] You try to (?:hit|slash|crush|pierce|punch|kick|bash|reave|frenzy on) (.+?), but ", &match)) {
        return Trim(match[1], " `t.,!")
    }
    return ExtractOutgoingDamageTarget(line)
}

ExtractOutgoingDamageTarget(line) {
    patterns := [
        "i\] You (?:hit|slash|crush|pierce|punch|kick|bash|reave) (.+?) for [0-9]+",
        "i\] You frenzy on (.+?) for [0-9]+",
        "i\] Your .+ (?:hits|slashes|crushes|pierces|punches|kicks|bashes|bites|claws) (.+?) for [0-9]+",
        "i\] (.+?) (?:has|have) taken [0-9]+ .+damage from your .+",
        "i\] (.+?) (?:is|are) .+ by YOUR .+ for [0-9]+ .+damage"
    ]
    for pattern in patterns {
        if (RegExMatch(line, pattern, &match)) {
            return Trim(match[1], " `t.,!")
        }
    }
    return ""
}

IsTargetAcquisitionKey(keyName) {
    keyName := Trim(keyName)
    return StrLen(keyName) = 1 && Ord(keyName) = 96
}

ShouldSuppressTargetKey(keyName) {
    global targetLockActive
    return targetLockActive && IsTargetAcquisitionKey(keyName)
}

DeferredCannotSeeCheck() {
    global isRunning, pendingCannotSee, lastTargetConfirmedAt, lastLogEvent
    global whenCannotSeeAction, whenCannotSeeValue

    if (!isRunning || !pendingCannotSee) {
        return
    }

    elapsed := A_TickCount - lastTargetConfirmedAt
    if (lastTargetConfirmedAt > 0 && elapsed < 5000) {
        SetTimer DeferredCannotSeeCheck, -Max(100, 5000 - elapsed)
        return
    }

    pendingCannotSee := false
    lastLogEvent := "Target still cannot be seen after damage settled"
    RunWhenRule("CannotSee", whenCannotSeeAction, whenCannotSeeValue)
}

IsOutgoingDamageLine(line) {
    ; Match the damage sentence, rather than a fixed list of attack verbs. EQ
    ; adds verbs over time, and an unknown verb must not make combat look idle.
    return RegExMatch(line,
        "i\] You .+ for [0-9]+(?: \([0-9]+\))? points? of (?:[a-z-]+ )?damage")
        || RegExMatch(line, "i\] Your .+ (hits|slashes|crushes|pierces|punches|kicks|bashes|bites|claws) .+ for [0-9]+")
        || RegExMatch(line, "i\] .+ (has|have) taken [0-9]+ .+damage from your .+")
        || RegExMatch(line, "i\] .+ (is|are) .+ by YOUR .+ for [0-9]+ .+damage")
}

IsOutgoingPhysicalDamageLine(line) {
    ; Spell and proc lines say "magic damage" (or another typed damage).
    ; Any player-originated physical line ends with plain "points of damage",
    ; regardless of the attack verb or whether it came from a weapon/ability.
    return RegExMatch(line,
        "i\] You .+ for [0-9]+ points? of damage(?:\.| \(.+\))?$")
        || RegExMatch(line,
            "i\] Your .+ .+ for [0-9]+ points? of damage(?:\.| \(.+\))?$")
}

IsPlayerCombatActivityLine(line) {
    if (IsOutgoingDamageLine(line)) {
        return true
    }
    ; Uppercase YOU is how the log identifies the local player as the target.
    ; Matching the complete damage form catches hits, cleaves, kicks, and any
    ; other attack verb without maintaining an incomplete verb allow-list.
    return RegExMatch(line,
        "i\] .+ YOU for [0-9]+(?: \([0-9]+\))? points? of (?:[a-z-]+ )?damage")
        || RegExMatch(line, "i\] .+ hit you for [0-9]+ .+damage")
        || RegExMatch(line, "i\] You (?:have|has) taken [0-9]+ .+damage")
        || RegExMatch(line, "i\] You (?:are|were) hit by .+ for [0-9]+ .+damage")
        || InStr(line, "] You have run out of ammo!")
}

RecordCombatActivity(direction := "Combat activity") {
    global combatIdlePauseEnabled, combatLastActivityAt, combatIdlePaused
    global combatState, lastCombatDirection, lastMessage

    combatLastActivityAt := A_TickCount
    combatState := "In combat"
    lastCombatDirection := direction
    QueueStatusRefresh()
    if (combatIdlePauseEnabled && combatIdlePaused) {
        combatIdlePaused := false
        lastMessage := "Combat activity detected; resuming queued sequence."
        UpdateStatus()
        SetTimer ResumeMainQueue, -100
    }
}

CheckCombatIdleTimeout() {
    global isRunning, combatIdlePauseEnabled, combatIdleSeconds
    global combatActiveWindowMs
    global combatLastActivityAt, combatIdlePaused, combatState, lastMessage

    if (!isRunning || combatLastActivityAt <= 0) {
        return
    }
    elapsedMs := A_TickCount - combatLastActivityAt

    if (elapsedMs >= combatActiveWindowMs && combatState != "Idle") {
        combatState := "Idle"
        QueueStatusRefresh()
    }
    if (!combatIdlePauseEnabled || combatIdlePaused
        || elapsedMs < combatIdleSeconds * 1000) {
        return
    }

    combatIdlePaused := true
    combatState := "Paused after " combatIdleSeconds " seconds without combat"
    lastMessage := "Combat activity timed out; main sequence paused."
    UpdateStatus()
}

RunWhenRule(eventName, action, value) {
    global reactionLastAt, lastMessage, rotationActive

    if (action = "Do Nothing") {
        return
    }
    if (action = "Rotate Slowly Until Target" && rotationActive) {
        return
    }
    if (!IsObject(reactionLastAt)) {
        reactionLastAt := Map()
    }
    now := A_TickCount
    if (reactionLastAt.Has(eventName) && now - reactionLastAt[eventName] < 3000) {
        return
    }
    reactionLastAt[eventName] := now

    if (action = "Stop Helper") {
        lastMessage := "When " eventName " happened: stopping helper."
        StopHelper()
        return
    }

    if (!PrepareEverQuestForReaction()) {
        lastMessage := "When " eventName " happened: response waiting because EverQuest is not active."
        return
    }

    if (action = "Send Command") {
        SendEverQuestCommand(value)
        lastMessage := "When " eventName " happened: sent command " value "."
    } else if (action = "Press Key") {
        SendGameKey(value)
        lastMessage := "When " eventName " happened: pressed " value "."
    } else if (action = "Rotate Slowly Until Target") {
        StartSlowRotation(value)
        lastMessage := "When " eventName " happened: started slow rotation with " value "."
    }
    UpdateStatus()
}

PrepareEverQuestForReaction() {
    global sleeperMode, windowTitle

    gameHwnd := WinExist(windowTitle)
    if (!gameHwnd) {
        return false
    }
    if (WinExist("A") = gameHwnd) {
        return true
    }
    return sleeperMode && ActivateEverQuestForSleeper(gameHwnd)
}

SendEverQuestCommand(commandText) {
    global reactionBusy

    reactionBusy := true
    try {
        SendEvent "{Enter}"
        Sleep 100
        SendText commandText
        Sleep 100
        SendEvent "{Enter}"
    } finally {
        reactionBusy := false
    }
}

StartSlowRotation(keyName) {
    global rotationActive, rotationDeadline, rotationKey, whenRotationSeconds, reactionBusy
    global rotationNextActionAt, rotationStartedAt

    StopSlowRotation("", false)
    BeginTargetAcquisitionPhase()
    rotationKey := keyName
    ; Start the safety clock immediately so focus or scheduling problems can
    ; never leave the helper permanently trapped in rotation mode.
    rotationDeadline := A_TickCount + whenRotationSeconds * 1000
    rotationStartedAt := A_TickCount
    rotationNextActionAt := A_TickCount
    rotationActive := true
    reactionBusy := false
    SetTimer SlowRotationTick, 300
}

SlowRotationTick() {
    global isRunning, rotationActive, rotationDeadline, rotationKey
    global mainActionBusy, nextTickAt, reactionBusy
    global targetAcquisitionActive

    if (!isRunning || !rotationActive) {
        if (targetAcquisitionActive) {
            FailTargetAcquisitionPhase("Target acquisition stopped before a physical attack was confirmed.")
        }
        StopSlowRotation("Slow rotation stopped.")
        return
    }
    ; This runs again when the five-second observation window expires, before
    ; another turn pulse can begin.
    if (StopRotationAtCheckBoundary(
        "Physical attack detected during the observation window; rotation stopped.")) {
        return
    }
    ; If acquisition interrupted a key that was already being sent, wait for
    ; that single key boundary. No new main-sequence work starts during this phase.
    timeUntilMainTick := nextTickAt - A_TickCount
    if (mainActionBusy || (timeUntilMainTick > 0 && timeUntilMainTick <= 150)) {
        return
    }

    PerformSlowRotationPulse()
}

PerformSlowRotationPulse() {
    global isRunning, rotationActive, rotationDeadline, rotationKey
    global whenRotationSeconds, reactionBusy
    global rotationNextActionAt, rotationHoldingKey, targetLockState

    if (!isRunning || !rotationActive) {
        return false
    }
    if (A_TickCount >= rotationDeadline) {
        FailTargetAcquisitionPhase("Target acquisition reached its safety timeout.")
        StopSlowRotation("Slow rotation reached its safety timeout.")
        return false
    }
    if (A_TickCount < rotationNextActionAt) {
        return false
    }
    if (!PrepareEverQuestForReaction()) {
        FailTargetAcquisitionPhase("Target acquisition stopped because EverQuest is not active.")
        StopSlowRotation("Slow rotation stopped because EverQuest is not active.")
        return false
    }

    reactionBusy := true
    targetLockState := "Acquisition phase - turning " rotationKey
    UpdateStatus()
    try {
        SendGameKeyState(rotationKey, true)
        rotationHoldingKey := true
        Sleep 500
    } finally {
        SendGameKeyState(rotationKey, false)
        rotationHoldingKey := false
        reactionBusy := false
    }
    ; Check immediately after releasing the turn key. Log polling can observe
    ; an attack while the half-second key hold is sleeping.
    if (StopRotationAtCheckBoundary(
        "Physical attack detected after turning; rotation stopped.")) {
        return true
    }
    ; Leave a five-second observation window for a normal swing or shot before
    ; another half-second turn is allowed.
    targetLockState := "Acquisition phase - observing 5s for a swing or shot"
    rotationNextActionAt := A_TickCount + 5000
    UpdateStatus()
    return true
}

StopSlowRotation(reason := "", updateDisplay := true) {
    global isRunning, rotationActive, rotationKey, reactionBusy, reactionLastAt, lastMessage
    global rotationNextActionAt, rotationStartedAt, rotationHoldingKey

    SetTimer SlowRotationTick, 0
    wasActive := rotationActive
    if (rotationActive && rotationKey != "") {
        try SendGameKeyState(rotationKey, false)
    }
    ; Release both supported turn directions as a final guard against a key-down
    ; pulse being interrupted while the combat-log timer cancels rotation.
    try SendGameKeyState("Left", false)
    try SendGameKeyState("Right", false)
    rotationActive := false
    rotationNextActionAt := 0
    rotationStartedAt := 0
    rotationHoldingKey := false
    reactionBusy := false
    if (IsObject(reactionLastAt)) {
        reactionLastAt["CannotSee"] := 0
    }
    if (reason != "") {
        lastMessage := reason
        if (updateDisplay) {
            UpdateStatus()
        }
    }
}

ResumeMainQueue() {
    global isRunning, nextTickAt

    if (!isRunning) {
        return
    }
    nextTickAt := A_TickCount
    Tick()
}

Tick() {
    global isRunning, sequenceType, seriesIndex, nextTickAt
    global multipleResumeIndex, lastMessage, sleeperMode, windowTitle
    global mainActionBusy, sethActionBusy, reactionBusy, rotationActive, rotationHoldingKey, rotationKey, combatIdlePaused
    global targetAcquisitionActive

    if (!isRunning || sethActionBusy || (reactionBusy && !rotationActive)
        || combatIdlePaused || targetAcquisitionActive) {
        return
    }

    ; A newly detected acquisition phase may interrupt a key delay. Release any
    ; active turn hold before continuing normal work.
    if (rotationActive && rotationHoldingKey) {
        try SendGameKeyState(rotationKey, false)
        rotationHoldingKey := false
    }

    mainActionBusy := true
    previousTitle := GetActiveWindowTitleSafe()

    if (sleeperMode) {
        gameHwnd := WinExist(windowTitle)
        if (!gameHwnd) {
            lastMessage := "Sleeper tick skipped. EverQuest window not found: " windowTitle
            nextTickAt := A_TickCount + GetIntervalMs()
            mainActionBusy := false
            UpdateStatus()
            return
        }

        if (WinExist("A") != gameHwnd) {
            lastMessage := "Sleeper is bringing EverQuest forward..."
            UpdateStatus()
            if (!ActivateEverQuestForSleeper(gameHwnd)) {
                lastMessage := "Sleeper tick skipped. EverQuest could not receive focus."
                nextTickAt := A_TickCount + GetIntervalMs()
                mainActionBusy := false
                UpdateStatus()
                return
            }
        }
    } else if (!IsEverQuestActive(previousTitle)) {
        lastMessage := "Waiting. Active window: " previousTitle
        mainActionBusy := false
        UpdateStatus()
        return
    }

    keys := GetConfiguredKeys()
    if (keys.Length = 0) {
        lastMessage := "No keys configured."
        mainActionBusy := false
        UpdateStatus()
        return
    }

    if (sequenceType = "Multiple") {
        sent := []
        if (multipleResumeIndex < 1 || multipleResumeIndex > keys.Length) {
            multipleResumeIndex := 1
        }
        startPosition := multipleResumeIndex
        Loop keys.Length - startPosition + 1 {
            positionIndex := startPosition + A_Index - 1
            key := keys[positionIndex]
            if (ShouldSuppressTargetKey(key)) {
                sent.Push("target retained")
                multipleResumeIndex := positionIndex + 1
                continue
            }
            SendConfiguredKey(key, positionIndex)
            sent.Push(key)
            multipleResumeIndex := positionIndex + 1
            if (targetAcquisitionActive) {
                mainActionBusy := false
                lastMessage := "Main sequence paused for target acquisition."
                UpdateStatus()
                return
            }
            if (combatIdlePaused) {
                mainActionBusy := false
                nextTickAt := 0
                lastMessage := "Main sequence paused after key " positionIndex
                    . " because combat activity timed out."
                UpdateStatus()
                return
            }
            TryRunSethQueue()
        }
        multipleResumeIndex := 1
        lastMessage := (sleeperMode ? "Sleeper sent sequence: " : "Sent sequence: ") JoinKeys(sent) "."
    } else {
        if (seriesIndex > keys.Length) {
            seriesIndex := 1
        }

        key := keys[seriesIndex]
        if (ShouldSuppressTargetKey(key)) {
            originalIndex := seriesIndex
            Loop keys.Length {
                seriesIndex := Mod(seriesIndex, keys.Length) + 1
                key := keys[seriesIndex]
                if (!ShouldSuppressTargetKey(key)) {
                    break
                }
            }
            if (ShouldSuppressTargetKey(key)) {
                lastMessage := "Target retained; no non-target key is configured."
                nextTickAt := A_TickCount + GetIntervalMs()
                mainActionBusy := false
                UpdateStatus()
                return
            }
        }
        SendConfiguredKey(key, seriesIndex)
        if (targetAcquisitionActive) {
            mainActionBusy := false
            lastMessage := "Main sequence paused for target acquisition."
            UpdateStatus()
            return
        }
        if (combatIdlePaused) {
            seriesIndex += 1
            mainActionBusy := false
            nextTickAt := 0
            lastMessage := "Series paused because combat activity timed out."
            UpdateStatus()
            return
        }
        TryRunSethQueue()
        lastMessage := (sleeperMode ? "Sleeper sent series key " : "Sent series key ") seriesIndex " of " keys.Length ": " key "."
        seriesIndex += 1
    }

    nextTickAt := A_TickCount + GetIntervalMs()
    mainActionBusy := false
    TryRunSethQueue()
    UpdateStatus()
}

StartNewSethCycle() {
    global isRunning, sethMode, simpleSethMode
    global sethCycleStartedAt, sethTriggerAt, sethCycleEndsAt
    global sethSelectedAction, sethActionQueued

    if (!isRunning || !sethMode) {
        return
    }

    sethCycleStartedAt := A_TickCount
    sethCycleEndsAt := sethCycleStartedAt + 300000
    sethTriggerAt := sethCycleStartedAt + Random(1, 300) * 1000
    actions := simpleSethMode ? ["Space"] : ["Space", "W/S", "S/W", "A/D", "D/A"]
    sethSelectedAction := actions[Random(1, actions.Length)]
    sethActionQueued := false
}

ClearSethScheduler() {
    global sethCycleStartedAt, sethTriggerAt, sethCycleEndsAt
    global sethSelectedAction, sethActionQueued, sethQueue

    SetTimer SethScheduler, 0
    sethCycleStartedAt := 0
    sethTriggerAt := 0
    sethCycleEndsAt := 0
    sethSelectedAction := ""
    sethActionQueued := false
    sethQueue := []
}

SethScheduler() {
    global isRunning, sethMode, sethTriggerAt, sethCycleEndsAt
    global sethSelectedAction, sethActionQueued, sethQueue

    if (!isRunning || !sethMode) {
        ClearSethScheduler()
        return
    }

    now := A_TickCount
    if (!sethActionQueued && sethTriggerAt > 0 && now >= sethTriggerAt) {
        sethQueue.Push(sethSelectedAction)
        sethActionQueued := true
    }

    while (sethCycleEndsAt > 0 && now >= sethCycleEndsAt) {
        StartNewSethCycle()
        now := A_TickCount
    }

    TryRunSethQueue()
}

TryRunSethQueue() {
    global isRunning, sethMode, sethQueue, mainActionBusy, nextTickAt
    global sleeperMode, windowTitle, lastMessage, sethActionBusy, reactionBusy
    global rotationActive, combatIdlePaused

    if (!isRunning || !sethMode || sethActionBusy || reactionBusy
        || rotationActive || combatIdlePaused || sethQueue.Length = 0) {
        return false
    }

    ; A due main tick always wins. While a main sequence is active, this function
    ; is called only at the explicit boundaries after each complete main action.
    if (!mainActionBusy && nextTickAt > 0 && A_TickCount >= nextTickAt) {
        return false
    }

    if (sleeperMode) {
        gameHwnd := WinExist(windowTitle)
        if (!gameHwnd || (WinExist("A") != gameHwnd && !ActivateEverQuestForSleeper(gameHwnd))) {
            return false
        }
    } else if (!IsEverQuestActive()) {
        return false
    }

    action := sethQueue.RemoveAt(1)
    sethActionBusy := true
    try {
        RunSethAction(action)
    } finally {
        sethActionBusy := false
    }
    lastMessage := "Seth action completed: " action "."
    return true
}

RunSethAction(action) {
    if (action = "Space") {
        SendGameKey("Space")
        return
    }

    parts := StrSplit(action, "/")
    if (parts.Length != 2) {
        return
    }

    durationMs := Random(1000, 3000)
    HoldGameKey(parts[1], durationMs)
    HoldGameKey(parts[2], durationMs)
}

HoldGameKey(keyName, durationMs) {
    global heldSethKey

    heldSethKey := keyName
    SendGameKeyState(keyName, true)
    try {
        Sleep durationMs
    } finally {
        SendGameKeyState(keyName, false)
        heldSethKey := ""
    }
}

SendGameKeyState(keyName, isDown) {
    global modeIndex, modes

    mode := modes[modeIndex]
    normalizedKey := NormalizeKeyName(keyName)
    state := isDown ? "down" : "up"
    if (mode = "SendEvent") {
        SendEvent "{" normalizedKey " " state "}"
    } else if (mode = "SendInput") {
        SendInput "{" normalizedKey " " state "}"
    } else if (mode = "ControlSend") {
        hwnd := WinGetID("A")
        ControlSend "{" normalizedKey " " state "}", , "ahk_id " hwnd
    } else if (mode = "PostMessage") {
        vk := GetVirtualKey(normalizedKey)
        if (vk = 0) {
            SendEvent "{" normalizedKey " " state "}"
        } else {
            hwnd := WinGetID("A")
            PostMessage (isDown ? 0x0100 : 0x0101), vk, 0, , "ahk_id " hwnd
        }
    }
}

ActivateEverQuestForSleeper(gameHwnd) {
    Loop 3 {
        try WinRestore "ahk_id " gameHwnd
        WinActivate "ahk_id " gameHwnd
        if (WinWaitActive("ahk_id " gameHwnd, , 0.75)) {
            Sleep 150
            return true
        }
        Sleep 150
    }
    return false
}

IsEverQuestActive(activeTitle := "") {
    global windowTitle

    if (activeTitle = "") {
        activeTitle := GetActiveWindowTitleSafe()
    }

    return InStr(activeTitle, windowTitle)
}

GetActiveWindowTitleSafe() {
    try {
        return WinGetTitle("A")
    } catch TargetError {
        return ""
    }
}

SendGameKey(keyName) {
    global modeIndex, modes

    mode := modes[modeIndex]
    normalizedKey := NormalizeKeyName(keyName)

    if (mode = "SendEvent") {
        SendEvent "{" normalizedKey " down}"
        Sleep 75
        SendEvent "{" normalizedKey " up}"
    } else if (mode = "SendInput") {
        SendInput "{" normalizedKey " down}"
        Sleep 75
        SendInput "{" normalizedKey " up}"
    } else if (mode = "ControlSend") {
        hwnd := WinGetID("A")
        ControlSend "{" normalizedKey " down}", , "ahk_id " hwnd
        Sleep 75
        ControlSend "{" normalizedKey " up}", , "ahk_id " hwnd
    } else if (mode = "PostMessage") {
        vk := GetVirtualKey(normalizedKey)
        if (vk = 0) {
            SendEvent "{" normalizedKey " down}"
            Sleep 75
            SendEvent "{" normalizedKey " up}"
            return
        }

        hwnd := WinGetID("A")
        PostMessage 0x0100, vk, 0, , "ahk_id " hwnd
        Sleep 75
        PostMessage 0x0101, vk, 0, , "ahk_id " hwnd
    }
}

SendConfiguredKey(keyName, positionIndex := 1) {
    global beforeKeyDelayText, afterKeyDelayText

    beforeMs := GetDelayMsFor(beforeKeyDelayText, positionIndex)
    if (beforeMs > 0) {
        SleepWithKeyCountdown(positionIndex, beforeMs, "Fires in")
    }

    FlashKeyVisual(positionIndex)
    SetKeyTimingText(positionIndex, "Pressed", "cB45309")
    SendGameKey(keyName)

    afterMs := GetDelayMsFor(afterKeyDelayText, positionIndex)
    if (afterMs > 0) {
        SleepWithKeyCountdown(positionIndex, afterMs, "Next in")
    }
    SetKeyTimingText(positionIndex, GetConfiguredTimingLabel(positionIndex))
}

SleepWithKeyCountdown(positionIndex, durationMs, prefix) {
    endTick := A_TickCount + durationMs
    connectorIndex := (prefix = "Fires in") ? positionIndex - 1 : positionIndex
    while ((remaining := endTick - A_TickCount) > 0) {
        SetKeyTimingText(positionIndex, prefix " " Format("{:.1f}", remaining / 1000) "s", "cB45309")
        if (connectorIndex > 0) {
            SetKeyConnectorText(connectorIndex, "-" Format("{:.1f}", remaining / 1000) "s>", "cB45309")
        }
        Sleep Min(100, remaining)
    }
    if (connectorIndex > 0) {
        SetKeyConnectorText(connectorIndex, GetTransitionTimingLabel(connectorIndex))
    }
}

GetConfiguredTimingLabel(positionIndex) {
    global beforeKeyDelayText, afterKeyDelayText

    beforeSeconds := GetDelayMsFor(beforeKeyDelayText, positionIndex) / 1000
    afterSeconds := GetDelayMsFor(afterKeyDelayText, positionIndex) / 1000
    return "B" Format("{:g}", beforeSeconds) "  A" Format("{:g}", afterSeconds)
}

GetTransitionTimingLabel(positionIndex) {
    global beforeKeyDelayText, afterKeyDelayText

    keys := GetConfiguredKeys()
    if (positionIndex < 1 || positionIndex >= keys.Length) {
        return ""
    }

    gapSeconds := (GetDelayMsFor(afterKeyDelayText, positionIndex)
        + GetDelayMsFor(beforeKeyDelayText, positionIndex + 1)) / 1000
    arrow := (Mod(positionIndex, 5) = 0) ? "v" : ">"
    return "-" Format("{:g}", gapSeconds) "s" arrow
}

SetKeyTimingText(positionIndex, textValue, colorOption := "c64748B") {
    global keyVisualTimingControls

    if (positionIndex < 1 || positionIndex > keyVisualTimingControls.Length) {
        return
    }

    control := keyVisualTimingControls[positionIndex]
    control.Value := textValue
    control.SetFont("s6 " colorOption, "Segoe UI")
    control.Redraw()
}

SetKeyConnectorText(positionIndex, textValue, colorOption := "c64748B") {
    global keyVisualConnectorControls, connectorFontSize

    if (positionIndex < 1 || positionIndex > keyVisualConnectorControls.Length) {
        return
    }

    control := keyVisualConnectorControls[positionIndex]
    control.Value := textValue
    control.SetFont("s" connectorFontSize " bold " colorOption, "Segoe UI")
    control.Redraw()
}

BuildKeyVisuals() {
    global helperGui, keyVisualControls, keyVisualTimingControls
    global keyVisualConnectorControls, keyVisualStartY, connectorFontSize
    global startButton, stopButton, applyButton, testButton, statusText

    keys := GetConfiguredKeys()
    requiredControls := Max(keys.Length, 1)

    while (keyVisualControls.Length < requiredControls) {
        control := helperGui.AddText("x0 y0 w48 h34 Center Border +0x200 BackgroundF3F4F6 Hidden", "")
        control.SetFont("s11 bold c1F2937", "Segoe UI")
        keyVisualControls.Push(control)

        timingControl := helperGui.AddText("x0 y0 w48 h16 Center +0x200 Hidden", "")
        timingControl.SetFont("s6 c64748B", "Segoe UI")
        keyVisualTimingControls.Push(timingControl)

        connectorControl := helperGui.AddText("x0 y0 w55 h24 Center +0x200 Hidden", "")
        connectorControl.SetFont("s" connectorFontSize " bold c64748B", "Segoe UI")
        keyVisualConnectorControls.Push(connectorControl)
    }

    for index, control in keyVisualControls {
        if (index <= keys.Length) {
            column := Mod(index - 1, 5)
            row := Floor((index - 1) / 5)
            xPosition := 8 + (column * 104)
            yPosition := keyVisualStartY + (row * 58)
            control.Move(xPosition, yPosition, 48, 34)
            control.Value := keys[index]
            control.Opt("+BackgroundF3F4F6")
            control.SetFont("s11 bold c1F2937", "Segoe UI")
            control.Visible := true

            timingControl := keyVisualTimingControls[index]
            timingControl.Move(xPosition, yPosition + 36, 48, 16)
            timingControl.Value := GetConfiguredTimingLabel(index)
            timingControl.SetFont("s6 c64748B", "Segoe UI")
            timingControl.Visible := true

            connectorControl := keyVisualConnectorControls[index]
            if (index < keys.Length) {
                connectorControl.Move(xPosition + 49, yPosition + 5, 55, 24)
                connectorControl.Value := GetTransitionTimingLabel(index)
                connectorControl.SetFont("s" connectorFontSize " bold c64748B", "Segoe UI")
                connectorControl.Visible := true
            } else {
                connectorControl.Visible := false
            }
        } else {
            control.Visible := false
            keyVisualTimingControls[index].Visible := false
            keyVisualConnectorControls[index].Visible := false
        }
    }

    rowCount := Ceil(requiredControls / 5)
    actionY := keyVisualStartY + (rowCount * 58) + 4
    startButton.Move(8, actionY, 78)
    stopButton.Move(94, actionY, 78)
    applyButton.Move(180, actionY, 78)
    testButton.Move(266, actionY, 78)
    statusText.Move(8, actionY + 38, 520, 215)
}

FlashKeyVisual(positionIndex) {
    global keyVisualControls

    if (positionIndex < 1 || positionIndex > keyVisualControls.Length) {
        return
    }

    control := keyVisualControls[positionIndex]
    control.Opt("+BackgroundF59E0B")
    control.SetFont("s11 bold cFFFFFF", "Segoe UI")
    control.Redraw()
    SetTimer ((*) => ResetKeyVisual(positionIndex)), -300
}

ResetKeyVisual(positionIndex) {
    global keyVisualControls

    if (positionIndex < 1 || positionIndex > keyVisualControls.Length) {
        return
    }

    control := keyVisualControls[positionIndex]
    control.Opt("+BackgroundF3F4F6")
    control.SetFont("s11 bold c1F2937", "Segoe UI")
    control.Redraw()
}

NormalizeKeyName(keyName) {
    key := Trim(keyName)

    lower := StrLower(key)
    arrowKeys := Map(
        "left", "Left",
        "left arrow", "Left",
        "leftarrow", "Left",
        "right", "Right",
        "right arrow", "Right",
        "rightarrow", "Right",
        "up", "Up",
        "up arrow", "Up",
        "uparrow", "Up",
        "down", "Down",
        "down arrow", "Down",
        "downarrow", "Down"
    )
    if (arrowKeys.Has(lower)) {
        return arrowKeys[lower]
    }

    if (RegExMatch(lower, "^numpad([0-9])$", &match)) {
        return "Numpad" match[1]
    }

    if (RegExMatch(lower, "^f([1-9]|1[0-2])$", &match)) {
        return "F" match[1]
    }

    return key
}

GetVirtualKey(keyName) {
    upper := StrUpper(keyName)

    arrowVirtualKeys := Map(
        "LEFT", 0x25,
        "UP", 0x26,
        "RIGHT", 0x27,
        "DOWN", 0x28
    )
    if (arrowVirtualKeys.Has(upper)) {
        return arrowVirtualKeys[upper]
    }

    if (RegExMatch(upper, "^[0-9]$")) {
        return Ord(upper)
    }

    if (RegExMatch(upper, "^[A-Z]$")) {
        return Ord(upper)
    }

    if (RegExMatch(upper, "^F([1-9]|1[0-2])$", &match)) {
        return 0x70 + Integer(match[1]) - 1
    }

    if (RegExMatch(upper, "^NUMPAD([0-9])$", &match)) {
        return 0x60 + Integer(match[1])
    }

    return 0
}

JoinKeys(keys) {
    output := ""
    for key in keys {
        output .= (output = "" ? "" : ", ") key
    }
    return output
}

UpdateStatus() {
    global appVersion
    global statusText, currentProfile, windowTitle, sequenceType, intervalSeconds
    global beforeKeyDelayText, afterKeyDelayText, connectorFontSize
    global sleeperMode, sethMode, simpleSethMode, modes, modeIndex
    global isRunning, nextTickAt, lastMessage, seriesIndex
    global sethTriggerAt, sethCycleEndsAt, sethSelectedAction, sethQueue
    global logFilePath, lastLogEvent, rotationActive
    global logLinesProcessed, lastLogLineAt, lastLogReadError
    global whenDeathAction, whenManaAction, whenCannotSeeAction
    global combatIdlePauseEnabled, combatIdleSeconds, combatIdlePaused
    global combatLastActivityAt, combatActiveWindowMs, combatState
    global lastCombatDirection
    global targetLockActive, targetLockName, targetLockState, targetLockLastConfirmedAt
    global targetAcquisitionActive
    global lastAttackAttemptAt, attackState, attackTargetName

    keys := GetConfiguredKeys()
    activeTitle := GetActiveWindowTitleSafe()
    state := isRunning ? (combatIdlePaused ? "Paused - waiting for combat" : "Running") : "Stopped"
    combatMode := GetCombatMode()
    combatModeDescription := GetCombatModeDescription(combatMode)
    nextAction := "Not scheduled"
    if (isRunning && nextTickAt > 0) {
        remainingSeconds := Max(0, nextTickAt - A_TickCount) / 1000
        nextAction := Format("{:.1f} seconds", remainingSeconds)
    }
    if (targetAcquisitionActive) {
        nextAction := "Main sequence paused until target acquisition finishes"
    }
    sleeperState := sleeperMode
        ? "On - EverQuest will be brought forward and left focused"
        : "Off - keys are sent only while EverQuest is already active"
    seriesText := (sequenceType = "Interval Series")
        ? "Next key position " seriesIndex " of " keys.Length
        : "All configured keys on each interval"
    sethState := "Off"
    if (sethMode) {
        sethState := simpleSethMode ? "On - Simple (Space only)" : "On - Full actions"
        if (isRunning && sethTriggerAt > 0) {
            triggerRemaining := Max(0, sethTriggerAt - A_TickCount) / 1000
            cycleRemaining := Max(0, sethCycleEndsAt - A_TickCount) / 1000
            sethState .= "`r`nSeth selected: " sethSelectedAction
                . " | trigger in " Format("{:.1f}", triggerRemaining) "s"
                . " | cycle in " Format("{:.1f}", cycleRemaining) "s"
                . " | queued: " sethQueue.Length
        }
    }
    logState := WhenRulesEnabled()
        ? (logFilePath != "" ? "On - " RegExReplace(logFilePath, ".*\\", "") : "Configured - log not open")
        : "Off - no active rules"
    logInputStatus := logLinesProcessed " new lines processed"
    if (lastLogLineAt > 0) {
        logInputStatus .= " | last line " Format("{:.1f}", Max(0, A_TickCount - lastLogLineAt) / 1000) "s ago"
    }
    if (lastLogReadError != "") {
        logInputStatus .= " | READ ERROR: " lastLogReadError
    }
    combatStatus := "No recent incoming or outgoing damage"
    if (combatLastActivityAt > 0) {
        combatAge := Max(0, A_TickCount - combatLastActivityAt) / 1000
        combatStatus := combatAge <= combatActiveWindowMs / 1000
            ? "In combat - " lastCombatDirection " " Format("{:.1f}", combatAge) "s ago"
            : "No recent damage - last " lastCombatDirection " " Format("{:.1f}", combatAge) "s ago"
        if (combatIdlePauseEnabled) {
            combatStatus .= " | pause timeout " combatIdleSeconds "s"
        }
    }
    if (isRunning && combatIdlePauseEnabled && !combatIdlePaused && combatLastActivityAt > 0) {
        idleFor := Max(0, A_TickCount - combatLastActivityAt) / 1000
        combatStatus .= " | idle " Format("{:.1f}", idleFor) "s"
    }
    targetNameText := targetLockName != "" ? targetLockName : "Unknown (log did not name it)"
    targetAgeText := "Never"
    if (targetLockLastConfirmedAt > 0) {
        targetAgeText := Format("{:.1f} seconds ago", Max(0, A_TickCount - targetLockLastConfirmedAt) / 1000)
    }
    attackStatus := "Not attacking"
    if (lastAttackAttemptAt > 0) {
        attackAge := Max(0, A_TickCount - lastAttackAttemptAt) / 1000
        if (targetLockActive && attackAge <= 6) {
            attackStatus := attackState " | " Format("{:.1f}", attackAge) "s ago"
        } else if (targetLockActive) {
            attackStatus := "Target acquired, but no outgoing attack for " Format("{:.1f}", attackAge) "s"
        }
    }
    if (attackTargetName != "") {
        attackStatus .= " | " attackTargetName
    }

    statusText.Value :=
    (
        "AKHELPER v" appVersion "`r`n"
        "RUN STATUS`r`n"
        "State: " state "`r`n"
        "Next action in: " nextAction "`r`n"
        "Last event: " lastMessage "`r`n`r`n"
        "TARGET AND COMBAT`r`n"
        "State: " combatMode " - " combatModeDescription "`r`n"
        "Target name: " targetNameText "`r`n"
        "Target state: " targetLockState "`r`n"
        "Last outgoing damage: " targetAgeText "`r`n"
        "Attack state: " attackStatus "`r`n"
        "Combat: " combatStatus "`r`n`r`n"
        "SEQUENCE`r`n"
        "Profile: " currentProfile "`r`n"
        "Mode: " sequenceType " - " seriesText "`r`n"
        "Keys: " JoinKeys(keys) "`r`n"
        "Interval: " intervalSeconds " seconds`r`n"
        "Per-key delay: before [" beforeKeyDelayText "], after [" afterKeyDelayText "] seconds`r`n`r`n"
        "Connector delay font: " connectorFontSize " pt`r`n`r`n"
        "WINDOW CONTROL`r`n"
        "Sleeper: " sleeperState "`r`n"
        "Seth Mode: " sethState "`r`n"
        "Target title: " windowTitle "`r`n"
        "Active window: " activeTitle "`r`n"
        "Input method: " modes[modeIndex] "`r`n`r`n"
        "WHEN... HAPPENS`r`n"
        "Log monitor: " logState "`r`n"
        "Log input: " logInputStatus "`r`n"
        "Last log event: " lastLogEvent "`r`n"
        "Death: " whenDeathAction " | Mana: " whenManaAction " | Cannot see: " whenCannotSeeAction "`r`n"
        "Target acquisition: " (targetAcquisitionActive
            ? (rotationActive ? "Active - turn 0.5s, observe 5s, repeat" : "Starting")
            : "Inactive") "`r`n`r`n"
        "COMBAT ACTIVITY`r`n"
        "Idle pause: " combatStatus "`r`n`r`n"
        "SHORTCUTS`r`n"
        "F6: test now    F7: switch method    Ctrl+Esc: stop"
    )
}

RefreshLiveStatus() {
    global isRunning
    if (isRunning) {
        UpdateStatus()
    }
}

TestNow() {
    global sequenceType, lastMessage

    if (!SaveSettings()) {
        return
    }

    activeTitle := GetActiveWindowTitleSafe()
    if (!IsEverQuestActive(activeTitle)) {
        lastMessage := "Manual test skipped. Active window: " activeTitle
        UpdateStatus()
        return
    }

    keys := GetConfiguredKeys()
    if (keys.Length = 0) {
        lastMessage := "Manual test skipped. No keys configured."
        UpdateStatus()
        return
    }

    if (sequenceType = "Multiple") {
        sent := []
        for key in keys {
            SendConfiguredKey(key, A_Index)
            sent.Push(key)
        }
        lastMessage := "Manual test sent sequence: " JoinKeys(sent) "."
    } else {
        SendConfiguredKey(keys[1], 1)
        lastMessage := "Manual test sent first series key: " keys[1] "."
    }

    UpdateStatus()
}

F6::TestNow()

F7:: {
    global modeIndex, modes, lastMessage

    modeIndex += 1
    if (modeIndex > modes.Length) {
        modeIndex := 1
    }

    lastMessage := "Switched input method to " modes[modeIndex] "."
    UpdateStatus()
}

^Esc::ExitApp
