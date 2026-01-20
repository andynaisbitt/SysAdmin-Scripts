<#
.SYNOPSIS
Safely restarts the print spooler service and clears the spool folder on a specified computer.
#>
[CmdletBinding(SupportsShouldProcess = $true)]
param (
    [string]$ComputerName,
    [switch]$ClearSpoolFolder
)

if (-not $ComputerName) {
    $ComputerName = Read-Host "Enter the computer name (server or workstation)"
}

try {
    Write-Verbose "Attempting to restart print spooler on $ComputerName."

    # Stop Print Spooler
    if ($pscmdlet.ShouldProcess("Stopping 'Print Spooler' service on $ComputerName", "Stop Service")) {
        Get-Service -ComputerName $ComputerName -Name Spooler | Stop-Service -Force -ErrorAction Stop
        Write-Host "Print Spooler service stopped on $ComputerName."
    }

    # Clear Spool Folder
    if ($ClearSpoolFolder) {
        $SpoolFolderPath = "\\$ComputerName\admin$\System32\spool\PRINTERS"
        if (Test-Path -Path $SpoolFolderPath) {
            if ($pscmdlet.ShouldProcess("Clearing spool folder '$SpoolFolderPath' on $ComputerName", "Clear Folder")) {
                Remove-Item -Path "$SpoolFolderPath\*" -Recurse -Force -ErrorAction Stop
                Write-Host "Spool folder cleared on $ComputerName."
            }
        }
        else {
            Write-Warning "Spool folder '$SpoolFolderPath' not found on $ComputerName. Skipping clearing."
        }
    }

    # Start Print Spooler
    if ($pscmdlet.ShouldProcess("Starting 'Print Spooler' service on $ComputerName", "Start Service")) {
        Get-Service -ComputerName $ComputerName -Name Spooler | Start-Service -ErrorAction Stop
        Write-Host "Print Spooler service started on $ComputerName."
    }
}
catch {
    Write-Error "An error occurred while restarting the print spooler on $ComputerName: $($_.Exception.Message)"
}
