# Deploy-AVDTasks.ps1
# Master deployment script for Azure blob - drops scripts and creates scheduled tasks

$scriptRoot = "C:\ProgramData\Intune\Scripts"
$logDir = "C:\ProgramData\Intune\Logs"

# Create directories
if (-not (Test-Path $scriptRoot)) { New-Item -Path $scriptRoot -ItemType Directory -Force | Out-Null }
if (-not (Test-Path $logDir)) { New-Item -Path $logDir -ItemType Directory -Force | Out-Null }

# ============================================================
# Script 1: Office Shortcuts (runs at startup via scheduled task)
# ============================================================
$officeShortcutsScript = @'
Start-Sleep -Seconds 120

$logDir = "C:\ProgramData\Intune\Logs"
if (-not (Test-Path $logDir)) { New-Item -Path $logDir -ItemType Directory -Force | Out-Null }
$logPath = "$logDir\OfficeShortcuts-Install.log"
$timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

$officePaths = @(
    "${env:ProgramFiles}\Microsoft Office\root\Office16",
    "${env:ProgramFiles(x86)}\Microsoft Office\root\Office16"
)

$officePath = $officePaths | Where-Object { Test-Path $_ } | Select-Object -First 1

if (-not $officePath) {
    Add-Content -Path $logPath -Value "$timestamp - Office not found, exiting"
    exit
}

Add-Content -Path $logPath -Value "$timestamp - Office found at: $officePath"

$publicDesktop = "$env:PUBLIC\Desktop"
$WshShell = New-Object -ComObject WScript.Shell

$apps = @{
    "Word"    = "WINWORD.EXE"
    "Excel"   = "EXCEL.EXE"
    "Outlook" = "OUTLOOK.EXE"
    "Access"  = "MSACCESS.EXE"
    "Teams"   = $null
}

foreach ($app in $apps.GetEnumerator()) {
    $shortcutPath = Join-Path $publicDesktop "$($app.Key).lnk"
    
    if ($app.Key -eq "Teams") {
        $teamsPath = "$env:ProgramFiles\WindowsApps\MSTeams_*\ms-teams.exe"
        $teamsExe = Get-Item $teamsPath -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($teamsExe -and -not (Test-Path $shortcutPath)) {
            $shortcut = $WshShell.CreateShortcut($shortcutPath)
            $shortcut.TargetPath = $teamsExe.FullName
            $shortcut.Save()
            Add-Content -Path $logPath -Value "$timestamp - Created Teams shortcut"
        }
    }
    else {
        $exePath = Join-Path $officePath $app.Value
        if ((Test-Path $exePath) -and -not (Test-Path $shortcutPath)) {
            $shortcut = $WshShell.CreateShortcut($shortcutPath)
            $shortcut.TargetPath = $exePath
            $shortcut.Save()
            Add-Content -Path $logPath -Value "$timestamp - Created $($app.Key) shortcut"
        }
    }
}
'@

Set-Content -Path "$scriptRoot\Create-OfficeShortcuts.ps1" -Value $officeShortcutsScript -Force

