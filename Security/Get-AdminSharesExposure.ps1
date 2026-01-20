<#
.SYNOPSIS
Audits admin shares, remote registry access, and SMB signing configurations on one or more computers.
#>
param (
    [string[]]$ComputerName,
    [string]$ExportPath
)

if (-not $ComputerName) {
    $ComputerName = $env:COMPUTERNAME
}

$Result = foreach ($Computer in $ComputerName) {
    Write-Verbose "Auditing admin shares and SMB settings on $Computer..."
    try {
        Invoke-Command -ComputerName $Computer -ScriptBlock {
            # --- Admin Shares (C$, ADMIN$, IPC$) ---
            $AdminShares = Get-SmbShare | Where-Object { $_.Name -match '\$'} | Select-Object Name, Path, Description

            # --- Remote Registry Access ---
            $RemoteRegistryService = Get-Service -Name RemoteRegistry -ErrorAction SilentlyContinue
            $RemoteRegistryStatus = if ($RemoteRegistryService) { $RemoteRegistryService.Status } else { "Not Found" }

            # --- SMB Signing Status ---
            $SmbSigningRequired = $false
            $SmbSigningRequiredPath = "HKLM:\SYSTEM\CurrentControlSet\Services\LanmanWorkstation\Parameters"
            try {
                $SmbSigningRequired = (Get-ItemProperty -Path $SmbSigningRequiredPath -Name RequireSecuritySignature -ErrorAction Stop).RequireSecuritySignature -eq 1
            }
            catch {}

            [PSCustomObject]@{
                ComputerName            = $using:Computer
                AdminShares             = ($AdminShares | ForEach-Object { "$($_.Name) ($($_.Path))" }) -join "; "
                RemoteRegistryServiceStatus = $RemoteRegistryStatus
                SmbSigningRequired      = $SmbSigningRequired
            }
        } -ErrorAction Stop
    }
    catch {
        Write-Warning "Failed to audit admin shares and SMB settings on '$Computer'. Error: $($_.Exception.Message)"
        [PSCustomObject]@{
            ComputerName            = $Computer
            AdminShares             = "Error"
            RemoteRegistryServiceStatus = "Error"
            SmbSigningRequired      = "Error"
            Error                   = $_.Exception.Message
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
