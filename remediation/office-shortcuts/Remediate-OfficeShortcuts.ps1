# Remediate-OfficeShortcuts.ps1

# Logging setup
$LogFolder = "C:\ProgramData\Intune\RemediationScripts"
$LogFile = Join-Path $LogFolder "OfficeShortcuts-Remediation.log"

if (-not (Test-Path $LogFolder)) {
    New-Item -Path $LogFolder -ItemType Directory -Force | Out-Null
}

function Write-Log {
    param([string]$Message)
    $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $LogEntry = "[$Timestamp] $Message"
    Add-Content -Path $LogFile -Value $LogEntry
}

Write-Log "===== Remediation script started ====="

$Apps = @(
    @{Name = "Word"; Exe = "WINWORD.EXE"},
    @{Name = "Excel"; Exe = "EXCEL.EXE"},
    @{Name = "Outlook"; Exe = "OUTLOOK.EXE"},
    @{Name = "Access"; Exe = "MSACCESS.EXE"}
)

$PublicDesktop = "C:\Users\Public\Desktop"
$StartMenu = "C:\ProgramData\Microsoft\Windows\Start Menu\Programs"
$OfficePath = "C:\Program Files\Microsoft Office\root\Office16"

$WshShell = New-Object -ComObject WScript.Shell
$ShortcutsCreated = 0

Write-Log "Office path: $OfficePath"

foreach ($App in $Apps) {
    $ExePath = Join-Path $OfficePath $App.Exe

    if (Test-Path $ExePath) {
        Write-Log "$($App.Name) executable found"

        # Public Desktop
        $DesktopShortcut = Join-Path $PublicDesktop "$($App.Name).lnk"
        if (-not (Test-Path $DesktopShortcut)) {
            try {
                $Shortcut = $WshShell.CreateShortcut($DesktopShortcut)
                $Shortcut.TargetPath = $ExePath
                $Shortcut.Save()
                Write-Log "CREATED: $($App.Name) desktop shortcut"
                $ShortcutsCreated++
            } catch {
                Write-Log "ERROR: Failed to create $($App.Name) desktop shortcut - $($_.Exception.Message)"
            }
        } else {
            Write-Log "SKIPPED: $($App.Name) desktop shortcut already exists"
        }

        # Start Menu
        $StartMenuShortcut = Join-Path $StartMenu "$($App.Name).lnk"
        if (-not (Test-Path $StartMenuShortcut)) {
            try {
                $Shortcut = $WshShell.CreateShortcut($StartMenuShortcut)
                $Shortcut.TargetPath = $ExePath
                $Shortcut.Save()
                Write-Log "CREATED: $($App.Name) Start Menu shortcut"
                $ShortcutsCreated++
            } catch {
                Write-Log "ERROR: Failed to create $($App.Name) Start Menu shortcut - $($_.Exception.Message)"
            }
        } else {
            Write-Log "SKIPPED: $($App.Name) Start Menu shortcut already exists"
        }
    } else {
        Write-Log "$($App.Name) executable not found (skipped)"
    }
}

Write-Log "Total shortcuts created: $ShortcutsCreated"
Write-Log "===== Remediation script ended ====="
Write-Output "Created $ShortcutsCreated shortcuts"
