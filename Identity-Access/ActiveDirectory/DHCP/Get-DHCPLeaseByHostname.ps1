<#
.SYNOPSIS
Searches DHCP leases across all scopes on a DHCP server, showing IP, MAC, and expiry.
#>
param (
    [string]$DHCPServer,
    [string]$HostnameFilter, # Optional: Filter leases by hostname
    [string]$ExportPath
)

if (-not $DHCPServer) {
    $DHCPServer = Read-Host "Enter the DHCP server name"
}

try {
    Write-Host "Getting DHCP scopes from $DHCPServer..."
    $Scopes = Get-DhcpServerv4Scope -ComputerName $DHCPServer -ErrorAction Stop

    $Result = @()
    foreach ($Scope in $Scopes) {
        Write-Verbose "Checking leases in scope $($Scope.ScopeId) - $($Scope.Name)..."
        $Leases = Get-DhcpServerv4Lease -ComputerName $DHCPServer -ScopeId $Scope.ScopeId -ErrorAction SilentlyContinue

        foreach ($Lease in $Leases) {
            if (-not $HostnameFilter -or ($Lease.HostName -like "*$HostnameFilter*")) {
                $Result += [PSCustomObject]@{
                    DHCPServer      = $DHCPServer
                    ScopeId         = $Scope.ScopeId
                    ScopeName       = $Scope.Name
                    IPAddress       = $Lease.IPAddress
                    MACAddress      = $Lease.ClientId
                    HostName        = $Lease.HostName
                    LeaseExpiryTime = $Lease.LeaseExpiryTime
                    AddressState    = $Lease.AddressState
                }
            }
        }
    }

    if ($Result) {
        Write-Host "Found $($Result.Count) matching DHCP leases."
    }
    else {
        Write-Host "No matching DHCP leases found."
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
    Write-Error "An error occurred while getting DHCP leases: $($_.Exception.Message)"
}
