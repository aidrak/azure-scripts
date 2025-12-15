# Fix-AVD-Notifications-OneShot.ps1
# One-shot fix for AVD notification settings (no reboot)

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "AVD Notification Fix - One Shot" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

# Check admin privileges
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Host "ERROR: Must run as Administrator!" -ForegroundColor Red
    exit 1
}

Write-Host "Running as: $env:USERNAME`n" -ForegroundColor Gray

# Fix 1: HKLM Policy PushNotifications
Write-Host "[1/6] Fixing HKLM Policy settings..." -ForegroundColor Yellow
$LMPolicyPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\CurrentVersion\PushNotifications"
if (Test-Path $LMPolicyPath) {
    Set-ItemProperty -Path $LMPolicyPath -Name "NoCloudApplicationNotification" -Value 0 -Force -ErrorAction SilentlyContinue
    Set-ItemProperty -Path $LMPolicyPath -Name "NoToastApplicationNotification" -Value 0 -Force -ErrorAction SilentlyContinue
    Write-Host "  ✓ HKLM policies updated" -ForegroundColor Green
} else {
    Write-Host "  ℹ No HKLM policies found" -ForegroundColor Gray
}

# Fix 2: HKCU Policy PushNotifications (all loaded user profiles)
Write-Host "`n[2/6] Fixing user profile policies..." -ForegroundColor Yellow
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
Write-Host "  ✓ Fixed $ProfileCount user profile(s)" -ForegroundColor Green

# Fix 3: HKLM Explorer NoNewAppAlert
Write-Host "`n[3/6] Fixing Explorer notification settings..." -ForegroundColor Yellow
$LMExplorerPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Explorer"
if (Test-Path $LMExplorerPath) {
    Set-ItemProperty -Path $LMExplorerPath -Name "NoNewAppAlert" -Value 0 -Force -ErrorAction SilentlyContinue
    Write-Host "  ✓ NoNewAppAlert disabled" -ForegroundColor Green
} else {
    Write-Host "  ℹ No Explorer policies found" -ForegroundColor Gray
}

# Fix 4: Enable system-level notification settings (CRITICAL for AVD)
Write-Host "`n[4/6] Enabling system notification settings..." -ForegroundColor Yellow
$LMPushPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\PushNotifications"
if (-not (Test-Path $LMPushPath)) {
    New-Item -Path $LMPushPath -Force | Out-Null
    Write-Host "  ℹ Created registry path" -ForegroundColor Gray
}

Set-ItemProperty -Path $LMPushPath -Name "ToastEnabled" -Value 1 -Force
Set-ItemProperty -Path $LMPushPath -Name "EnableMultiUser" -Value 1 -Type DWord -Force
Write-Host "  ✓ ToastEnabled = 1" -ForegroundColor Green
Write-Host "  ✓ EnableMultiUser = 1 (AVD multi-user support)" -ForegroundColor Green

# Fix 5: Verify and start Windows Push Notification Service
Write-Host "`n[5/6] Checking Windows Push Notification Service..." -ForegroundColor Yellow
$WpnService = Get-Service -Name "WpnService" -ErrorAction SilentlyContinue
if ($WpnService) {
    if ($WpnService.Status -ne "Running") {
        Start-Service -Name "WpnService" -ErrorAction SilentlyContinue
        Write-Host "  ✓ Started WpnService" -ForegroundColor Green
    } else {
        Write-Host "  ✓ WpnService already running" -ForegroundColor Green
    }
    
    # Restart to apply changes
    Restart-Service -Name "WpnService" -Force -ErrorAction SilentlyContinue
    Write-Host "  ✓ Restarted WpnService" -ForegroundColor Green
} else {
    Write-Host "  ✗ WpnService not found!" -ForegroundColor Red
}

# Fix 6: Verification
Write-Host "`n[6/6] Verifying changes..." -ForegroundColor Yellow
$MultiUserEnabled = (Get-ItemProperty -Path $LMPushPath -ErrorAction SilentlyContinue).EnableMultiUser
$ToastEnabled = (Get-ItemProperty -Path $LMPushPath -ErrorAction SilentlyContinue).ToastEnabled
$ServiceRunning = (Get-Service -Name "WpnService" -ErrorAction SilentlyContinue).Status -eq "Running"

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "VERIFICATION RESULTS" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

Write-Host "`nMulti-user notifications: " -NoNewline
if ($MultiUserEnabled -eq 1) {
    Write-Host "ENABLED ✓" -ForegroundColor Green
} else {
    Write-Host "DISABLED ✗" -ForegroundColor Red
}

Write-Host "Toast notifications: " -NoNewline
if ($ToastEnabled -eq 1) {
    Write-Host "ENABLED ✓" -ForegroundColor Green
} else {
    Write-Host "DISABLED ✗" -ForegroundColor Red
}

Write-Host "WPN Service: " -NoNewline
if ($ServiceRunning) {
    Write-Host "RUNNING ✓" -ForegroundColor Green
} else {
    Write-Host "STOPPED ✗" -ForegroundColor Red
}

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "NEXT STEPS" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "1. Have all users sign out and sign back in"
Write-Host "2. Check notification settings in Windows Settings"
Write-Host "3. If issues persist, check for Group Policy/Intune overrides"
Write-Host "`nLog location: C:\ProgramData\Intune\RemediationScripts\*.log`n" -ForegroundColor Gray