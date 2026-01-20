<#
.SYNOPSIS
Triggers common MECM (SCCM) client actions remotely, such as hardware inventory, software inventory, and policy retrieval.
#>
[CmdletBinding(SupportsShouldProcess = $true)]
param (
    [string]$ComputerName = "localhost",
    [switch]$HardwareInventory,
    [switch]$SoftwareInventory,
    [switch]$ApplicationDeploymentEvaluation,
    [switch]$UserPolicyRetrievalAndEvaluation,
    [switch]$MachinePolicyRetrievalAndEvaluation,
    [switch]$DiscoveryDataCollection
)

$Result = [PSCustomObject]@{
    ComputerName = $ComputerName
    ActionsAttempted = @()
    OverallStatus = "Failed"
    Errors = @()
}

try {
    Write-Host "--- Triggering MECM Client Actions on $ComputerName ---"

    Invoke-Command -ComputerName $ComputerName -ScriptBlock {
        $CcmClient = Get-WmiObject -Namespace "root\ccm" -Class "SMS_Client" -ErrorAction SilentlyContinue
        if (-not $CcmClient) {
            throw "MECM client WMI class 'SMS_Client' not found. Is MECM client installed and healthy?"
        }

        # Hardware Inventory Cycle
        if ($using:HardwareInventory) {
            if ($pscmdlet.ShouldProcess("Trigger Hardware Inventory Cycle", "MECM Action")) {
                try {
                    $CcmClient.TriggerSchedule("{00000000-0000-0000-0000-000000000001}") # Hardware Inventory Cycle
                    $using:Result.ActionsAttempted += "Hardware Inventory"
                    Write-Host "Hardware Inventory cycle triggered."
                } catch { $using:Result.Errors += "HW Inventory: $($_.Exception.Message)" }
            }
        }

        # Software Inventory Cycle
        if ($using:SoftwareInventory) {
            if ($pscmdlet.ShouldProcess("Trigger Software Inventory Cycle", "MECM Action")) {
                try {
                    $CcmClient.TriggerSchedule("{00000000-0000-0000-0000-000000000002}") # Software Inventory Cycle
                    $using:Result.ActionsAttempted += "Software Inventory"
                    Write-Host "Software Inventory cycle triggered."
                } catch { $using:Result.Errors += "SW Inventory: $($_.Exception.Message)" }
            }
        }

        # Application Deployment Evaluation Cycle
        if ($using:ApplicationDeploymentEvaluation) {
            if ($pscmdlet.ShouldProcess("Trigger Application Deployment Evaluation Cycle", "MECM Action")) {
                try {
                    $CcmClient.TriggerSchedule("{00000000-0000-0000-0000-000000000003}") # App Deployment Evaluation Cycle
                    $using:Result.ActionsAttempted += "App Deployment Evaluation"
                    Write-Host "Application Deployment Evaluation cycle triggered."
                } catch { $using:Result.Errors += "App Deployment: $($_.Exception.Message)" }
            }
        }
        
        # User Policy Retrieval & Evaluation Cycle
        if ($using:UserPolicyRetrievalAndEvaluation) {
            if ($pscmdlet.ShouldProcess("Trigger User Policy Retrieval & Evaluation Cycle", "MECM Action")) {
                try {
                    $CcmClient.TriggerSchedule("{00000000-0000-0000-0000-000000000004}") # User Policy Retrieval & Evaluation Cycle
                    $using:Result.ActionsAttempted += "User Policy Retrieval"
                    Write-Host "User Policy Retrieval & Evaluation cycle triggered."
                } catch { $using:Result.Errors += "User Policy: $($_.Exception.Message)" }
            }
        }

        # Machine Policy Retrieval & Evaluation Cycle
        if ($using:MachinePolicyRetrievalAndEvaluation) {
            if ($pscmdlet.ShouldProcess("Trigger Machine Policy Retrieval & Evaluation Cycle", "MECM Action")) {
                try {
                    $CcmClient.TriggerSchedule("{00000000-0000-0000-0000-000000000005}") # Machine Policy Retrieval & Evaluation Cycle
                    $using:Result.ActionsAttempted += "Machine Policy Retrieval"
                    Write-Host "Machine Policy Retrieval & Evaluation cycle triggered."
                } catch { $using:Result.Errors += "Machine Policy: $($_.Exception.Message)" }
            }
        }
        
        # Discovery Data Collection Cycle
        if ($using:DiscoveryDataCollection) {
            if ($pscmdlet.ShouldProcess("Trigger Discovery Data Collection Cycle", "MECM Action")) {
                try {
                    $CcmClient.TriggerSchedule("{00000000-0000-0000-0000-000000000006}") # Discovery Data Collection Cycle
                    $using:Result.ActionsAttempted += "Discovery Data Collection"
                    Write-Host "Discovery Data Collection cycle triggered."
                } catch { $using:Result.Errors += "DDC: $($_.Exception.Message)" }
            }
        }

        if ($using:Result.Errors.Count -eq 0) { $using:Result.OverallStatus = "Success" } else { $using:Result.OverallStatus = "Completed with Errors" }

    } -ErrorAction Stop

    $Result.OverallStatus = if ($Result.Errors.Count -eq 0) { "Success" } else { "Completed with Errors" }
}
catch {
    $Result.OverallStatus = "Failed"
    $Result.Errors += $_.Exception.Message
    Write-Error "An error occurred during MECM client action execution: $($_.Exception.Message)"
}

if ($ExportPath) {
    $Result | Export-Csv -Path $ExportPath -NoTypeInformation -Force
}
else {
    $Result | Format-List
}
