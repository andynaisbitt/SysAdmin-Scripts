<#
.SYNOPSIS
Gets the health of print server queues.
#>
param (
    [string]$ComputerName,
    [string]$ExportPath
)

if (-not $ComputerName) {
    $ComputerName = Read-Host "Enter the print server name"
}

try {
    $Printers = Get-Printer -ComputerName $ComputerName
    $Result = foreach ($Printer in $Printers) {
        $Jobs = Get-PrintJob -ComputerName $ComputerName -PrinterName $Printer.Name
        $OldestJob = $Jobs | Sort-Object -Property SubmittedTime | Select-Object -First 1
        [PSCustomObject]@{
            PrinterName   = $Printer.Name
            JobCount      = $Jobs.Count
            StuckJobs     = ($Jobs | Where-Object { $_.JobStatus -ne "Normal" }).Count
            OldestJobAge  = if ($OldestJob) { (New-TimeSpan -Start $OldestJob.SubmittedTime).ToString() } else { "N/A" }
            ErrorState    = $Printer.PrinterStatus
        }
    }

    if ($ExportPath) {
        if ($ExportPath.EndsWith(".csv")) {
            $Result | Export-Csv -Path $ExportPath -NoTypeInformation
        }
        else {
            Write-Warning "Invalid export path. Please specify a .csv file."
        }
    }
    else {
        $Result
    }
}
catch {
    Write-Error "Failed to get print server queue health from '$ComputerName'. Please ensure the print server name is correct and you have the necessary permissions."
}
