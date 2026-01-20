<#
.SYNOPSIS
Lists non-compliant devices in Intune, including compliance reasons, and exports a CSV and summary.
#>
param (
    [string]$ExportPath
)

try {
    # Connect to Microsoft Graph (requires DeviceManagementManagedDevices.Read.All or similar scope)
    Connect-MgGraph -Scopes "DeviceManagementManagedDevices.Read.All", "Device.Read.All" -ErrorAction Stop

    Write-Host "Retrieving non-compliant Intune devices..."
    # Get all managed devices that are not compliant
    $NonCompliantDevices = Get-MgDeviceManagementManagedDevice -All `
        -Filter "complianceState eq 'noncompliant'" `
        -Property DeviceName, ComplianceGracePeriodExpirationDateTime, ComplianceState, `
        DeviceEnrollmentType, DeviceActionResults, `
        @{N='DeviceCategory';E={$_.AdditionalProperties['deviceCategoryDisplayName']}}, `
        @{N='ComplianceGracePeriodExpirationDateTime';E={$_.AdditionalProperties['complianceGracePeriodExpirationDateTime']}} `
        -ErrorAction Stop

    $Result = foreach ($Device in $NonCompliantDevices) {
        # This is a simplified approach. Compliance reasons can be very detailed and require deeper Graph queries.
        # Often, compliance reasons are tied to specific policies and their settings.
        # For this script, we'll try to get basic reasons from device action results if available.
        $ComplianceReason = "Noncompliant"
        if ($Device.DeviceActionResults) {
            $DeviceAction = $Device.DeviceActionResults | Where-Object { $_.ActionState -eq "failed" } | Select-Object -ExpandProperty ActionName -First 1
            if ($DeviceAction) {
                $ComplianceReason = "Action Failed: $DeviceAction"
            }
        }
        
        [PSCustomObject]@{
            DeviceName           = $Device.DeviceName
            ComplianceState      = $Device.ComplianceState
            ComplianceReason     = $ComplianceReason
            OS                   = $Device.OperatingSystem
            OSVersion            = $Device.OperatingSystemVersion
            EnrollmentType       = $Device.DeviceEnrollmentType
            LastSync             = $Device.LastSyncDateTime
            ComplianceGracePeriod = if ($Device.ComplianceGracePeriodExpirationDateTime) { $Device.ComplianceGracePeriodExpirationDateTime } else { "N/A" }
        }
    }

    if ($Result) {
        Write-Host "Found $($Result.Count) non-compliant devices."
    }
    else {
        Write-Host "No non-compliant Intune devices found."
    }

    if ($ExportPath) {
        if ($ExportPath.EndsWith(".csv")) {
            $Result | Export-Csv -Path $ExportPath -NoTypeInformation
        }
        elseif ($ExportPath.EndsWith(".html")) {
            $Result | ConvertTo-Html -Title "Intune Non-Compliant Devices Report" | Out-File -Path $ExportPath
        }
        else {
            Write-Warning "Invalid export path. Please specify a .csv or .html file."
        }
    }
    else {
        $Result | Format-Table -AutoSize
    }

    Disconnect-MgGraph
}
catch {
    Write-Error "An error occurred during Intune non-compliant devices retrieval: $($_.Exception.Message)"
}
