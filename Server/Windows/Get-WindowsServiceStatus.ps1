<#
.SYNOPSIS
Gets the status of a list of services on one or more computers.
#>
param (
    [string[]]$ComputerName,
    [string[]]$ServiceName
)

if (-not $ComputerName) {
    $ComputerName = $env:COMPUTERNAME
}

if (-not $ServiceName) {
    $ServiceName = "WinRM", "Spooler", "BITS"
}

$Result = foreach ($Computer in $ComputerName) {
    foreach ($Service in $ServiceName) {
        try {
            $ServiceStatus = Get-Service -ComputerName $Computer -Name $Service -ErrorAction Stop
            [PSCustomObject]@{
                ComputerName = $Computer
                ServiceName  = $ServiceStatus.Name
                DisplayName  = $ServiceStatus.DisplayName
                Status       = $ServiceStatus.Status
                StartType    = $ServiceStatus.StartType
            }
        }
        catch {
            Write-Warning "Failed to get status of service '$Service' on computer '$Computer'."
            [PSCustomObject]@{
                ComputerName = $Computer
                ServiceName  = $Service
                DisplayName  = "N/A"
                Status       = "N/A"
                StartType    = "N/A"
            }
        }
    }
}

$Result
