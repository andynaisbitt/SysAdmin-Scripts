<#
.SYNOPSIS
Generates a report of BSOD events from one or more computers.
#>
param (
    [string[]]$ComputerName,
    [int]$Days = 30
)

if (-not $ComputerName) {
    $ComputerName = $env:COMPUTERNAME
}

$Result = foreach ($Computer in $ComputerName) {
    try {
        $Events = Get-WinEvent -ComputerName $Computer -FilterHashtable @{
            LogName   = 'System'
            ID        = 1001
            StartTime = (Get-Date).AddDays(-$Days)
        } -ErrorAction Stop

        foreach ($Event in $Events) {
            $Message = $Event.Message
            $BugCheckCode = $Message -match 'Bugcheck code: (.*)' | Out-Null; $BugCheckCode = $matches[1]
            $BugCheckParams = $Message -match 'Bugcheck parameters: (.*)' | Out-Null; $BugCheckParams = $matches[1]

            [PSCustomObject]@{
                ComputerName   = $Computer
                TimeCreated    = $Event.TimeCreated
                BugCheckCode   = $BugCheckCode
                BugCheckParams = $BugCheckParams
            }
        }
    }
    catch {
        Write-Warning "Failed to get BSOD events from '$Computer'."
    }
}

$Result
