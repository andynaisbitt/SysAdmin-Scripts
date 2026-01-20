<#
.SYNOPSIS
Retrieves a health summary from a VMware environment using PowerCLI, including host alarms, datastore free space, and snapshot sprawl.
#>
param (
    [string]$VcenterServer, # Required: vCenter Server name/IP
    [string]$ExportPath
)

# Requires VMware PowerCLI module
# Connect-VIServer $VcenterServer -Credential (Get-Credential) must be executed before running this script.

$Result = [PSCustomObject]@{
    VcenterServer = $VcenterServer
    HostAlarms = "N/A"
    DatastoreFreeSpaceGB = "N/A"
    SnapshotSprawlVMs = "N/A"
    OverallStatus = "Failed"
    Errors = @()
}

try {
    Write-Host "--- Checking VMware Health Summary for $VcenterServer ---"

    if (-not (Get-Module -ListAvailable -Name VMware.PowerCLI)) {
        throw "VMware PowerCLI module not found. Please install PowerCLI."
    }
    
    # Check for existing connection to vCenter
    if (-not (Get-VIServer -ErrorAction SilentlyContinue | Where-Object { $_.Name -eq $VcenterServer })) {
        throw "Not connected to vCenter '$VcenterServer'. Please run Connect-VIServer $VcenterServer -Credential (Get-Credential) first."
    }

    # 1. Host Alarms
    Write-Verbose "Checking host alarms..."
    $ActiveHostAlarms = Get-Alarm | Where-Object { $_.Target -is [VMware.VimAutomation.ViCore.Impl.V1.Inventory.VMHostImpl] -and $_.Status -ne "Green" }
    $Result.HostAlarms = if ($ActiveHostAlarms) { "$($ActiveHostAlarms.Count) active host alarms" } else { "None" }

    # 2. Datastore Free Space
    Write-Verbose "Checking datastore free space..."
    $Datastores = Get-Datastore | Select-Object Name, @{N="CapacityGB";E={[math]::Round($_.CapacityGB, 2)}}, @{N="FreeSpaceGB";E={[math]::Round($_.FreeSpaceGB, 2)}}, @{N="PercentFree";E={[math]::Round(($_.FreeSpaceGB / $_.CapacityGB) * 100, 2)}}
    $Result.DatastoreFreeSpaceGB = ($Datastores | ForEach-Object { "$($_.Name): $($_.FreeSpaceGB)GB free ($($_.PercentFree)%)" }) -join "; "
    
    # 3. Snapshot Sprawl
    Write-Verbose "Checking for snapshot sprawl..."
    $VMsWithSnapshots = Get-VM | Get-Snapshot | Group-Object VM | ForEach-Object {
        $VMName = $_.Name
        $SnapshotCount = $_.Count
        $OldestSnapshotDays = (New-TimeSpan -Start ($_.Group | Sort-Object Created -First 1).Created).Days
        "$VMName ($SnapshotCount snapshots, oldest $OldestSnapshotDays days)"
    }
    $Result.SnapshotSprawlVMs = if ($VMsWithSnapshots) { ($VMsWithSnapshots -join "; ") } else { "None" }

    $Result.OverallStatus = "Success"
}
catch {
    $Result.Errors += $_.Exception.Message
    Write-Error "An error occurred during VMware health summary: $($_.Exception.Message)"
}

if ($ExportPath) {
    $Result | Export-Csv -Path $ExportPath -NoTypeInformation -Force
}
else {
    $Result | Format-List
}
