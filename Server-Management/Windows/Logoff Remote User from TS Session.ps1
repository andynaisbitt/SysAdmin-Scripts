<#
.SYNOPSIS
Logs off a remote user from a terminal server session.
#>
param (
    [string]$UserName,
    [string]$ServerListFile = ".\servers.txt"
)

if (-not $UserName) {
    $UserName = Read-Host "Enter the user name to log off"
}

$Servers = Get-Content -Path $ServerListFile -ErrorAction SilentlyContinue

foreach ($Server in $Servers) {
    try {
        $Session = Get-RDUserSession -ComputerName $Server | Where-Object { $_.UserName -eq $UserName }
        if ($Session) {
            Disconnect-RDUser -HostServer $Server -UnifiedSessionID $Session.UnifiedSessionId -Force
        }
    }
    catch {
        Write-Warning "Failed to log off user '$UserName' from server '$Server'."
    }
}
