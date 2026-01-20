<#
.SYNOPSIS
Reports on the default printer status, spooler status, stuck jobs count, and driver name/version on a computer.
#>
param (
    [string]$ComputerName = "localhost",
    [string]$ExportPath
)

$Result = [PSCustomObject]@{
    ComputerName = $ComputerName
    DefaultPrinter = "N/A"
    SpoolerStatus = "N/A"
    StuckJobsCount = 0
    DefaultPrinterDriver = "N/A"
    DefaultPrinterDriverVersion = "N/A"
    OverallStatus = "Failed"
    Errors = @()
}

try {
    Write-Host "--- Getting Default Printer Status on $ComputerName ---"

    Invoke-Command -ComputerName $ComputerName -ScriptBlock {
        # Default Printer
        $DefaultPrinter = (Get-WmiObject -Class Win32_Printer | Where-Object { $_.Default -eq $true } | Select-Object -ExpandProperty Name -First 1)
        if ($DefaultPrinter) {
            $using:Result.DefaultPrinter = $DefaultPrinter
            
            # Default Printer Driver Info
            $PrinterObject = Get-Printer -Name $DefaultPrinter -ErrorAction SilentlyContinue
            if ($PrinterObject) {
                $using:Result.DefaultPrinterDriver = $PrinterObject.DriverName
                $Driver = Get-PrinterDriver -Name $PrinterObject.DriverName -ErrorAction SilentlyContinue
                if ($Driver) {
                    $using:Result.DefaultPrinterDriverVersion = $Driver.DriverVersion
                }
            }
        }
        
        # Spooler Status
        $SpoolerService = Get-Service -Name Spooler -ErrorAction SilentlyContinue
        if ($SpoolerService) {
            $using:Result.SpoolerStatus = $SpoolerService.Status
        }

        # Stuck Jobs Count
        if ($using:Result.DefaultPrinter -ne "N/A") {
            $Jobs = Get-PrintJob -PrinterName $using:Result.DefaultPrinter -ErrorAction SilentlyContinue
            $StuckJobs = $Jobs | Where-Object { $_.JobStatus -ne "Normal" -and $_.JobStatus -ne "Printed" }
            $using:Result.StuckJobsCount = $StuckJobs.Count
        }
        
        $using:Result.OverallStatus = "Success"
    } -ErrorAction Stop

    $Result.OverallStatus = "Success"
}
catch {
    $Result.OverallStatus = "Failed"
    $Result.Errors += $_.Exception.Message
    Write-Error "An error occurred during default printer status retrieval: $($_.Exception.Message)"
}

if ($ExportPath) {
    $Result | Export-Csv -Path $ExportPath -NoTypeInformation -Force
}
else {
    $Result | Format-List
}
