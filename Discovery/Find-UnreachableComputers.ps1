<#
.SYNOPSIS
Detects unreachable computers by testing ping, WinRM, and SMB connectivity, providing a status matrix.
#>
param (
    [string[]]$ComputerName,     # Single computer name or array
    [string]$CsvPath,            # Path to a CSV file with a 'ComputerName' column
    [string]$AdOuPath,           # Distinguished Name of an AD OU to query for computers
    [string]$TextFilePath,       # Path to a text file with one computer name per line
    [string]$ExportPath
)

# --- Load Core Get-Targets.ps1 ---
. (Join-Path -Path $PSScriptRoot -ChildPath "..\Core\Get-Targets.ps1")

try {
    $TargetComputers = Get-Targets -ComputerName $ComputerName -CsvPath $CsvPath -AdOuPath $AdOuPath -TextFilePath $TextFilePath

    if (-not $TargetComputers) {
        Write-Warning "No target computers provided or found. Exiting."
        return
    }

    $Result = foreach ($Computer in $TargetComputers) {
        $PingStatus = "N/A"
        $WinRMStatus = "N/A"
        $SMBStatus = "N/A"

        Write-Verbose "Testing connectivity to $Computer..."

        # Test Ping
        try {
            if (Test-Connection -ComputerName $Computer -Count 1 -ErrorAction Stop -Quiet) {
                $PingStatus = "Reachable"
            } else {
                $PingStatus = "Unreachable"
            }
        }
        catch { $PingStatus = "Error: $($_.Exception.Message)" }

        # Test WinRM
        try {
            Invoke-Command -ComputerName $Computer -ScriptBlock { "Test" } -ErrorAction Stop | Out-Null
            $WinRMStatus = "Reachable"
        }
        catch { $WinRMStatus = "Error: $($_.Exception.Message)" }

        # Test SMB
        try {
            if (Test-Path -Path "\\$Computer\IPC$" -ErrorAction Stop) {
                $SMBStatus = "Reachable"
            } else {
                $SMBStatus = "Unreachable"
            }
        }
        catch { $SMBStatus = "Error: $($_.Exception.Message)" }

        [PSCustomObject]@{
            ComputerName = $Computer
            Ping         = $PingStatus
            WinRM        = $WinRMStatus
            SMB          = $SMBStatus
        }
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
        $Result | Format-Table -AutoSize
    }
}
catch {
    Write-Error "An error occurred during unreachable computers detection: $($_.Exception.Message)"
}
