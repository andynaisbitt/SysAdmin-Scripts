<#
.SYNOPSIS
Queries Domain Controller event logs for account lockout events and identifies the source workstation/IP and timeline.
#>
param (
    [string]$UserName,
    [string[]]$DomainControllerName, # Optional: Specific DCs to query
    [int]$LookbackHours = 24,
    [string]$ExportPath
)

if (-not $UserName) {
    $UserName = Read-Host "Enter the username to find lockout source for"
}

# Find all Domain Controllers if not specified
if (-not $DomainControllerName) {
    Write-Verbose "Discovering Domain Controllers..."
    try {
        $DomainControllerName = (Get-ADDomainController -Filter * | Select-Object -ExpandProperty HostName)
    }
    catch {
        Write-Warning "Failed to discover Domain Controllers. Please specify them manually or ensure AD module is loaded and accessible. Error: $($_.Exception.Message)"
        $DomainControllerName = @("localhost") # Fallback
    }
}

$Result = @()
foreach ($DC in $DomainControllerName) {
    Write-Verbose "Querying $DC for lockout events for user '$UserName'..."
    try {
        $FilterHashTable = @{
            LogName = 'Security'
            ID      = 4740 # Event ID for Account Lockout
            StartTime = (Get-Date).AddHours(-$LookbackHours)
            EndTime = Get-Date
        }

        $LockoutEvents = Get-WinEvent -ComputerName $DC -FilterHashtable $FilterHashTable -ErrorAction Stop

        foreach ($Event in $LockoutEvents) {
            $Properties = [Ordered]@{}
            $Event.Properties | ForEach-Object { $Properties[$_.ItemKey] = $_.Value }

            if ($Properties.TargetUserName -eq $UserName) {
                # Event 4740 provides: TargetUserName, TargetDomainName, CallerComputerName
                # For source IP, you often need to correlate with 4625 (failed logon) events just before 4740
                # or check the CallerComputerName. This script will focus on 4740's direct info.
                
                # To get source IP, often we need to parse Event ID 4625 from the same DC,
                # near the same time, for the same user, with LogonType 3 (Network)
                # This is a more advanced correlation. For this script, we'll get what 4740 provides.
                $SourceWorkstation = $Properties.CallerComputerName # From event 4740
                
                $Result += [PSCustomObject]@{
                    Timestamp         = $Event.TimeCreated
                    DomainController  = $DC
                    UserName          = $Properties.TargetUserName
                    SourceWorkstation = $SourceWorkstation
                    EventMessage      = $Event.Message.Trim().Split("`n")[0] # Just first line of message
                }
            }
        }
    }
    catch {
        Write-Warning "Failed to query lockout events from '$DC'. Error: $($_.Exception.Message)"
        $Result += [PSCustomObject]@{
            Timestamp         = "Error"
            DomainController  = $DC
            UserName          = $UserName
            SourceWorkstation = "Error"
            EventMessage      = $_.Exception.Message
        }
    }
}

if ($Result) {
    Write-Host "Found $($Result.Count) lockout events for user '$UserName'."
    $Result | Format-Table -AutoSize
} else {
    Write-Host "No lockout events found for user '$UserName' in the last $LookbackHours hours."
}


if ($ExportPath) {
    if ($ExportPath.EndsWith(".csv")) {
        $Result | Export-Csv -Path $ExportPath -NoTypeInformation
    }
    elseif ($ExportPath.EndsWith(".html")) {
        $Result | ConvertTo-Html -Title "Account Lockout Source Report for $UserName" | Out-File -Path $ExportPath
    }
    else {
        Write-Warning "Invalid export path. Please specify a .csv or .html file."
    }
}
else {
    $Result | Format-Table -AutoSize
}
