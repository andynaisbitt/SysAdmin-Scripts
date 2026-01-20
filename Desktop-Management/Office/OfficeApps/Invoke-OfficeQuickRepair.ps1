<#
.SYNOPSIS
Triggers Office Click-to-Run Quick Repair (and optionally Online Repair) with clear warnings.
#>
[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
param (
    [string]$ComputerName = "localhost",
    [switch]$OnlineRepair # If present, performs an online repair (requires internet and longer time)
)

$Result = [PSCustomObject]@{
    ComputerName = $ComputerName
    RepairType   = if ($OnlineRepair) { "Online Repair" } else { "Quick Repair" }
    ActionTaken  = "None"
    Outcome      = "N/A"
    OverallStatus = "Failed"
    Errors       = @()
}

try {
    Write-Host "--- Starting Office Repair on $ComputerName ---"

    Invoke-Command -ComputerName $ComputerName -ScriptBlock {
        param ($OnlineRepair)

        $OfficeC2RPath = "$env:ProgramFiles\Common Files\Microsoft Shared\ClickToRun\OfficeC2RClient.exe"
        if (-not (Test-Path -Path $OfficeC2RPath)) {
            throw "Office Click-to-Run client not found at $OfficeC2RPath."
        }

        $RepairArgs = if ($OnlineRepair) {
            Write-Warning "Online Repair will download a fresh copy of Office and may take a long time."
            "repair C_NAME=O365ProPlusRetail R_TYPE=Full" # Full/Online Repair
        }
        else {
            "repair C_NAME=O365ProPlusRetail R_TYPE=Quick" # Quick Repair
        }
        
        Write-Host "Triggering Office repair: $RepairArgs"
        if ($pscmdlet.ShouldProcess("Trigger Office $($Result.RepairType) on '$using:ComputerName'", "Perform Office Repair")) {
            try {
                Start-Process -FilePath $OfficeC2RPath -ArgumentList $RepairArgs -Wait -NoNewWindow -ErrorAction Stop
                $Result.ActionTaken = "Repair Initiated"
                $Result.Outcome = "Repair process started successfully."
                Write-Host "Office repair process completed."
            }
            catch {
                Write-Warning "Failed to trigger Office repair: $($_.Exception.Message)"
                $Result.Errors += "Repair Trigger Failed: $($_.Exception.Message)"
                $Result.Outcome = "Failed to start repair process."
            }
        }
    } -ArgumentList $OnlineRepair -ErrorAction Stop

    $Result.OverallStatus = "Success"
}
catch {
    $Result.OverallStatus = "Failed"
    $Result.Errors += $_.Exception.Message
    Write-Error "An error occurred during Office repair: $($_.Exception.Message)"
}

if ($ExportPath) {
    $Result | Export-Csv -Path $ExportPath -NoTypeInformation -Force
}
else {
    $Result | Format-List
}
