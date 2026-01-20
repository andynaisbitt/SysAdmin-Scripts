<#
.SYNOPSIS
Clears print jobs from a specific printer or all printers on a server.
#>
[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
param (
    [string]$ComputerName,
    [string]$PrinterName,
    [switch]$ShowWhatWillBeDeleted
)

if (-not $ComputerName) {
    $ComputerName = Read-Host "Enter the print server name"
}

try {
    Write-Verbose "Connecting to print server $ComputerName."

    if ($PrinterName) {
        $PrintersToClear = Get-Printer -ComputerName $ComputerName -Name $PrinterName -ErrorAction Stop
    }
    else {
        $PrintersToClear = Get-Printer -ComputerName $ComputerName -ErrorAction Stop
        Write-Host "No specific printer name provided. All print queues on $ComputerName will be targeted."
    }

    foreach ($Printer in $PrintersToClear) {
        $Jobs = Get-PrintJob -ComputerName $ComputerName -PrinterName $Printer.Name -ErrorAction SilentlyContinue

        if ($Jobs) {
            Write-Host "Found $($Jobs.Count) jobs in queue for printer $($Printer.Name)."
            if ($ShowWhatWillBeDeleted) {
                Write-Host "Jobs to be deleted:"
                $Jobs | Format-Table Id, DocumentName, UserName, SubmittedTime
            }

            if ($pscmdlet.ShouldProcess("Clearing all jobs from printer '$($Printer.Name)' on '$ComputerName'", "Clear Print Queue")) {
                $Jobs | Remove-PrintJob -ComputerName $ComputerName -PrinterName $Printer.Name -WhatIf:$pscmdlet.WhatIf -ErrorAction Stop
                Write-Host "All jobs cleared from printer '$($Printer.Name)' on '$ComputerName'."
            }
        }
        else {
            Write-Host "No jobs found for printer '$($Printer.Name)' on '$ComputerName'."
        }
    }
}
catch {
    Write-Error "An error occurred: $($_.Exception.Message)"
}
