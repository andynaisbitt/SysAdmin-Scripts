<#
.SYNOPSIS
A wrapper around Get-NetTCPConnection to show process owner and service name.
#>
param (
    [int]$LocalPort,
    [string]$RemoteAddress,
    [string]$State
)

try {
    $Connections = Get-NetTCPConnection
    
    if ($LocalPort) {
        $Connections = $Connections | Where-Object { $_.LocalPort -eq $LocalPort }
    }
    if ($RemoteAddress) {
        $Connections = $Connections | Where-Object { $_.RemoteAddress -like "*$RemoteAddress*" }
    }
    if ($State) {
        $Connections = $Connections | Where-Object { $_.State -eq $State }
    }

    $Result = foreach ($Connection in $Connections) {
        $Process = Get-Process -Id $Connection.OwningProcess -ErrorAction SilentlyContinue
        $ServiceName = (Get-WmiObject -Class Win32_Service -Filter "ProcessId = $($Connection.OwningProcess)" -ErrorAction SilentlyContinue).Name

        [PSCustomObject]@{
            LocalAddress  = $Connection.LocalAddress
            LocalPort     = $Connection.LocalPort
            RemoteAddress = $Connection.RemoteAddress
            RemotePort    = $Connection.RemotePort
            State         = $Connection.State
            ProcessName   = if ($Process) { $Process.ProcessName } else { "N/A" }
            PID           = $Connection.OwningProcess
            ServiceName   = if ($ServiceName) { $ServiceName } else { "N/A" }
        }
    }
    $Result
}
catch {
    Write-Error "An error occurred: $($_.Exception.Message)"
}
