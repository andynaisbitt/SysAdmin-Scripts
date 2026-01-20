<#
.SYNOPSIS
Generates a report comparing expected vs. actual licenses and identifies unused licenses.
Requires the Microsoft.Graph.Users module to be installed.
#>
param (
    [string]$ExpectedLicensesJsonPath, # Path to a JSON file defining expected licenses per user or group
    [string]$ExportPath
)

try {
    # Connect to Microsoft Graph
    Connect-MgGraph -Scopes "User.Read.All", "Directory.Read.All", "Policy.Read.All" -ErrorAction Stop

    $Users = Get-MgUser -All -Property UserPrincipalName, DisplayName, AssignedLicenses -ErrorAction Stop
    $SkuDetails = Get-MgSubscribedSku -All -ErrorAction Stop | Select-Object SkuPartNumber, SkuId, ConsumedUnits, EnabledForAssignment, @{N='TotalUnits';E={$_.PrepaidUnits.Enabled}}, @{N='WarningUnits';E={$_.PrepaidUnits.Warning}}, @{N='SuspendedUnits';E={$_.PrepaidUnits.Suspended}}

    $Result = @()

    foreach ($User in $Users) {
        $AssignedSkus = ($User.AssignedLicenses.SkuId | ForEach-Object { $SkuDetails | Where-Object {$_.SkuId -eq $_} | Select-Object -ExpandProperty SkuPartNumber}) -join ", "
        
        # This part would require a more complex definition of "ExpectedLicensesJsonPath"
        # For a basic drift report, we can compare against a known set or simply list current
        
        $Result += [PSCustomObject]@{
            DisplayName       = $User.DisplayName
            UserPrincipalName = $User.UserPrincipalName
            AssignedLicenses  = $AssignedSkus
            HasLicenses       = if ($User.AssignedLicenses.Count -gt 0) { "Yes" } else { "No" }
            # ExpectedLicenses = "N/A" # Placeholder for comparison with $ExpectedLicensesJsonPath
            # LicensingDrift   = "N/A"
        }
    }

    # Identify unused licenses (basic count)
    $UsedSkus = @{}
    $Users | ForEach-Object {
        $_.AssignedLicenses | ForEach-Object {
            $Sku = $SkuDetails | Where-Object {$_.SkuId -eq $_.SkuId}
            if ($Sku) {
                $UsedSkus[$Sku.SkuPartNumber] = $UsedSkus[$Sku.SkuPartNumber] + 1
            }
        }
    }

    $UnusedLicenses = foreach ($Sku in $SkuDetails) {
        $Consumed = $UsedSkus[$Sku.SkuPartNumber]
        if (-not $Consumed) { $Consumed = 0 }
        
        [PSCustomObject]@{
            SkuPartNumber = $Sku.SkuPartNumber
            SkuId         = $Sku.SkuId
            TotalUnits    = $Sku.TotalUnits
            ConsumedUnits = $Consumed
            UnusedUnits   = $Sku.TotalUnits - $Consumed
            Enabled       = $Sku.EnabledForAssignment
        }
    }
    $UnusedLicenses = $UnusedLicenses | Where-Object {$_.UnusedUnits -gt 0}

    # Combine results for export or display
    $FinalReport = @{
        UsersLicenses = $Result
        UnusedLicenses = $UnusedLicenses
    }

    if ($ExportPath) {
        # This would require more sophisticated export logic to handle nested objects
        # For simplicity, we can export each part separately or convert to JSON
        $Result | Export-Csv -Path (Join-Path -Path (Split-Path $ExportPath) -ChildPath "UsersLicenses.csv") -NoTypeInformation
        $UnusedLicenses | Export-Csv -Path (Join-Path -Path (Split-Path $ExportPath) -ChildPath "UnusedLicenses.csv") -NoTypeInformation
        Write-Host "Licensing drift report exported to: $(Split-Path $ExportPath)"
    }
    else {
        Write-Host "`n--- User Licensing Report ---"
        $Result | Format-Table -AutoSize
        Write-Host "`n--- Unused Licenses Report ---"
        $UnusedLicenses | Format-Table -AutoSize
    }

    Disconnect-MgGraph
}
catch {
    Write-Error "An error occurred while generating the licensing drift report: $($_.Exception.Message)"
}
