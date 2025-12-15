# Deploy-AVDNotificationsTask.ps1
# Platform script - drops script and registers scheduled task

$scriptRoot = "C:\ProgramData\Intune\Scripts"
if (-not (Test-Path $scriptRoot)) { New-Item -Path $scriptRoot -ItemType Directory -Force | Out-Null }

$scriptContent = @'
Start-Sleep -Seconds 60

# Fix 1: HKLM Policy PushNotifications
$LMPolicyPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\CurrentVersion\PushNotifications"
if (Test-Path $LMPolicyPath) {
    Set-ItemProperty -Path $LMPolicyPath -Name "NoCloudApplicationNotification" -Value 0 -Force -ErrorAction SilentlyContinue
    Set-ItemProperty -Path $LMPolicyPath -Name "NoToastApplicationNotification" -Value 0 -Force -ErrorAction SilentlyContinue
}

# Fix 2: HKCU Policy PushNotifications (all loaded user profiles)
$ProfileList = Get-ChildItem "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList" |
    Where-Object { $_.PSChildName -match '^S-1-5-21-' }

foreach ($Profile in $ProfileList) {
    $SID = $Profile.PSChildName
    $HKUPath = "Registry::HKU\$SID\SOFTWARE\Policies\Microsoft\Windows\CurrentVersion\PushNotifications"
    
    if (Test-Path $HKUPath) {
        Set-ItemProperty -Path $HKUPath -Name "NoToastApplicationNotification" -Value 0 -Force -ErrorAction SilentlyContinue
        Set-ItemProperty -Path $HKUPath -Name "NoToastApplicationNotificationOnLockScreen" -Value 0 -Force -ErrorAction SilentlyContinue
    }
}

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

# Fix 5: Restart Windows Push Notification Service
$WpnService = Get-Service -Name "WpnService" -ErrorAction SilentlyContinue
if ($WpnService) {
    if ($WpnService.Status -ne "Running") {
        Start-Service -Name "WpnService" -ErrorAction SilentlyContinue
    }
    Restart-Service -Name "WpnService" -Force -ErrorAction SilentlyContinue
}
'@

Set-Content -Path "$scriptRoot\Fix-AVD-Notifications.ps1" -Value $scriptContent -Force

# Register the scheduled task
$action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$scriptRoot\Fix-AVD-Notifications.ps1`""
$trigger = New-ScheduledTaskTrigger -AtStartup
$principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest
Register-ScheduledTask -TaskName "Fix AVD Notifications" -Action $action -Trigger $trigger -Principal $principal -Force