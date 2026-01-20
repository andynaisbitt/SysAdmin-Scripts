<#
.SYNOPSIS
Generates a report of all DHCP scopes and their utilization from a DHCP server.
#>
param (
    [string]$ComputerName
)

if (-not $ComputerName) {
    $ComputerName = Read-Host "Enter the DHCP server name"
}

try {
    $Scopes = Get-DhcpServerv4Scope -ComputerName $ComputerName
    $Result = foreach ($Scope in $Scopes) {
        $ScopeStats = Get-DhcpServerv4ScopeStatistics -ComputerName $ComputerName -ScopeId $Scope.ScopeId
        [PSCustomObject]@{
            ScopeId         = $Scope.ScopeId
            Name            = $Scope.Name
            SubnetMask      = $Scope.SubnetMask
            StartRange      = $Scope.StartRange
            EndRange        = $Scope.EndRange
            State           = $Scope.State
            LeasesInUse     = $ScopeStats.InUse
            LeasesAvailable = $ScopeStats.Available
            PercentUsed     = $ScopeStats.PercentageInUse
        }
    }
    $Result
}
catch {
    Write-Error "Failed to get DHCP scope report from '$ComputerName'. Please ensure the DHCP server name is correct and you have the necessary permissions."
}
