<#
.SYNOPSIS
Shows all listening ports, associated processes, and binary paths.
#>
param (
    [string]$ExportPath
)

try {
    $Connections = Get-NetTCPConnection | Where-Object { $_.State -eq "Listen" }

    $Result = foreach ($Connection in $Connections) {
        $Process = Get-Process -Id $Connection.OwningProcess -ErrorAction SilentlyContinue
        $BinaryPath = if ($Process) { $Process.Path } else { "N/A" }

        [PSCustomObject]@{
            LocalAddress  = $Connection.LocalAddress
            LocalPort     = $Connection.LocalPort
            ProcessName   = if ($Process) { $Process.ProcessName } else { "N/A" }
            PID           = $Connection.OwningProcess
            BinaryPath    = $BinaryPath
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
    Write-Error "An error occurred: $($_.Exception.Message)"
}
