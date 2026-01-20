<#
.SYNOPSIS
Triggers an Intune device sync remotely (where possible) and provides guidance for local client-side actions.
#>
param (
    [string]$DeviceId, # Intune Device ID or Entra ID Device ID
    [string]$ComputerName = "localhost" # For local client-side actions guidance
)

try {
    Write-Host "--- Attempting to Trigger Intune Sync ---"
    
    # 1. Trigger Remote Sync via Microsoft Graph (for Managed Devices)
    if ($DeviceId) {
        Write-Host "Attempting to trigger remote Intune sync for Device ID: $DeviceId..."
        # Connect to Microsoft Graph (requires DeviceManagementManagedDevices.ReadWrite.All or Device.ReadWrite.All)
        Connect-MgGraph -Scopes "DeviceManagementManagedDevices.ReadWrite.All", "Device.ReadWrite.All" -ErrorAction Stop
        
        try {
            # Find the managed device by ID
            $ManagedDevice = Get-MgDeviceManagementManagedDevice -ManagedDeviceId $DeviceId -ErrorAction Stop
            
            # Trigger sync action
            Invoke-MgDeviceManagementManagedDeviceSyncDevice -ManagedDeviceId $ManagedDevice.Id -ErrorAction Stop
            Write-Host "Remote Intune sync triggered successfully for device '$($ManagedDevice.DeviceName)'."
        }
        catch {
            Write-Warning "Failed to trigger remote Intune sync for Device ID '$DeviceId'. Error: $($_.Exception.Message)"
            Write-Host "This might be due to permissions, device not found, or device not fully managed."
        }
        Disconnect-MgGraph
    }
    else {
        Write-Warning "No DeviceId provided. Remote Intune sync cannot be triggered."
    }

    # 2. Provide Local Client-Side Guidance/Script
    Write-Host "`n--- Local Client-Side Guidance for $ComputerName ---"
    Write-Host "For a more immediate sync, consider executing these actions directly on the client:"
    
    # Restart Microsoft Intune Management Extension (IME) Service
    Write-Host "1. Restart Microsoft Intune Management Extension (IME) Service:"
    Write-Host "   On $ComputerName, open an elevated PowerShell prompt and run:"
    Write-Host "   Get-Service -Name Microsoft.Intune.ManagementExtension -ErrorAction SilentlyContinue | Restart-Service -Force"
    
    # Trigger local sync from settings
    Write-Host "`n2. Manually trigger sync from Settings:"
    Write-Host "   On $ComputerName, go to Settings -> Accounts -> Access work or school -> Select account -> Info -> Sync"

    # Trigger via scheduled task (workaround for some scenarios)
    Write-Host "`n3. Trigger sync via scheduled tasks (if existing):"
    Write-Host "   On $ComputerName, open Task Scheduler and look for tasks under 'Microsoft\Windows\EnterpriseMgmt'"
    Write-Host "   You can try to run tasks like 'Microsoft\Windows\EnterpriseMgmt\<GUID>\Push' or 'Microsoft\Windows\EnterpriseMgmt\<GUID>\Discovery'"

}
catch {
    Write-Error "An error occurred during Intune sync trigger: $($_.Exception.Message)"
}
