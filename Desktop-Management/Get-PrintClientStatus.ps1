<#
.SYNOPSIS
Lists installed printers, default printer, driver versions, and last spooler errors on a client workstation.
#>
param (
    [string]$ComputerName,
    [string]$ExportPath
)

if (-not $ComputerName) {
    $ComputerName = Read-Host "Enter the computer name of the workstation"
}

$Result = [PSCustomObject]@{
    ComputerName  = $ComputerName
    InstalledPrinters = @()
    DefaultPrinter = "N/A"
    SpoolerErrorEvents = @()
    OverallStatus = "N/A"
}

try {
    Invoke-Command -ComputerName $ComputerName -ScriptBlock {
        # --- Installed Printers and Drivers ---
        $Printers = Get-Printer | Select-Object Name, PortName, DriverName, Published
        foreach ($Printer in $Printers) {
            $Driver = Get-PrinterDriver -Name $Printer.DriverName -ErrorAction SilentlyContinue
            $PrinterObject = [PSCustomObject]@{
                Name = $Printer.Name
                Driver = $Printer.DriverName
                DriverVersion = if ($Driver) { $Driver.DriverVersion } else { "N/A" }
                Port = $Printer.PortName
                Published = $Printer.Published
            }
            $using:Result.InstalledPrinters += $PrinterObject
        }

        # --- Default Printer ---
        $DefaultPrinter = (Get-WmiObject -Class Win32_Printer | Where-Object { $_.Default -eq $true } | Select-Object -ExpandProperty Name -First 1)
        if ($DefaultPrinter) {
            $using:Result.DefaultPrinter = $DefaultPrinter
        }

        # --- Last Spooler Errors (Event Log) ---
        $SpoolerErrors = Get-WinEvent -FilterHashtable @{
            LogName = 'System'
            ProviderName = 'Microsoft-Windows-PrintSpooler'
            Level = @(1, 2) # Critical, Error
            StartTime = (Get-Date).AddDays(-7) # Last 7 days
        } -ErrorAction SilentlyContinue | Select-Object TimeCreated, Message -First 5
        if ($SpoolerErrors) {
            $using:Result.SpoolerErrorEvents = ($SpoolerErrors | ForEach-Object { "$($_.TimeCreated): $($_.Message)" }) -join " | "
        }
    } -ErrorAction Stop

    $Result.OverallStatus = "Success"
}
catch {
    $Result.OverallStatus = "Failed"
    $Result.Errors = $_.Exception.Message
    Write-Error "An error occurred while getting print client status from '$ComputerName': $($_.Exception.Message)"
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
    $Result | Format-List # Format as list for better readability of nested objects
}
