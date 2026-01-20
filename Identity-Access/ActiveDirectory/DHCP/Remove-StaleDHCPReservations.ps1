<#
.SYNOPSIS
Reports on stale DHCP reservations and offers an optional delete mode.
#>
[CmdletBinding(SupportsShouldProcess = $true)]
param (
    [string]$DHCPServer,
    [int]$StaleDays = 90, # Reservation is considered stale if last client activity is older than this
    [switch]$DeleteStaleReservations,
    [string]$ExportPath
)

if (-not $DHCPServer) {
    $DHCPServer = Read-Host "Enter the DHCP server name"
}

try {
    Write-Host "Getting DHCP scopes from $DHCPServer..."
    $Scopes = Get-DhcpServerv4Scope -ComputerName $DHCPServer -ErrorAction Stop

    $StaleReservations = @()
    foreach ($Scope in $Scopes) {
        Write-Verbose "Checking reservations in scope $($Scope.ScopeId) - $($Scope.Name)..."
        $Reservations = Get-DhcpServerv4Reservation -ComputerName $DHCPServer -ScopeId $Scope.ScopeId -ErrorAction SilentlyContinue

        foreach ($Reservation in $Reservations) {
            # Get associated lease to check last activity
            # This is tricky as there isn't a direct "LastActivity" for a reservation in Get-DhcpServerv4Reservation
            # We assume a reservation is stale if its associated lease is expired and hasn't renewed in StaleDays
            # Or if the reservation has no associated lease and was created long ago
            
            # For a more robust check, you might need to check Event Logs or rely on manual tracking.
            # For simplicity, we'll mark as potentially stale if no active lease.
            
            $AssociatedLease = Get-DhcpServerv4Lease -ComputerName $DHCPServer -IPAddress $Reservation.IPAddress -ErrorAction SilentlyContinue
            if (-not $AssociatedLease -or ($AssociatedLease.LeaseExpiryTime -lt (Get-Date).AddDays(-$StaleDays))) {
                $StaleReservations += [PSCustomObject]@{
                    DHCPServer      = $DHCPServer
                    ScopeId         = $Scope.ScopeId
                    ScopeName       = $Scope.Name
                    IPAddress       = $Reservation.IPAddress
                    MACAddress      = $Reservation.ClientId
                    HostName        = $Reservation.Name
                    Description     = $Reservation.Description
                    Status          = if ($AssociatedLease) { "Lease Expired (>$StaleDays)" } else { "No Active Lease" }
                }
            }
        }
    }

    if ($StaleReservations) {
        Write-Host "Found $($StaleReservations.Count) potentially stale DHCP reservations:"
        $StaleReservations | Format-Table -AutoSize

        if ($DeleteStaleReservations) {
            foreach ($Reservation in $StaleReservations) {
                if ($pscmdlet.ShouldProcess("Delete stale DHCP reservation '$($Reservation.IPAddress)' (Host: $($Reservation.HostName)) from scope $($Reservation.ScopeId)", "Delete Reservation")) {
                    Remove-DhcpServerv4Reservation -ComputerName $DHCPServer -ScopeId $Reservation.ScopeId -IPAddress $Reservation.IPAddress -ErrorAction Stop
                    Write-Host "Deleted stale reservation: $($Reservation.IPAddress) ($($Reservation.HostName))"
                }
            }
        }
    }
    else {
        Write-Host "No stale DHCP reservations found."
    }

    if ($ExportPath) {
        if ($ExportPath.EndsWith(".csv")) {
            $StaleReservations | Export-Csv -Path $ExportPath -NoTypeInformation
        }
        elseif ($ExportPath.EndsWith(".html")) {
            $StaleReservations | ConvertTo-Html | Out-File -Path $ExportPath
        }
        else {
            Write-Warning "Invalid export path. Please specify a .csv or .html file."
        }
    }
}
catch {
    Write-Error "An error occurred while managing DHCP reservations: $($_.Exception.Message)"
}
