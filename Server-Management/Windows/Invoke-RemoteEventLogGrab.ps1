<#
.SYNOPSIS
Retrieves event logs with specific Event IDs and within a time window from multiple remote servers.
#>
param (
    [string[]]$ComputerName,
    [string[]]$LogName = @("System", "Application"),
    [int[]]$EventId,
    [datetime]$StartTime,
    [datetime]$EndTime = (Get-Date),
    [string]$ExportPath
)

if (-not $ComputerName) {
    $ComputerName = $env:COMPUTERNAME
}

if (-not $StartTime) {
    $StartTime = (Read-Host "Enter start time (e.g., 'yesterday', '1 week ago', or specific date/time)").Trim()
    try {
        if ($StartTime -eq "yesterday") { $StartTime = (Get-Date).AddDays(-1) }
        elseif ($StartTime -eq "1 week ago") { $StartTime = (Get-Date).AddDays(-7) }
        else { $StartTime = [datetime]$StartTime }
    }
    catch {
        Write-Error "Invalid StartTime format. Please use 'yesterday', '1 week ago', or a valid datetime string."
        return
    }
}

$Result = @()
foreach ($Computer in $ComputerName) {
    Write-Verbose "Grabbing event logs from $Computer..."
    try {
        $FilterHashTable = @{
            LogName   = $LogName
            StartTime = $StartTime
            EndTime   = $EndTime
        }
        if ($EventId) {
            $FilterHashTable.Add("Id", $EventId)
        }

        $Events = Get-WinEvent -ComputerName $Computer -FilterHashtable $FilterHashTable -ErrorAction Stop

        foreach ($Event in $Events) {
            $Result += [PSCustomObject]@{
                ComputerName = $Computer
                LogName      = $Event.LogName
                Id           = $Event.Id
                LevelDisplayName = $Event.LevelDisplayName
                TimeCreated  = $Event.TimeCreated
                Message      = $Event.Message
            }
        }
    }
    catch {
        Write-Warning "Failed to grab event logs from '$Computer'. Error: $($_.Exception.Message)"
        $Result += [PSCustomObject]@{
            ComputerName = $Computer
            LogName      = "Error"
            Id           = "N/A"
            LevelDisplayName = "Error"
            TimeCreated  = "N/A"
            Message      = $_.Exception.Message
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
