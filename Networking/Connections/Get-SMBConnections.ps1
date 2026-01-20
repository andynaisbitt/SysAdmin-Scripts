<#
.SYNOPSIS
Shows active SMB client connections, sessions, dialect, encryption/signing, and bytes transferred.
#>
param (
    [string]$ComputerName
)

if (-not $ComputerName) {
    $ComputerName = Read-Host "Enter the file server name"
}

try {
    # Get SMB sessions
    $Sessions = Get-SmbSession -ComputerName $ComputerName -ErrorAction Stop

    $Result = foreach ($Session in $Sessions) {
        # Get SMB connections for the session (might be multiple)
        $Connections = Get-SmbConnection -ComputerName $ComputerName | Where-Object { $_.SessionId -eq $Session.SessionId }

        foreach ($Connection in $Connections) {
            [PSCustomObject]@{
                ComputerName        = $ComputerName
                ClientIPAddress     = $Session.ClientComputerName
                UserName            = $Session.ClientUserName
                SessionId           = $Session.SessionId
                ConnectionId        = $Connection.ConnectionId
                Dialect             = $Connection.Dialect
                EncryptData         = $Connection.EncryptData
                Signed              = $Connection.Signed
                BytesReceived       = $Connection.BytesReceived
                BytesSent           = $Connection.BytesSent
            }
        }
    }
    $Result
}
catch {
    Write-Error "An error occurred while getting SMB connections from '$ComputerName': $($_.Exception.Message)"
}
