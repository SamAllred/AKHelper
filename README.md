# AKHelper

Configurable AutoHotkey v2 key sequence helper with named profiles, per-key timing, log-aware actions, and launch-time updates.

## Install

Download `AKHelper_Full.zip` from the latest GitHub Release, extract it, and run `Install_EverQuest_Key_Helper.ps1` in PowerShell.

On each launch, the helper checks the latest GitHub Release. If a newer semantic version is available, it asks before downloading, installing, and restarting. A failed or offline update check never blocks startup.

## Publish a release

1. Update `appVersion` in `EverQuest_Key_Helper.ahk`.
2. Put the same version in `VERSION` without a leading `v`.
3. Commit and push the changes.
4. Tag that commit and push the tag:

```powershell
git tag v1.4.4
git push origin main
git push origin v1.4.4
```

The release workflow creates `AKHelper_Update.zip` and `AKHelper_Full.zip`. It also publishes `EverQuest_Key_Helper_Update.zip` temporarily so installations from before the rename can update safely.
