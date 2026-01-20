<#
.SYNOPSIS
Executes Windows repair operations (DISM RestoreHealth, SFC, component cleanup) and exports the results.
#>
[CmdletBinding(SupportsShouldProcess = $true)]
param (
    [string]$ComputerName = "localhost",
    [switch]$PerformCleanup,
    [string]$OutputPath = (Join-Path $PSScriptRoot "..\..\Output\WindowsRepairReports")
)

if (-not (Test-Path -Path $OutputPath)) {
    New-Item -Path $OutputPath -ItemType Directory -Force | Out-Null
}

$Timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$ReportFile = Join-Path -Path $OutputPath -ChildPath "$ComputerName-WindowsRepairReport-$Timestamp.txt"

function Write-RepairLog ([string]$Message, [string]$Level = "INFO") {
    $Time = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    "[$Time] [$Level] $Message" | Add-Content -Path $ReportFile
    Write-Host "[$Level] $Message"
}

$Result = [PSCustomObject]@{
    ComputerName = $ComputerName
    DismRestoreHealthStatus = "N/A"
    SfcScanStatus = "N/A"
    ComponentCleanupStatus = "N/A"
    OverallStatus = "Failed"
    Errors = @()
}

try {
    Write-Host "--- Starting Windows Repair Pack on $ComputerName ---"
    Write-RepairLog "Starting Windows Repair Pack on $ComputerName."

    Invoke-Command -ComputerName $ComputerName -ScriptBlock {
        # 1. DISM /RestoreHealth
        Write-RepairLog "Running DISM /RestoreHealth..."
        if ($pscmdlet.ShouldProcess("Run DISM /RestoreHealth", "DISM RestoreHealth")) {
            try {
                $DismOutput = (dism.exe /online /cleanup-image /restorehealth /NoRestart 2>&1 | Out-String)
                $DismOutput | Add-Content -Path $using:ReportFile
                if ($DismOutput -match "The restore operation completed successfully" -or $DismOutput -match "The operation completed successfully") {
                    $using:Result.DismRestoreHealthStatus = "Success"
                    Write-RepairLog "DISM /RestoreHealth completed successfully."
                } else {
                    $using:Result.DismRestoreHealthStatus = "Failed"
                    Write-RepairLog "DISM /RestoreHealth failed." "ERROR"
                }
            } catch {
                $using:Result.DismRestoreHealthStatus = "Error"
                $using:Result.Errors += "DISM: $($_.Exception.Message)"
                Write-RepairLog "Error running DISM: $($_.Exception.Message)" "ERROR"
            }
        }

        # 2. SFC /scannow
        Write-RepairLog "Running SFC /scannow..."
        if ($pscmdlet.ShouldProcess("Run SFC /scannow", "SFC Scan")) {
            try {
                $SfcOutput = (sfc.exe /scannow 2>&1 | Out-String)
                $SfcOutput | Add-Content -Path $using:ReportFile
                if ($SfcOutput -match "Windows Resource Protection did not find any integrity violations." -or $SfcOutput -match "Windows Resource Protection found corrupt files and successfully repaired them.") {
                    $using:Result.SfcScanStatus = "Success"
                    Write-RepairLog "SFC /scannow completed successfully."
                } else {
                    $using:Result.SfcScanStatus = "Failed"
                    Write-RepairLog "SFC /scannow found issues." "ERROR"
                }
            } catch {
                $using:Result.SfcScanStatus = "Error"
                $using:Result.Errors += "SFC: $($_.Exception.Message)"
                Write-RepairLog "Error running SFC: $($_.Exception.Message)" "ERROR"
            }
        }

        # 3. Component Cleanup
        if ($using:PerformCleanup) {
            Write-RepairLog "Performing component cleanup..."
            if ($pscmdlet.ShouldProcess("Perform component cleanup", "Component Cleanup")) {
                try {
                    # This is equivalent to "Clean up system files" in Disk Cleanup
                    $CleanupOutput = (dism.exe /online /Cleanup-Image /StartComponentCleanup /NoRestart 2>&1 | Out-String)
                    $CleanupOutput | Add-Content -Path $using:ReportFile
                    if ($CleanupOutput -match "The operation completed successfully") {
                        $using:Result.ComponentCleanupStatus = "Success"
                        Write-RepairLog "Component cleanup completed successfully."
                    } else {
                        $using:Result.ComponentCleanupStatus = "Failed"
                        Write-RepairLog "Component cleanup failed." "ERROR"
                    }
                } catch {
                    $using:Result.ComponentCleanupStatus = "Error"
                    $using:Result.Errors += "Component Cleanup: $($_.Exception.Message)"
                    Write-RepairLog "Error running Component Cleanup: $($_.Exception.Message)" "ERROR"
                }
            }
        }
        $using:Result.OverallStatus = "Success"
    } -ErrorAction Stop

    $Result.OverallStatus = "Success"
}
catch {
    $Result.OverallStatus = "Failed"
    $Result.Errors += $_.Exception.Message
    Write-Error "An error occurred during Windows repair pack execution: $($_.Exception.Message)"
    Write-RepairLog "Overall script execution failed: $($_.Exception.Message)" "CRITICAL"
}
finally {
    Write-RepairLog "Windows Repair Pack execution finished."
    Write-Host "Windows Repair Pack report saved to: $ReportFile"
    # Optionally open the report file
    # Invoke-Item -Path $ReportFile
}
