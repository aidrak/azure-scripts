# Remediate-NotificationsEnabled.ps1
# Remediation script for AVD notification settings (no reboot)

# Logging setup
$LogFolder = "C:\ProgramData\Intune\RemediationScripts"
$LogFile = Join-Path $LogFolder "Remediate-NotificationsEnabled.log"

if (-not (Test-Path $LogFolder)) {
    New-Item -Path $LogFolder -ItemType Directory -Force | Out-Null
}

function Write-Log {
    param([string]$Message)
    $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    "$Timestamp - $Message" | Out-File -FilePath $LogFile -Append -Encoding UTF8
}

Write-Log "========== Remediation script started =========="
Write-Log "Running as: $env:USERNAME"

$ChangesMade = $false

# Fix 1: HKLM Policy PushNotifications
$LMPolicyPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\CurrentVersion\PushNotifications"
Write-Log "Checking HKLM Policy: $LMPolicyPath"
if (Test-Path $LMPolicyPath) {
    $NoCloud = (Get-ItemProperty -Path $LMPolicyPath -Name "NoCloudApplicationNotification" -ErrorAction SilentlyContinue).NoCloudApplicationNotification
    $NoToast = (Get-ItemProperty -Path $LMPolicyPath -Name "NoToastApplicationNotification" -ErrorAction SilentlyContinue).NoToastApplicationNotification
    Write-Log "  Current NoCloudApplicationNotification: $NoCloud"
    Write-Log "  Current NoToastApplicationNotification: $NoToast"

    if ($NoCloud -eq 1) {
        Set-ItemProperty -Path $LMPolicyPath -Name "NoCloudApplicationNotification" -Value 0 -Force
        Write-Log "  -> Set NoCloudApplicationNotification to 0"
        $ChangesMade = $true
    }
    if ($NoToast -eq 1) {
        Set-ItemProperty -Path $LMPolicyPath -Name "NoToastApplicationNotification" -Value 0 -Force
        Write-Log "  -> Set NoToastApplicationNotification to 0"
        $ChangesMade = $true
    }
} else {
    Write-Log "  Path does not exist - no action needed"
}

# Fix 2: HKCU Policy PushNotifications (all user profiles)
Write-Log "Checking HKCU Policy for all user profiles"
$ProfileList = Get-ChildItem "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList" |
    Where-Object { $_.PSChildName -match '^S-1-5-21-' }

foreach ($Profile in $ProfileList) {
    $SID = $Profile.PSChildName
    $HKUPath = "Registry::HKU\$SID\SOFTWARE\Policies\Microsoft\Windows\CurrentVersion\PushNotifications"
    Write-Log "  Checking SID: $SID"

    if (Test-Path $HKUPath) {
        try {
            Set-ItemProperty -Path $HKUPath -Name "NoToastApplicationNotification" -Value 0 -Force -ErrorAction SilentlyContinue
            Set-ItemProperty -Path $HKUPath -Name "NoToastApplicationNotificationOnLockScreen" -Value 0 -Force -ErrorAction SilentlyContinue
            Write-Log "    -> Set NoToastApplicationNotification to 0"
            Write-Log "    -> Set NoToastApplicationNotificationOnLockScreen to 0"
            $ChangesMade = $true
        } catch {
            Write-Log "    -> Error setting values: $_"
        }
    } else {
        Write-Log "    Path does not exist - no action needed"
    }
}

# Fix 3: HKLM Explorer NoNewAppAlert
$LMExplorerPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Explorer"
Write-Log "Checking HKLM Explorer: $LMExplorerPath"
if (Test-Path $LMExplorerPath) {
    $NoNewApp = (Get-ItemProperty -Path $LMExplorerPath -Name "NoNewAppAlert" -ErrorAction SilentlyContinue).NoNewAppAlert
    Write-Log "  Current NoNewAppAlert: $NoNewApp"
    
    if ($NoNewApp -eq 1) {
        Set-ItemProperty -Path $LMExplorerPath -Name "NoNewAppAlert" -Value 0 -Force
        Write-Log "  -> Set NoNewAppAlert to 0"
        $ChangesMade = $true
    }
} else {
    Write-Log "  Path does not exist - no action needed"
}

# Fix 4: Enable ToastEnabled and EnableMultiUser in HKLM (CRITICAL for AVD)
$LMPushPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\PushNotifications"
Write-Log "Ensuring ToastEnabled and EnableMultiUser in: $LMPushPath"
if (-not (Test-Path $LMPushPath)) {
    New-Item -Path $LMPushPath -Force | Out-Null
    Write-Log "  -> Created registry path"
}

$CurrentToast = (Get-ItemProperty -Path $LMPushPath -Name "ToastEnabled" -ErrorAction SilentlyContinue).ToastEnabled
$CurrentMultiUser = (Get-ItemProperty -Path $LMPushPath -Name "EnableMultiUser" -ErrorAction SilentlyContinue).EnableMultiUser

if ($CurrentToast -ne 1) {
    Set-ItemProperty -Path $LMPushPath -Name "ToastEnabled" -Value 1 -Force
    Write-Log "  -> Set ToastEnabled to 1"
    $ChangesMade = $true
}

if ($CurrentMultiUser -ne 1) {
    Set-ItemProperty -Path $LMPushPath -Name "EnableMultiUser" -Value 1 -Type DWord -Force
    Write-Log "  -> Set EnableMultiUser to 1 (CRITICAL for AVD multi-user support)"
    $ChangesMade = $true
}

# Fix 5: Ensure Windows Push Notification Service is running
Write-Log "Verifying Windows Push Notification Service"
$WpnService = Get-Service -Name "WpnService" -ErrorAction SilentlyContinue
if ($WpnService) {
    if ($WpnService.Status -ne "Running") {
        try {
            Start-Service -Name "WpnService" -ErrorAction Stop
            Write-Log "  -> Started WpnService"
            $ChangesMade = $true
        } catch {
            Write-Log "  -> Failed to start WpnService: $_"
        }
    } else {
        Write-Log "  -> WpnService already running"
    }
    
    # Restart service to apply changes if any were made
    if ($ChangesMade) {
        try {
            Restart-Service -Name "WpnService" -Force -ErrorAction Stop
            Write-Log "  -> Restarted WpnService to apply changes"
        } catch {
            Write-Log "  -> Failed to restart WpnService: $_"
        }
    }
} else {
    Write-Log "  -> WpnService not found"
}

# Final result
if ($ChangesMade) {
    Write-Log "RESULT: Remediation complete - changes applied"
    Write-Log "NOTE: Users may need to sign out and back in for changes to take full effect"
    Write-Log "========== Remediation script completed =========="
    Write-Output "Remediated. User sign-out recommended."
} else {
    Write-Log "RESULT: Remediation complete - no changes needed"
    Write-Log "========== Remediation script completed =========="
    Write-Output "No changes needed."
}