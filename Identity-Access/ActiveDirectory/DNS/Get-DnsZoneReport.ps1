<#
.SYNOPSIS
Generates a report of all DNS zones and their records from a DNS server.
#>
param (
    [string]$ComputerName
)

if (-not $ComputerName) {
    $ComputerName = Read-Host "Enter the DNS server name"
}

try {
    $Zones = Get-DnsServerZone -ComputerName $ComputerName
    $Result = foreach ($Zone in $Zones) {
        $Records = Get-DnsServerResourceRecord -ComputerName $ComputerName -ZoneName $Zone.ZoneName
        foreach ($Record in $Records) {
            [PSCustomObject]@{
                ZoneName      = $Zone.ZoneName
                RecordType    = $Record.RecordType
                HostName      = $Record.HostName
                RecordData    = $Record.RecordData
            }
        }
    }
    $Result
}
catch {
    Write-Error "Failed to get DNS zone report from '$ComputerName'. Please ensure the DNS server name is correct and you have the necessary permissions."
}
