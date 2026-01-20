<#
.SYNOPSIS
Gets the users currently logged on to one or more remote computers.
#>
param (
    [string[]]$ComputerName,
    [string]$ExportPath
)

if (-not $ComputerName) {
    $ComputerName = Read-Host "Enter a comma-separated list of computer names (e.g., PC1,PC2)"
    $ComputerName = $ComputerName.Split(',')
}

$Result = foreach ($Computer in $ComputerName) {
    Write-Verbose "Querying $Computer..."
    try {
        $Sessions = Invoke-Command -ComputerName $Computer -ScriptBlock {
            quser /SERVER:$env:COMPUTERNAME | Select-String -Pattern "(\S+)\s+(\S+)\s+(Disc|Actv)\s+(\d+)\s+(\d+)\s+(\d+:\d+)\s+(.+)" | ForEach-Object {
                $Matches = $_.Matches[0].Groups
                [PSCustomObject]@{
                    UserName     = $Matches[1].Value
                    SessionName  = $Matches[2].Value
                    State        = $Matches[3].Value
                    Id           = $Matches[4].Value
                    IdleTime     = $Matches[5].Value
                    LogonTime    = $Matches[6].Value
                    ClientName   = $Matches[7].Value # This might be IP or hostname
                    SessionType  = if ($Matches[2].Value -eq "console") { "Console" } elseif ($Matches[2].Value -like "rdp-tcp#*") { "RDP" } else { "Unknown" }
                }
            }
        } -ErrorAction Stop

        foreach ($Session in $Sessions) {
            [PSCustomObject]@{
                ComputerName = $Computer
                UserName     = $Session.UserName
                SessionName  = $Session.SessionName
                SessionType  = $Session.SessionType
                State        = $Session.State
                Id           = $Session.Id
                IdleTime     = $Session.IdleTime
                LogonTime    = $Session.LogonTime
                ClientName   = $Session.ClientName
            }
        }
    }
    catch {
        Write-Warning "Failed to get logged on users from '$Computer'. Error: $($_.Exception.Message)"
        [PSCustomObject]@{
            ComputerName = $Computer
            UserName     = "N/A"
            SessionName  = "N/A"
            SessionType  = "N/A"
            State        = "N/A"
            Id           = "N/A"
            IdleTime     = "N/A"
            LogonTime    = "N/A"
            ClientName   = "N/A"
            Error        = $_.Exception.Message
        }
    }
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
