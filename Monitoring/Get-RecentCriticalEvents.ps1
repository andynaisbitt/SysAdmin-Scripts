<#
.SYNOPSIS
Retrieves recent critical events from specified event logs.
#>
param (
    [string[]]$ComputerName,
    [string[]]$LogName = @("System", "Application"),
    [int]$TimeInHours = 24,
    [string]$ExportPath
)

if (-not $ComputerName) {
    $ComputerName = $env:COMPUTERNAME
}

$Result = foreach ($Computer in $ComputerName) {
    Write-Verbose "Checking critical events on $Computer..."
    try {
        $EndTime = Get-Date
        $StartTime = $EndTime.AddHours(-$TimeInHours)

        foreach ($Log in $LogName) {
            Get-WinEvent -ComputerName $Computer -FilterHashtable @{
                LogName   = $Log
                Level     = @(1, 2) # 1 = Critical, 2 = Error
                StartTime = $StartTime
                EndTime   = $EndTime
            } -ErrorAction SilentlyContinue | ForEach-Object {
                [PSCustomObject]@{
                    ComputerName = $Computer
                    LogName      = $_.LogName
                    Id           = $_.Id
                    LevelDisplayName = $_.LevelDisplayName
                    TimeCreated  = $_.TimeCreated
                    Message      = $_.Message
                }
            }
        }
    }
    catch {
        Write-Warning "Failed to retrieve critical events from '$Computer'. Error: $($_.Exception.Message)"
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
