# Detect-NotificationsEnabled.ps1
# Detection script for AVD notification settings

# Logging setup
$LogFolder = "C:\ProgramData\Intune\RemediationScripts"
$LogFile = Join-Path $LogFolder "Detect-NotificationsEnabled.log"

if (-not (Test-Path $LogFolder)) {
    New-Item -Path $LogFolder -ItemType Directory -Force | Out-Null
}

function Write-Log {
    param([string]$Message)
    $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    "$Timestamp - $Message" | Out-File -FilePath $LogFile -Append -Encoding UTF8
}

Write-Log "========== Detection script started =========="
Write-Log "Running as: $env:USERNAME"

$NotificationsDisabled = $false

# Check 1: HKLM Policy PushNotifications
$LMPolicyPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\CurrentVersion\PushNotifications"
Write-Log "Checking HKLM Policy: $LMPolicyPath"
if (Test-Path $LMPolicyPath) {
    $NoCloud = (Get-ItemProperty -Path $LMPolicyPath -Name "NoCloudApplicationNotification" -ErrorAction SilentlyContinue).NoCloudApplicationNotification
    $NoToast = (Get-ItemProperty -Path $LMPolicyPath -Name "NoToastApplicationNotification" -ErrorAction SilentlyContinue).NoToastApplicationNotification
    Write-Log "  NoCloudApplicationNotification: $NoCloud"
    Write-Log "  NoToastApplicationNotification: $NoToast"
    
    if ($NoCloud -eq 1 -or $NoToast -eq 1) {
        Write-Log "  -> Notifications disabled via HKLM Policy"
        $NotificationsDisabled = $true
    }
} else {
    Write-Log "  Path does not exist"
}

# Check 2: HKCU Policy PushNotifications (all user profiles)
Write-Log "Checking HKCU Policy for all user profiles"
$ProfileList = Get-ChildItem "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList" |
    Where-Object { $_.PSChildName -match '^S-1-5-21-' }

foreach ($Profile in $ProfileList) {
    $SID = $Profile.PSChildName
    $HKUPath = "Registry::HKU\$SID\SOFTWARE\Policies\Microsoft\Windows\CurrentVersion\PushNotifications"
    Write-Log "  Checking SID: $SID"
    
    if (Test-Path $HKUPath) {
        $NoToastUser = (Get-ItemProperty -Path $HKUPath -Name "NoToastApplicationNotification" -ErrorAction SilentlyContinue).NoToastApplicationNotification
        $NoToastLock = (Get-ItemProperty -Path $HKUPath -Name "NoToastApplicationNotificationOnLockScreen" -ErrorAction SilentlyContinue).NoToastApplicationNotificationOnLockScreen
        Write-Log "    NoToastApplicationNotification: $NoToastUser"
        Write-Log "    NoToastApplicationNotificationOnLockScreen: $NoToastLock"
        
        if ($NoToastUser -eq 1 -or $NoToastLock -eq 1) {
            Write-Log "    -> Notifications disabled for this user"
            $NotificationsDisabled = $true
        }
    } else {
        Write-Log "    Path does not exist"
    }
}

# Check 3: HKLM Explorer NoNewAppAlert
$LMExplorerPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Explorer"
Write-Log "Checking HKLM Explorer: $LMExplorerPath"
if (Test-Path $LMExplorerPath) {
    $NoNewApp = (Get-ItemProperty -Path $LMExplorerPath -Name "NoNewAppAlert" -ErrorAction SilentlyContinue).NoNewAppAlert
    Write-Log "  NoNewAppAlert: $NoNewApp"
    
    if ($NoNewApp -eq 1) {
        Write-Log "  -> NoNewAppAlert is enabled (blocking notifications)"
        $NotificationsDisabled = $true
    }
} else {
    Write-Log "  Path does not exist"
}

# Check 4: ToastEnabled in HKLM
$LMPushPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\PushNotifications"
Write-Log "Checking HKLM PushNotifications: $LMPushPath"
if (Test-Path $LMPushPath) {
    $ToastEnabled = (Get-ItemProperty -Path $LMPushPath -Name "ToastEnabled" -ErrorAction SilentlyContinue).ToastEnabled
    $MultiUser = (Get-ItemProperty -Path $LMPushPath -Name "EnableMultiUser" -ErrorAction SilentlyContinue).EnableMultiUser
    Write-Log "  ToastEnabled: $ToastEnabled"
    Write-Log "  EnableMultiUser: $MultiUser"
    
    if ($ToastEnabled -eq 0) {
        Write-Log "  -> ToastEnabled is 0 (notifications disabled)"
        $NotificationsDisabled = $true
    }
    if ($MultiUser -ne 1) {
        Write-Log "  -> EnableMultiUser is not 1 (multi-user notifications disabled - critical for AVD)"
        $NotificationsDisabled = $true
    }
} else {
    Write-Log "  Path does not exist - needs creation"
    $NotificationsDisabled = $true
}

# Check 5: Windows Push Notification Service
Write-Log "Checking Windows Push Notification Service"
$WpnService = Get-Service -Name "WpnService" -ErrorAction SilentlyContinue
if ($WpnService) {
    Write-Log "  Service Status: $($WpnService.Status)"
    Write-Log "  Start Type: $($WpnService.StartType)"
    
    if ($WpnService.Status -ne "Running") {
        Write-Log "  -> WpnService is not running"
        $NotificationsDisabled = $true
    }
} else {
    Write-Log "  -> WpnService not found"
    $NotificationsDisabled = $true
}

# Final result
if ($NotificationsDisabled) {
    Write-Log "RESULT: Notifications are disabled - remediation needed"
    Write-Log "========== Detection script completed =========="
    Write-Output "Notifications are disabled"
    exit 1
} else {
    Write-Log "RESULT: Notifications are enabled - no action needed"
    Write-Log "========== Detection script completed =========="
    Write-Output "Notifications are enabled"
    exit 0
}