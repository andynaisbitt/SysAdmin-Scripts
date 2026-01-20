<#
.SYNOPSIS
Discovers devices on a network by scanning a subnet for open ports and gathering system information.
#>
param (
    [string]$Subnet,
    [int[]]$Ports = @(22, 80, 135, 443, 445, 3389, 5985, 5986)
)

if (-not $Subnet) {
    $Subnet = Read-Host "Enter the subnet to scan (e.g., 192.168.1.0/24)"
}

try {
    # Get the IP network and broadcast address from the subnet
    $IpNetwork = [System.Net.IPNetwork]::Parse($Subnet)
    $NetworkAddress = $IpNetwork.Network.ToString()
    $BroadcastAddress = $IpNetwork.Broadcast.ToString()

    # Get a list of all IP addresses in the subnet
    $Addresses = $IpNetwork.ListIPAddress()

    $Result = foreach ($Address in $Addresses) {
        $IpAddress = $Address.ToString()
        if ($IpAddress -eq $NetworkAddress -or $IpAddress -eq $BroadcastAddress) {
            continue
        }

        $OpenPorts = @()
        foreach ($Port in $Ports) {
            $Connection = Test-NetConnection -ComputerName $IpAddress -Port $Port -WarningAction SilentlyContinue -InformationLevel Quiet
            if ($Connection.TcpTestSucceeded) {
                $OpenPorts += $Port
            }
        }

        if ($OpenPorts.Count -gt 0) {
            $CimInfo = try {
                Get-CimInstance -ClassName Win32_OperatingSystem -ComputerName $IpAddress -ErrorAction Stop
            }
            catch {
                $null
            }

            [PSCustomObject]@{
                IPAddress    = $IpAddress
                OpenPorts    = $OpenPorts -join ","
                ComputerName = if ($CimInfo) { $CimInfo.CSName } else { "N/A" }
                OS           = if ($CimInfo) { $CimInfo.Caption } else { "N/A" }
            }
        }
    }
    $Result
}
catch {
    Write-Error "Failed to scan network. Please ensure the subnet is correct and you have the necessary permissions."
}
