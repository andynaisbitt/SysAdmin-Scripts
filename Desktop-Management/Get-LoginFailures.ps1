<#
.SYNOPSIS
Pulls recent failed logon attempts from the Security event log, including time, failure reason, source IP, and workstation name.
#>
param (
    [string[]]$ComputerName,
    [string]$UserName, # Optional: Filter by specific user
    [int]$Hours = 24, # Look back in the last N hours
    [string]$ExportPath
)

if (-not $ComputerName) {
    $ComputerName = $env:COMPUTERNAME
}

$Result = foreach ($Computer in $ComputerName) {
    Write-Verbose "Checking login failures on $Computer..."
    try {
        $FilterHashTable = @{
            LogName = 'Security'
            ID = 4625 # Event ID for failed logon
            StartTime = (Get-Date).AddHours(-$Hours)
            EndTime = Get-Date
        }
        
        $Events = Get-WinEvent -ComputerName $Computer -FilterHashtable $FilterHashTable -ErrorAction Stop

        foreach ($Event in $Events) {
            $Properties = [Ordered]@{}
            $Event.Properties | ForEach-Object { $Properties[$_.ItemKey] = $_.Value }

            $TargetUserName = $Properties.TargetUserName
            if ($UserName -and $TargetUserName -notlike "*$UserName*") {
                continue # Skip if specific user filter is applied and doesn't match
            }

            [PSCustomObject]@{
                ComputerName = $Computer
                TimeCreated  = $Event.TimeCreated
                TargetUserName = $TargetUserName
                LogonType    = $Properties.LogonType
                FailureReason = $Properties.FailureReason # Message for 4625
                SubStatus    = $Properties.SubStatus
                SourceIp     = $Properties.IpAddress
                WorkstationName = $Properties.WorkstationName
            }
        }
    }
    catch {
        Write-Warning "Failed to retrieve login failures from '$Computer'. Error: $($_.Exception.Message)"
        [PSCustomObject]@{
            ComputerName = $Computer
            TimeCreated  = "Error"
            TargetUserName = "Error"
            LogonType    = "Error"
            FailureReason = "Error"
            SubStatus    = "Error"
            SourceIp     = "Error"
            WorkstationName = "Error"
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
