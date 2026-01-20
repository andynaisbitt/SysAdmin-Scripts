<#
.SYNOPSIS
Tests connectivity to a matrix of hosts and ports in parallel, providing a summary report.
#>
param (
    [string]$InputCsvPath,
    [string]$ExportPath
)

if (-not $InputCsvPath) {
    $InputCsvPath = Read-Host "Enter the path to the CSV file containing hosts and ports (e.g., Host,Port1,Port2)"
}

try {
    $Data = Import-Csv -Path $InputCsvPath
    $Results = @()

    $RunspacePool = [runspacefactory]::CreateRunspacePool(1, 10) # Min 1, Max 10 parallel runspaces
    $RunspacePool.Open()

    $Jobs = @()
    foreach ($Entry in $Data) {
        $HostName = $Entry.Host
        $Ports = $Entry.PSObject.Properties | Where-Object { $_.Name -ne "Host" } | Select-Object -ExpandProperty Value

        foreach ($Port in $Ports) {
            $ScriptBlock = {
                param($HostName, $Port)
                $Result = Test-NetConnection -ComputerName $HostName -Port $Port -InformationLevel Quiet -ErrorAction SilentlyContinue
                if ($Result.TcpTestSucceeded) {
                    $Status = "Green" # Success
                }
                elseif ($Result.PingSucceeded) {
                    $Status = "Amber" # Host reachable, port not open
                }
                else {
                    $Status = "Red" # Host not reachable
                }
                [PSCustomObject]@{
                    Host   = $HostName
                    Port   = $Port
                    Status = $Status
                }
            }
            $Job = [powershell]::Create().AddScript($ScriptBlock).AddArgument($HostName).AddArgument($Port)
            $Job.RunspacePool = $RunspacePool
            $Jobs += $Job.BeginInvoke()
        }
    }

    while ($Jobs.IsCompleted -contains $false) {
        Start-Sleep -Milliseconds 100
    }

    foreach ($Job in $Jobs) {
        $Results += $Job.EndInvoke()
    }

    $RunspacePool.Close()
    $RunspacePool.Dispose()

    if ($ExportPath) {
        if ($ExportPath.EndsWith(".csv")) {
            $Results | Export-Csv -Path $ExportPath -NoTypeInformation
        }
        elseif ($ExportPath.EndsWith(".html")) {
            $Results | ConvertTo-Html | Out-File -Path $ExportPath
        }
        else {
            Write-Warning "Invalid export path. Please specify a .csv or .html file."
        }
    }
    else {
        $Results | Format-Table -AutoSize
    }
}
catch {
    Write-Error "An error occurred: $($_.Exception.Message)"
}
