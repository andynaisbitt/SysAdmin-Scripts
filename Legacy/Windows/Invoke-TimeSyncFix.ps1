<#
.SYNOPSIS
Resets and resynchronizes the Windows Time service (w32time) on local or remote computers.
#>
[CmdletBinding(SupportsShouldProcess = $true)]
param (
    [string]$ComputerName
)

if (-not $ComputerName) {
    $ComputerName = $env:COMPUTERNAME
}

$Result = [PSCustomObject]@{
    ComputerName = $ComputerName
    BeforeSyncStatus = "N/A"
    BeforeSyncSource = "N/A"
    AfterSyncStatus = "N/A"
    AfterSyncSource = "N/A"
    OverallStatus = "Failed"
    Errors = @()
}

try {
    Write-Host "--- Performing Time Synchronization Fix on '$ComputerName' ---"

    Invoke-Command -ComputerName $ComputerName -ScriptBlock {
        # --- Before Status ---
        $w32tmBeforeStatus = w32tm /query /status 2>&1 | Out-String
        $w32tmBeforeSource = ($w32tmBeforeStatus | Select-String -Pattern "Source: (.+)" | ForEach-Object { $_.Matches[0].Groups[1].Value }).Trim()
        $w32tmBeforeStratum = ($w32tmBeforeStatus | Select-String -Pattern "Stratum: (.+)" | ForEach-Object { $_.Matches[0].Groups[1].Value }).Trim()
        
        $using:Result.BeforeSyncStatus = "Stratum: $w32tmBeforeStratum"
        $using:Result.BeforeSyncSource = $w32tmBeforeSource
        Write-Host "Before Sync Status: Stratum $w32tmBeforeStratum, Source: $w32tmBeforeSource"

        # 1. Stop and Reset w32time
        if ($pscmdlet.ShouldProcess("Stop and reset w32time service on '$using:ComputerName'", "Reset Time Service")) {
            Stop-Service w32time -ErrorAction SilentlyContinue
            w32tm /unregister -ErrorAction SilentlyContinue
            w32tm /register -ErrorAction SilentlyContinue
            Start-Service w32time -ErrorAction Stop
            Write-Host "w32time service stopped, unregistered, re-registered, and started."
        }

        # 2. Configure to use domain hierarchy
        if ($pscmdlet.ShouldProcess("Configure w32time to use domain hierarchy on '$using:ComputerName'", "Configure Time Service")) {
            w32tm /config /syncfromflags:DOMHIER /update -ErrorAction Stop
            Write-Host "w32time configured to use domain hierarchy."
        }
        
        # 3. Resync
        if ($pscmdlet.ShouldProcess("Force resynchronization on '$using:ComputerName'", "Resync Time")) {
            w32tm /resync /force -ErrorAction Stop
            Write-Host "Time resynchronization forced."
        }

        # --- After Status ---
        Start-Sleep -Seconds 5 # Give some time for sync to happen
        $w32tmAfterStatus = w32tm /query /status 2>&1 | Out-String
        $w32tmAfterSource = ($w32tmAfterStatus | Select-String -Pattern "Source: (.+)" | ForEach-Object { $_.Matches[0].Groups[1].Value }).Trim()
        $w32tmAfterStratum = ($w32tmAfterStatus | Select-String -Pattern "Stratum: (.+)" | ForEach-Object { $_.Matches[0].Groups[1].Value }).Trim()

        $using:Result.AfterSyncStatus = "Stratum: $w32tmAfterStratum"
        $using:Result.AfterSyncSource = $w32tmAfterSource
        Write-Host "After Sync Status: Stratum $w32tmAfterStratum, Source: $w32tmAfterSource"

        $using:Result.OverallStatus = "Success"
    } -ErrorAction Stop

}
catch {
    $Result.OverallStatus = "Failed"
    $Result.Errors += $_.Exception.Message
    Write-Error "An error occurred during time sync fix on '$ComputerName': $($_.Exception.Message)"
}

$Result | Format-List
