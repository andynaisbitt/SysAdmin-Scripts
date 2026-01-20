<#
.SYNOPSIS
Lists installed printer drivers on a server, including versions and driver types.
#>
param (
    [string]$ComputerName,
    [string]$ExportPath
)

if (-not $ComputerName) {
    $ComputerName = Read-Host "Enter the print server name"
}

try {
    $Drivers = Get-PrinterDriver -ComputerName $ComputerName -ErrorAction Stop
    $Result = foreach ($Driver in $Drivers) {
        # Determine Driver Type (often 3 or 4 for modern drivers)
        # This information might be inferred or looked up if not directly available
        # Get-PrinterDriver provides 'DriverType' property, which is usually 3 or 4
        $DriverType = $Driver.DriverType

        [PSCustomObject]@{
            ComputerName = $ComputerName
            DriverName   = $Driver.Name
            Version      = $Driver.DriverVersion
            DriverType   = $DriverType # This will be 3 for Type 3, 4 for Type 4
            Manufacturer = $Driver.Manufacturer
            InfPath      = $Driver.InfPath
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
    Write-Error "An error occurred while getting printer driver report from '$ComputerName': $($_.Exception.Message)"
}
