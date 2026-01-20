<#
.SYNOPSIS
Takes multiple snapshots of network connections, diffs them, and highlights new connections and top talkers.
#>
param (
    [int]$Snapshots = 3,
    [int]$IntervalSeconds = 5
)

try {
    $AllSnapshots = @()

    for ($i = 0; $i -lt $Snapshots; $i++) {
        Write-Host "Taking snapshot $($i + 1) of $Snapshots..."
        $CurrentSnapshot = Get-NetTCPConnection | Select-Object -Property LocalAddress, LocalPort, RemoteAddress, RemotePort, State, OwningProcess, @{Name='Timestamp';Expression={Get-Date}}
        $AllSnapshots += $CurrentSnapshot
        Start-Sleep -Seconds $IntervalSeconds
    }

    if ($AllSnapshots.Count -ge 2) {
        $FirstSnapshot = $AllSnapshots[0]
        $LastSnapshot = $AllSnapshots[-1]

        Write-Host "`n--- New Connections ---"
        $NewConnections = Compare-Object -ReferenceObject $FirstSnapshot -DifferenceObject $LastSnapshot -Property LocalAddress, LocalPort, RemoteAddress, RemotePort -IncludeEqual:$false | Where-Object { $_.SideIndicator -eq "=>" }
        $NewConnections | Format-Table

        Write-Host "`n--- Top Talkers (by Remote Address) ---"
        $AllSnapshots | Group-Object RemoteAddress | Select-Object -Property Name, Count | Sort-Object -Property Count -Descending | Select-Object -First 10 | Format-Table
    }
    else {
        Write-Warning "Not enough snapshots taken to perform a meaningful diff."
    }
}
catch {
    Write-Error "An error occurred: $($_.Exception.Message)"
}
