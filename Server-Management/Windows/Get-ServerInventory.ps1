<#
.SYNOPSIS
Gathers server-specific inventory details including roles/features, disk space, critical services, patch status, and certificate expiry.
Leverages other scripts in the toolkit for a comprehensive view.
#>
param (
    [string[]]$ComputerName,
    [string]$ExportPath
)

if (-not $ComputerName) {
    $ComputerName = $env:COMPUTERNAME
}

$Result = foreach ($Computer in $ComputerName) {
    Write-Verbose "Collecting server inventory from $Computer..."
    try {
        # --- Basic OS Info (from Get-ComputerInventory.ps1 logic) ---
        $OsInfo = Invoke-Command -ComputerName $Computer -ScriptBlock { Get-CimInstance -ClassName Win32_OperatingSystem | Select-Object Caption, OSArchitecture } -ErrorAction SilentlyContinue

        # --- Installed Features/Roles (from Get-ServerRoleInventory.ps1 logic) ---
        $Features = Invoke-Command -ComputerName $Computer -ScriptBlock {
            $InstalledFeatures = @()
            if (Get-Command -Name Get-WindowsFeature -ErrorAction SilentlyContinue) {
                $InstalledFeatures = Get-WindowsFeature | Where-Object { $_.Installed -eq $true } | Select-Object -ExpandProperty DisplayName
            } else {
                # Fallback for client OS or older servers
                $DismFeatures = (dism.exe /online /Get-Features /format:table | Select-String -Pattern "Enabled" | ForEach-Object { ($_.ToString().Split(' ', [System.StringSplitOptions]::RemoveEmptyEntries))[0] })
                $InstalledFeatures = $DismFeatures
            }
            $InstalledFeatures
        } -ErrorAction SilentlyContinue

        # --- Disk Space (simple view) ---
        $DiskSpace = Invoke-Command -ComputerName $Computer -ScriptBlock { Get-CimInstance -ClassName Win32_LogicalDisk | Where-Object { $_.DriveType -eq 3 } | Select-Object DeviceID, @{N="FreeGB";E={[math]::Round($_.FreeSpace / 1GB, 2)}}, @{N="SizeGB";E={[math]::Round($_.Size / 1GB, 2)}} } -ErrorAction SilentlyContinue

        # --- Critical Services Status (from Get-ServiceHealthReport.ps1 logic) ---
        $CriticalServiceHealth = & (Join-Path $PSScriptRoot "Get-ServiceHealthReport.ps1") -ComputerName $Computer -ErrorAction SilentlyContinue | Where-Object { $_.StatusMatch -ne "OK" } | Select-Object ServiceName, Status, StatusMatch

        # --- Patch Status (from Get-WindowsUpdateStatus.ps1 logic) ---
        $PatchStatus = & (Join-Path $PSScriptRoot "..\..\Patch-Management\Get-WindowsUpdateStatus.ps1") -ComputerName $Computer -ErrorAction SilentlyContinue

        # --- Certificate Expiry (from Get-CertificateExpiryReport.ps1 logic) ---
        $CertExpiry = & (Join-Path $PSScriptRoot "..\..\Monitoring\Get-CertificateExpiryReport.ps1") -ComputerName $Computer -WarningDays 60 -ErrorAction SilentlyContinue | Where-Object { $_.Status -ne "OK" } | Select-Object Subject, NotAfter, Status

        [PSCustomObject]@{
            ComputerName         = $Computer
            OS                   = if ($OsInfo) { $OsInfo.Caption } else { "N/A" }
            OSArchitecture       = if ($OsInfo) { $OsInfo.OSArchitecture } else { "N/A" }
            InstalledFeatures    = ($Features -join "; ")
            DiskSpaceSummary     = ($DiskSpace | ForEach-Object { "$($_.DeviceID): $($_.FreeGB)/$($_.SizeGB)GB" }) -join "; "
            CriticalServiceIssues = ($CriticalServiceHealth | ForEach-Object { "$($_.ServiceName): $($_.StatusMatch)" }) -join "; "
            LastPatchInstall     = if ($PatchStatus) { $PatchStatus.LastInstallDate } else { "N/A" }
            PendingReboot        = if ($PatchStatus) { $PatchStatus.PendingReboot } else { "N/A" }
            ExpiringCertificates = ($CertExpiry | ForEach-Object { "$($_.Subject) expires $($_.NotAfter)" }) -join "; "
        }
    }
    catch {
        Write-Warning "Failed to collect server inventory from '$Computer'. Error: $($_.Exception.Message)"
        [PSCustomObject]@{
            ComputerName = $Computer
            Error        = $_.Exception.Message
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
