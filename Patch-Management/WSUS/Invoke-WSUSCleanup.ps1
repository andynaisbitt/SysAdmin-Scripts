<#
.SYNOPSIS
Automates the WSUS cleanup wizard, performing various cleanup tasks.
#>
[CmdletBinding(SupportsShouldProcess = $true)]
param (
    [string]$WsusServer = "localhost",
    [int]$Port = 8530,
    [bool]$UseSsl = $false,
    [switch]$CleanupObsoleteComputers,
    [switch]$CleanupObsoleteUpdates,
    [switch]$CleanupUnneededContentFiles,
    [switch]$CleanupExpiredUpdates,
    [switch]$CleanupDeclinedUpdates
)

try {
    # Add the required assembly
    Add-Type -Path "$env:ProgramFiles\Update Services\Api\Microsoft.UpdateServices.Administration.dll" -ErrorAction Stop

    # Connect to the WSUS server
    $Wsus = [Microsoft.UpdateServices.Administration.AdminProxy]::GetUpdateServer($WsusServer, $UseSsl, $Port)

    # Get the cleanup manager
    $CleanupManager = $Wsus.GetCleanupManager()

    # Create a list of cleanup scopes
    $CleanupScopes = @()
    if ($CleanupObsoleteComputers) { $CleanupScopes += [Microsoft.UpdateServices.Administration.WsusCleanupTarget]::ObsoleteComputers }
    if ($CleanupObsoleteUpdates) { $CleanupScopes += [Microsoft.UpdateServices.Administration.WsusCleanupTarget]::ObsoleteUpdates }
    if ($CleanupUnneededContentFiles) { $CleanupScopes += [Microsoft.UpdateServices.Administration.WsusCleanupTarget]::UnneededContentFiles }
    if ($CleanupExpiredUpdates) { $CleanupScopes += [Microsoft.UpdateServices.Administration.WsusCleanupTarget]::ExpiredUpdates }
    if ($CleanupDeclinedUpdates) { $CleanupScopes += [Microsoft.UpdateServices.Administration.WsusCleanupTarget]::DeclinedUpdates }

    if ($CleanupScopes.Count -eq 0) {
        Write-Warning "No cleanup options selected. Exiting."
        return
    }

    $CombinedScope = [Microsoft.UpdateServices.Administration.WsusCleanupTarget]::None
    foreach ($Scope in $CleanupScopes) {
        $CombinedScope = $CombinedScope -bor $Scope
    }

    Write-Host "Starting WSUS cleanup on '$WsusServer' with scope: $CombinedScope"

    if ($pscmdlet.ShouldProcess("Perform WSUS cleanup on '$WsusServer'", "Cleanup WSUS")) {
        $CleanupResults = $CleanupManager.PerformCleanup($CombinedScope)

        Write-Host "WSUS Cleanup Results:"
        Write-Host "  Obsolete Computers Deleted: $($CleanupResults.DeletionsFromObsoleteComputersCount)"
        Write-Host "  Obsolete Updates Deleted: $($CleanupResults.DeletionsFromObsoleteUpdatesCount)"
        Write-Host "  Unneeded Content Files Deleted: $($CleanupResults.DeletionsFromUnneededContentFilesCount)"
        Write-Host "  Expired Updates Deleted: $($CleanupResults.DeletionsFromExpiredUpdatesCount)"
        Write-Host "  Declined Updates Deleted: $($CleanupResults.DeletionsFromDeclinedUpdatesCount)"
    }
}
catch {
    Write-Error "An error occurred during WSUS cleanup: $($_.Exception.Message)"
}
