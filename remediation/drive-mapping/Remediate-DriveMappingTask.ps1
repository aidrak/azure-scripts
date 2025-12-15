# Remediate-DriveMappingTask.ps1

# Logging setup
$LogFolder = "C:\ProgramData\Intune\RemediationScripts"
$LogFile = Join-Path $LogFolder "Remediate-DriveMappingTask.log"

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

$TaskName = "IntuneDriveMapping"
$ScriptPath = "C:\ProgramData\Intune\Scripts\MapDrives.ps1"
$ScriptDir = Split-Path $ScriptPath

Write-Log "Task name: $TaskName"
Write-Log "Script path: $ScriptPath"

# Create script directory
if (-not (Test-Path $ScriptDir)) {
    New-Item -Path $ScriptDir -ItemType Directory -Force | Out-Null
    Write-Log "Created script directory: $ScriptDir"
} else {
    Write-Log "Script directory already exists: $ScriptDir"
}

# Create the drive mapping script
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
Write-Log "Drive mapping script written to: $ScriptPath"

# Remove existing task if present
$ExistingTask = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
if ($ExistingTask) {
    Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false -ErrorAction SilentlyContinue
    Write-Log "Removed existing scheduled task"
}

# Create scheduled task
Write-Log "Creating scheduled task..."
$Action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-ExecutionPolicy Bypass -WindowStyle Hidden -File `"$ScriptPath`""
$Trigger = New-ScheduledTaskTrigger -AtLogOn
$Principal = New-ScheduledTaskPrincipal -GroupId "S-1-5-32-545" -RunLevel Limited  # USERS group
$Settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable

try {
    Register-ScheduledTask -TaskName $TaskName -Action $Action -Trigger $Trigger -Principal $Principal -Settings $Settings -Force | Out-Null
    Write-Log "Scheduled task created successfully"
    Write-Log "  Action: powershell.exe -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$ScriptPath`""
    Write-Log "  Trigger: At logon"
    Write-Log "  Principal: USERS group (Limited)"
    Write-Log "RESULT: Remediation complete"
    Write-Log "========== Remediation script completed =========="
    Write-Output "Scheduled task created"
} catch {
    Write-Log "ERROR: Failed to create scheduled task - $($_.Exception.Message)"
    Write-Log "========== Remediation script completed with errors =========="
    Write-Output "Failed to create scheduled task"
}