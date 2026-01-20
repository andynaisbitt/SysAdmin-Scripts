<#
.SYNOPSIS
Lists Remote Desktop Protocol (RDP) sessions on a server, including idle time, username, and session type.
#>
param (
    [string[]]$ComputerName,
    [string]$ExportPath
)

if (-not $ComputerName) {
    $ComputerName = $env:COMPUTERNAME
}

$Result = foreach ($Computer in $ComputerName) {
    Write-Verbose "Getting RDP sessions from $Computer..."
    try {
        Invoke-Command -ComputerName $Computer -ScriptBlock {
            quser /SERVER:$using:Computer | Select-String -Pattern "(\S+)\s+(\S+)\s+(Disc|Actv)\s+(\d+)\s+(\d+)\s+(\d+:\d+)\s+(.+)" | ForEach-Object {
                $Matches = $_.Matches[0].Groups
                [PSCustomObject]@{
                    ComputerName = $using:Computer
                    UserName     = $Matches[1].Value
                    SessionName  = $Matches[2].Value
                    SessionType  = if ($Matches[2].Value -eq "console") { "Console" } elseif ($Matches[2].Value -like "rdp-tcp#*") { "RDP" } else { "Unknown" }
                    State        = $Matches[3].Value
                    Id           = $Matches[4].Value
                    IdleTime     = $Matches[5].Value
                    LogonTime    = $Matches[6].Value
                    ClientName   = $Matches[7].Value
                }
            }
        } -ErrorAction Stop
    }
    catch {
        Write-Warning "Failed to get RDP sessions from '$Computer'. Error: $($_.Exception.Message)"
        [PSCustomObject]@{
            ComputerName = $Computer
            UserName     = "Error"
            SessionName  = "Error"
            SessionType  = "Error"
            State        = "Error"
            Id           = "Error"
            IdleTime     = "Error"
            LogonTime    = "Error"
            ClientName   = "Error"
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
