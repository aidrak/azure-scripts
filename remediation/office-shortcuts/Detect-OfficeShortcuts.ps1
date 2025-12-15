# Detect-OfficeShortcuts.ps1

# Logging setup
$LogFolder = "C:\ProgramData\Intune\RemediationScripts"
$LogFile = Join-Path $LogFolder "OfficeShortcuts-Detection.log"

if (-not (Test-Path $LogFolder)) {
    New-Item -Path $LogFolder -ItemType Directory -Force | Out-Null
}

function Write-Log {
    param([string]$Message)
    $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $LogEntry = "[$Timestamp] $Message"
    Add-Content -Path $LogFile -Value $LogEntry
}

Write-Log "===== Detection script started ====="

$Apps = @(
    @{Name = "Word"; Exe = "WINWORD.EXE"},
    @{Name = "Excel"; Exe = "EXCEL.EXE"},
    @{Name = "Outlook"; Exe = "OUTLOOK.EXE"},
    @{Name = "Access"; Exe = "MSACCESS.EXE"}
)

$PublicDesktop = "C:\Users\Public\Desktop"
$StartMenu = "C:\ProgramData\Microsoft\Windows\Start Menu\Programs"
$OfficePath = "C:\Program Files\Microsoft Office\root\Office16"
$MissingShortcuts = @()
$OfficeInstalled = $false

Write-Log "Checking Office path: $OfficePath"

# First check if Office is installed
if (-not (Test-Path $OfficePath)) {
    Write-Log "Office path does not exist - Office not installed"
    Write-Log "Detection result: COMPLIANT - Office not installed, no action needed"
    Write-Log "===== Detection script ended (exit 0) ====="
    Write-Output "Office not installed"
    exit 0
}

foreach ($App in $Apps) {
    $ExePath = Join-Path $OfficePath $App.Exe

    if (Test-Path $ExePath) {
        $OfficeInstalled = $true
        Write-Log "$($App.Name) executable found at $ExePath"
        $DesktopShortcut = Join-Path $PublicDesktop "$($App.Name).lnk"
        $StartMenuShortcut = Join-Path $StartMenu "$($App.Name).lnk"

        if (-not (Test-Path $DesktopShortcut)) {
            $MissingShortcuts += "$($App.Name) (Desktop)"
            Write-Log "MISSING: $($App.Name) desktop shortcut"
        } else {
            Write-Log "OK: $($App.Name) desktop shortcut exists"
        }
        if (-not (Test-Path $StartMenuShortcut)) {
            $MissingShortcuts += "$($App.Name) (Start Menu)"
            Write-Log "MISSING: $($App.Name) Start Menu shortcut"
        } else {
            Write-Log "OK: $($App.Name) Start Menu shortcut exists"
        }
    } else {
        Write-Log "$($App.Name) executable not found (skipped)"
    }
}

# If Office path exists but no apps found
if (-not $OfficeInstalled) {
    Write-Log "Office path exists but no Office apps found"
    Write-Log "Detection result: COMPLIANT - No Office apps to create shortcuts for"
    Write-Log "===== Detection script ended (exit 0) ====="
    Write-Output "No Office apps found"
    exit 0
}

if ($MissingShortcuts.Count -gt 0) {
    Write-Log "Detection result: REMEDIATION NEEDED - Missing: $($MissingShortcuts -join ', ')"
    Write-Log "===== Detection script ended (exit 1) ====="
    Write-Output "Missing shortcuts: $($MissingShortcuts -join ', ')"
    exit 1
} else {
    Write-Log "Detection result: COMPLIANT - All shortcuts present"
    Write-Log "===== Detection script ended (exit 0) ====="
    Write-Output "All shortcuts present"
    exit 0
}
