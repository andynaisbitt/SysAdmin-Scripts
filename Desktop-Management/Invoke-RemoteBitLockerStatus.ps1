<#
.SYNOPSIS
Reports on the BitLocker status of drives on one or more remote computers.
#>
param (
    [string[]]$ComputerName,
    [string]$ExportPath
)

if (-not $ComputerName) {
    $ComputerName = Read-Host "Enter a comma-separated list of computer names"
    $ComputerName = $ComputerName.Split(',')
}

$Result = foreach ($Computer in $ComputerName) {
    Write-Verbose "Checking BitLocker status on $Computer..."
    try {
        Invoke-Command -ComputerName $Computer -ScriptBlock {
            Get-BitLockerVolume | ForEach-Object {
                [PSCustomObject]@{
                    ComputerName       = $using:Computer
                    MountPoint         = $_.MountPoint
                    VolumeStatus       = $_.VolumeStatus
                    ProtectionStatus   = $_.ProtectionStatus
                    EncryptionMethod   = $_.EncryptionMethod
                    LockStatus         = $_.LockStatus
                    KeyProtector       = ($_.KeyProtector | Select-Object -ExpandProperty KeyProtectorType) -join ", "
                    AutoUnlockEnabled  = $_.AutoUnlockEnabled
                }
            }
        } -ErrorAction Stop
    }
    catch {
        Write-Warning "Failed to get BitLocker status from '$Computer'. Error: $($_.Exception.Message)"
        [PSCustomObject]@{
            ComputerName      = $Computer
            MountPoint        = "N/A"
            VolumeStatus      = "Error"
            ProtectionStatus  = "N/A"
            EncryptionMethod  = "N/A"
            LockStatus        = "N/A"
            KeyProtector      = "N/A"
            AutoUnlockEnabled = "N/A"
            Error             = $_.Exception.Message
        }
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