# Register scheduled task for Office shortcuts
$action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$scriptRoot\Create-OfficeShortcuts.ps1`""
$trigger = New-ScheduledTaskTrigger -AtStartup
$principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest
Register-ScheduledTask -TaskName "Create Office 365 Shortcuts" -Action $action -Trigger $trigger -Principal $principal -Description "Creates Office 365 shortcuts on public desktop at startup" -Force

# ============================================================
# Script 2: AVD Notifications Fix (runs at startup via scheduled task)
# ============================================================
$notificationsScript = @'
Start-Sleep -Seconds 60

$logPath = "C:\ProgramData\Intune\Logs\AVD-Notifications-Install.log"
$timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

Add-Content -Path $logPath -Value "$timestamp - Starting AVD Notification Fix"

# Fix 1: HKLM Policy PushNotifications
$LMPolicyPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\CurrentVersion\PushNotifications"
if (Test-Path $LMPolicyPath) {
    Set-ItemProperty -Path $LMPolicyPath -Name "NoCloudApplicationNotification" -Value 0 -Force -ErrorAction SilentlyContinue
    Set-ItemProperty -Path $LMPolicyPath -Name "NoToastApplicationNotification" -Value 0 -Force -ErrorAction SilentlyContinue
    Add-Content -Path $logPath -Value "$timestamp - HKLM policies updated"
}

# Fix 2: HKCU Policy PushNotifications (all loaded user profiles)
$ProfileList = Get-ChildItem "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList" |
    Where-Object { $_.PSChildName -match '^S-1-5-21-' }

$ProfileCount = 0
foreach ($Profile in $ProfileList) {
    $SID = $Profile.PSChildName
    $HKUPath = "Registry::HKU\$SID\SOFTWARE\Policies\Microsoft\Windows\CurrentVersion\PushNotifications"
    
    if (Test-Path $HKUPath) {
        Set-ItemProperty -Path $HKUPath -Name "NoToastApplicationNotification" -Value 0 -Force -ErrorAction SilentlyContinue
        Set-ItemProperty -Path $HKUPath -Name "NoToastApplicationNotificationOnLockScreen" -Value 0 -Force -ErrorAction SilentlyContinue
        $ProfileCount++
    }
}
Add-Content -Path $logPath -Value "$timestamp - Fixed $ProfileCount user profile(s)"

# Fix 3: HKLM Explorer NoNewAppAlert
$LMExplorerPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Explorer"
if (Test-Path $LMExplorerPath) {
    Set-ItemProperty -Path $LMExplorerPath -Name "NoNewAppAlert" -Value 0 -Force -ErrorAction SilentlyContinue
}

# Fix 4: Enable system-level notification settings
$LMPushPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\PushNotifications"
if (-not (Test-Path $LMPushPath)) {
    New-Item -Path $LMPushPath -Force | Out-Null
}
Set-ItemProperty -Path $LMPushPath -Name "ToastEnabled" -Value 1 -Force
Set-ItemProperty -Path $LMPushPath -Name "EnableMultiUser" -Value 1 -Type DWord -Force
Add-Content -Path $logPath -Value "$timestamp - System notification settings enabled"

# Fix 5: Restart Windows Push Notification Service
$WpnService = Get-Service -Name "WpnService" -ErrorAction SilentlyContinue
if ($WpnService) {
    if ($WpnService.Status -ne "Running") {
        Start-Service -Name "WpnService" -ErrorAction SilentlyContinue
    }
    Restart-Service -Name "WpnService" -Force -ErrorAction SilentlyContinue
    Add-Content -Path $logPath -Value "$timestamp - WpnService restarted"
}

Add-Content -Path $logPath -Value "$timestamp - AVD Notification Fix completed"
'@

Set-Content -Path "$scriptRoot\Fix-AVD-Notifications.ps1" -Value $notificationsScript -Force

# Register scheduled task for AVD notifications
$notifyAction = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$scriptRoot\Fix-AVD-Notifications.ps1`""
$notifyTrigger = New-ScheduledTaskTrigger -AtStartup
$notifyPrincipal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest
Register-ScheduledTask -TaskName "Fix AVD Notifications" -Action $notifyAction -Trigger $notifyTrigger -Principal $notifyPrincipal -Description "Fixes AVD notification settings at startup" -Force

# ============================================================
# Script 3: Drive Mapping (runs at logon via scheduled task)
# ============================================================
$driveMappingScript = @'
$DriveLetter = "T"
$UNCPath = "\\avd-fs-01\data"

# Remove existing if present
if (Test-Path "$($DriveLetter):") {
    Remove-PSDrive -Name $DriveLetter -Force -ErrorAction SilentlyContinue
    net use "$($DriveLetter):" /delete /y 2>$null
}

# Map the drive
try {
    New-PSDrive -Name $DriveLetter -PSProvider FileSystem -Root $UNCPath -Persist -Scope Global -ErrorAction Stop
} catch {
    net use "$($DriveLetter):" $UNCPath /persistent:yes
}
'@

Set-Content -Path "$scriptRoot\MapDrives.ps1" -Value $driveMappingScript -Force

# Remove existing drive mapping task if present
Unregister-ScheduledTask -TaskName "IntuneDriveMapping" -Confirm:$false -ErrorAction SilentlyContinue

# Register scheduled task for drive mapping
$driveAction = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-ExecutionPolicy Bypass -WindowStyle Hidden -File `"$scriptRoot\MapDrives.ps1`""
$driveTrigger = New-ScheduledTaskTrigger -AtLogOn
$drivePrincipal = New-ScheduledTaskPrincipal -GroupId "S-1-5-32-545" -RunLevel Limited
$driveSettings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable
Register-ScheduledTask -TaskName "IntuneDriveMapping" -Action $driveAction -Trigger $driveTrigger -Principal $drivePrincipal -Settings $driveSettings -Force

# ============================================================
# Summary
# ============================================================
$summaryLog = "C:\ProgramData\Intune\Logs\Deploy-AVDTasks.log"
$timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
Add-Content -Path $summaryLog -Value "$timestamp - Deployment completed"
Add-Content -Path $summaryLog -Value "  - Create-OfficeShortcuts.ps1 (scheduled task: at startup, SYSTEM)"
Add-Content -Path $summaryLog -Value "  - Fix-AVD-Notifications.ps1 (scheduled task: at startup, SYSTEM)"
Add-Content -Path $summaryLog -Value "  - MapDrives.ps1 (scheduled task: at logon, USERS)"