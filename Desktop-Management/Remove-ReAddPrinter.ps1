<#
.SYNOPSIS
Removes a named printer connection and re-adds it from a print server path, with optional spooler restart.
#>
[CmdletBinding(SupportsShouldProcess = $true)]
param (
    [string]$ComputerName,
    [string]$PrinterName,      # The local printer name on the client
    [string]$PrintServerPath,  # The UNC path to the shared printer (e.g., \\PrintServer\PrinterShare)
    [switch]$RestartSpooler,   # Restart spooler before re-adding
    [string]$ExportPath
)

if (-not $ComputerName) { $ComputerName = Read-Host "Enter the computer name of the workstation" }
if (-not $PrinterName) { $PrinterName = Read-Host "Enter the local name of the printer to remove/re-add" }
if (-not $PrintServerPath) { $PrintServerPath = Read-Host "Enter the UNC path to the shared printer (e.g., \\PrintServer\PrinterShare)" }

$Result = [PSCustomObject]@{
    ComputerName = $ComputerName
    PrinterName = $PrinterName
    PrintServerPath = $PrintServerPath
    RemoveStatus = "N/A"
    AddStatus = "N/A"
    SpoolerRestarted = "No"
    OverallStatus = "Failed"
    Errors = @()
}

try {
    Write-Host "Starting printer re-add process for '$PrinterName' on '$ComputerName'..."
    Invoke-Command -ComputerName $ComputerName -ScriptBlock {
        param ($PrinterName, $PrintServerPath, $RestartSpooler, $Result)

        # 1. Restart Spooler (Optional)
        if ($RestartSpooler) {
            if ($pscmdlet.ShouldProcess("Restart Print Spooler service", "Restart Spooler")) {
                try {
                    Stop-Service -Name Spooler -Force -ErrorAction Stop
                    Start-Service -Name Spooler -ErrorAction Stop
                    $Result.SpoolerRestarted = "Yes"
                    Write-Host "Print Spooler restarted."
                }
                catch {
                    Write-Warning "Failed to restart Print Spooler: $($_.Exception.Message)"
                    $Result.Errors += "Spooler Restart Failed: $($_.Exception.Message)"
                }
            }
        }

        # 2. Remove Printer
        if ($pscmdlet.ShouldProcess("Remove printer '$PrinterName'", "Remove Printer")) {
            try {
                Get-Printer -Name $PrinterName -ErrorAction Stop | Remove-Printer -ErrorAction Stop
                $Result.RemoveStatus = "Success"
                Write-Host "Printer '$PrinterName' removed."
            }
            catch {
                Write-Warning "Failed to remove printer '$PrinterName': $($_.Exception.Message)"
                $Result.Errors += "Printer Removal Failed: $($_.Exception.Message)"
            }
        }

        # 3. Add Printer
        if ($pscmdlet.ShouldProcess("Add printer '$PrintServerPath'", "Add Printer")) {
            try {
                Add-Printer -ConnectionName $PrintServerPath -ErrorAction Stop
                $Result.AddStatus = "Success"
                Write-Host "Printer '$PrintServerPath' re-added."
            }
            catch {
                Write-Warning "Failed to re-add printer '$PrintServerPath': $($_.Exception.Message)"
                $Result.Errors += "Printer Re-add Failed: $($_.Exception.Message)"
            }
        }

        $Result.OverallStatus = if ($Result.Errors.Count -eq 0) { "Success" } else { "Completed with Errors" }

    } -ArgumentList $PrinterName, $PrintServerPath, $RestartSpooler, $Result -ErrorAction Stop

    $Result.OverallStatus = if ($Result.Errors.Count -eq 0) { "Success" } else { "Completed with Errors" }
}
catch {
    $Result.OverallStatus = "Failed"
    $Result.Errors += $_.Exception.Message
    Write-Error "An error occurred during printer re-add process: $($_.Exception.Message)"
}

if ($ExportPath) {
    if ($ExportPath.EndsWith(".csv")) {
        $Result | Export-Csv -Path $ExportPath -NoTypeInformation
    }
    elseif ($ExportPath.EndsWith(".html")) {
        $Result | ConvertTo-Html | Out-File -Path $ExportPath
    }
    else {
        Write-Warning "Invalid export path. Please specify a .csv or .html file."
    }
}
else {
    $Result | Format-List
}
