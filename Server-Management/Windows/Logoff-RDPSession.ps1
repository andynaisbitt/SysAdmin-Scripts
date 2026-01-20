<#
.SYNOPSIS
Safely logs off a Remote Desktop Protocol (RDP) session by username or session ID.
#>
[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
param (
    [string]$ComputerName,
    [string]$UserName,
    [int]$SessionId
)

if (-not $ComputerName) {
    $ComputerName = Read-Host "Enter the computer name"
}

if (-not $UserName -and -not $SessionId) {
    Write-Error "Please specify either a UserName or a SessionId to log off."
    return
}

try {
    Write-Verbose "Getting RDP sessions on $ComputerName..."
    $Sessions = Get-RDPSessions -ComputerName $ComputerName -ErrorAction Stop

    $SessionToLogoff = $null
    if ($UserName) {
        $SessionToLogoff = $Sessions | Where-Object { $_.UserName -eq $UserName }
    }
    elseif ($SessionId) {
        $SessionToLogoff = $Sessions | Where-Object { $_.Id -eq $SessionId }
    }

    if ($SessionToLogoff) {
        foreach ($Session in $SessionToLogoff) {
            if ($pscmdlet.ShouldProcess("Log off session $($Session.Id) (User: $($Session.UserName)) on '$ComputerName'", "Log Off Session")) {
                # Disconnect-RDUser requires the Remote Desktop Services PowerShell module.
                # If not available, we can fall back to 'logoff' command line utility.
                try {
                    Disconnect-RDUser -HostServer $ComputerName -UnifiedSessionID $Session.Id -Force -ErrorAction Stop
                    Write-Host "Session $($Session.Id) for user $($Session.UserName) logged off from '$ComputerName'."
                }
                catch {
                    Write-Warning "Disconnect-RDUser failed. Falling back to 'logoff' command. Error: $($_.Exception.Message)"
                    Invoke-Command -ComputerName $ComputerName -ScriptBlock {
                        logoff $using:Session.Id
                    } -ErrorAction Stop
                    Write-Host "Session $($Session.Id) for user $($Session.UserName) logged off from '$ComputerName' using 'logoff' command."
                }
            }
        }
    }
    else {
        Write-Warning "No active session found for User: '$UserName' or Session ID: '$SessionId' on '$ComputerName'."
    }
}
catch {
    Write-Error "An error occurred while logging off RDP session: $($_.Exception.Message)"
}
