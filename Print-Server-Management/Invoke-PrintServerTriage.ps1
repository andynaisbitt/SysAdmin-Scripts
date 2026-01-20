<#
.SYNOPSIS
Performs a quick triage of a print server, checking spooler service, top printers by queue length, and oldest stuck jobs.
Optionally restarts the print spooler.
#>
[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
param (
    [string]$ComputerName,
    [switch]$RestartSpooler,
    [string]$ExportPath
)

if (-not $ComputerName) {
    $ComputerName = Read-Host "Enter the print server name"
}

$Result = [PSCustomObject]@{
    ComputerName = $ComputerName
    SpoolerStatus = "N/A"
    TopPrintersByQueue = @()
    StuckJobsSummary = "N/A"
    SpoolerRestarted = "No"
    OverallStatus = "Failed"
    Errors = @()
}

try {
    Write-Host "Starting print server triage on '$ComputerName'..."

    # 1. Check Spooler Service Status
    Write-Host "Checking Print Spooler service status..."
    $SpoolerService = Get-Service -ComputerName $ComputerName -Name Spooler -ErrorAction SilentlyContinue
    if ($SpoolerService) {
        $Result.SpoolerStatus = $SpoolerService.Status
        Write-Host "Print Spooler status: $($SpoolerService.Status)"
    }
    else {
        $Result.SpoolerStatus = "Not Found"
        Write-Warning "Print Spooler service not found on $ComputerName."
    }

    # 2. Restart Spooler (Optional)
    if ($RestartSpooler) {
        if ($pscmdlet.ShouldProcess("Restart Print Spooler service on $ComputerName", "Restart Service")) {
            try {
                $SpoolerService | Stop-Service -Force -ErrorAction Stop
                Start-Sleep -Seconds 2
                $SpoolerService | Start-Service -ErrorAction Stop
                $Result.SpoolerRestarted = "Yes"
                Write-Host "Print Spooler restarted."
            }
            catch {
                Write-Warning "Failed to restart Print Spooler: $($_.Exception.Message)"
                $Result.Errors += "Spooler Restart Failed: $($_.Exception.Message)"
            }
        }
    }

    # 3. Top Printers by Queue Length & Oldest Stuck Job
    Write-Host "Checking print queues..."
    $Printers = Get-Printer -ComputerName $ComputerName -ErrorAction SilentlyContinue
    if ($Printers) {
        $PrinterQueueData = @()
        foreach ($Printer in $Printers) {
            $Jobs = Get-PrintJob -ComputerName $ComputerName -PrinterName $Printer.Name -ErrorAction SilentlyContinue
            $JobCount = $Jobs.Count
            $OldestJob = $Jobs | Sort-Object -Property SubmittedTime | Select-Object -First 1
            $OldestJobAge = if ($OldestJob) { (New-TimeSpan -Start $OldestJob.SubmittedTime).ToString("g") } else { "N/A" }
            $StuckJobCount = ($Jobs | Where-Object { $_.JobStatus -ne "Normal" -and $_.JobStatus -ne "Printed" }).Count

            $PrinterQueueData += [PSCustomObject]@{
                PrinterName = $Printer.Name
                JobCount = $JobCount
                StuckJobCount = $StuckJobCount
                OldestJobAge = $OldestJobAge
            }
        }
        $Result.TopPrintersByQueue = $PrinterQueueData | Sort-Object -Property JobCount -Descending | Select-Object -First 5
        $Result.StuckJobsSummary = ($PrinterQueueData | Where-Object {$_.StuckJobCount -gt 0} | ForEach-Object {"$($_.PrinterName) has $($_.StuckJobCount) stuck jobs."}) -join "; "
        Write-Host "Print queue analysis complete."
    }
    else {
        Write-Warning "No printers found on $ComputerName."
    }

    $Result.OverallStatus = "Success"
}
catch {
    $Result.OverallStatus = "Failed"
    $Result.Errors += $_.Exception.Message
    Write-Error "An error occurred during print server triage on '$ComputerName': $($_.Exception.Message)"
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
