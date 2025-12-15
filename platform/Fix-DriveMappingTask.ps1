# Fix-DriveMappingTask.ps1
# One-shot fix for drive mapping scheduled task

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Drive Mapping Task Fix - One Shot" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

# Check admin privileges
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Host "ERROR: Must run as Administrator!" -ForegroundColor Red
    exit 1
}

Write-Host "Running as: $env:USERNAME`n" -ForegroundColor Gray

$TaskName = "IntuneDriveMapping"
$ScriptPath = "C:\ProgramData\Intune\Scripts\MapDrives.ps1"
$ScriptDir = Split-Path $ScriptPath

# Step 1: Create script directory
Write-Host "[1/5] Creating script directory..." -ForegroundColor Yellow
if (-not (Test-Path $ScriptDir)) {
    New-Item -Path $ScriptDir -ItemType Directory -Force | Out-Null
    Write-Host "  + Created: $ScriptDir" -ForegroundColor Green
} else {
    Write-Host "  - Already exists: $ScriptDir" -ForegroundColor Gray
}

# Step 2: Create the drive mapping script
Write-Host "`n[2/5] Writing drive mapping script..." -ForegroundColor Yellow
$DriveScript = @'
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

$DriveScript | Out-File -FilePath $ScriptPath -Encoding UTF8 -Force
Write-Host "  + Script written to: $ScriptPath" -ForegroundColor Green

# Step 3: Remove existing task if present
Write-Host "`n[3/5] Checking for existing scheduled task..." -ForegroundColor Yellow
$ExistingTask = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
if ($ExistingTask) {
    Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false -ErrorAction SilentlyContinue
    Write-Host "  + Removed existing task: $TaskName" -ForegroundColor Green
} else {
    Write-Host "  - No existing task found" -ForegroundColor Gray
}

# Step 4: Create scheduled task
Write-Host "`n[4/5] Creating scheduled task..." -ForegroundColor Yellow
$Action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-ExecutionPolicy Bypass -WindowStyle Hidden -File `"$ScriptPath`""
$Trigger = New-ScheduledTaskTrigger -AtLogOn
$Principal = New-ScheduledTaskPrincipal -GroupId "S-1-5-32-545" -RunLevel Limited  # USERS group
$Settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable

try {
    Register-ScheduledTask -TaskName $TaskName -Action $Action -Trigger $Trigger -Principal $Principal -Settings $Settings -Force | Out-Null
    Write-Host "  + Task created: $TaskName" -ForegroundColor Green
    Write-Host "    Trigger: At logon" -ForegroundColor Gray
    Write-Host "    Principal: USERS group (Limited)" -ForegroundColor Gray
} catch {
    Write-Host "  x Failed to create task: $($_.Exception.Message)" -ForegroundColor Red
}

# Step 5: Verification
Write-Host "`n[5/5] Verifying..." -ForegroundColor Yellow

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "VERIFICATION RESULTS" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

# Check script exists
Write-Host "`nDrive mapping script: " -NoNewline
if (Test-Path $ScriptPath) {
    Write-Host "EXISTS" -ForegroundColor Green
} else {
    Write-Host "MISSING" -ForegroundColor Red
}

# Check scheduled task
Write-Host "Scheduled task: " -NoNewline
$Task = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
if ($Task) {
    Write-Host "REGISTERED" -ForegroundColor Green
    Write-Host "  State: $($Task.State)" -ForegroundColor Gray
} else {
    Write-Host "NOT FOUND" -ForegroundColor Red
}

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "NEXT STEPS" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "1. Users need to sign out and sign back in for the task to run"
Write-Host "2. Or run the task manually: Start-ScheduledTask -TaskName '$TaskName'"
Write-Host "3. Verify T: drive is mapped after logon`n"
