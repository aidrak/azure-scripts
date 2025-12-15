# Detect-DriveMappingTask.ps1

# Logging setup
$LogFolder = "C:\ProgramData\Intune\RemediationScripts"
$LogFile = Join-Path $LogFolder "Detect-DriveMappingTask.log"

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

$TaskName = "IntuneDriveMapping"
Write-Log "Checking for scheduled task: $TaskName"

$Task = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue

if ($Task) {
    Write-Log "Task found - State: $($Task.State)"
    Write-Log "RESULT: Task exists - no action needed"
    Write-Log "========== Detection script completed =========="
    Write-Output "Task exists"
    exit 0
} else {
    Write-Log "Task not found"
    Write-Log "RESULT: Task missing - remediation needed"
    Write-Log "========== Detection script completed =========="
    Write-Output "Task missing"
    exit 1
}
