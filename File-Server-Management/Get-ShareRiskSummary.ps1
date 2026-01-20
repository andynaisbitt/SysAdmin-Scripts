<#
.SYNOPSIS
Generates a summary report of file share risks by combining results from over-permissive share detection and permissions auditing.
#>
param (
    [string[]]$ComputerName,
    [string]$ExportPath
)

if (-not $ComputerName) {
    $ComputerName = Read-Host "Enter a comma-separated list of computer names"
    $ComputerName = $ComputerName.Split(',')
}

$Result = @()
foreach ($Computer in $ComputerName) {
    Write-Host "--- Checking shares on $Computer ---"
    
    # Run Find-OverPermissiveShares.ps1
    $OverPermissiveShares = & (Join-Path $PSScriptRoot "Find-OverPermissiveShares.ps1") -ComputerName $Computer -ErrorAction SilentlyContinue
    
    # Run Get-SharePermissionsAudit.ps1 for all shares
    $Shares = Get-SmbShare -ComputerName $Computer -ErrorAction SilentlyContinue
    foreach ($Share in $Shares) {
        $Audit = & (Join-Path $PSScriptRoot "Get-SharePermissionsAudit.ps1") -ComputerName $Computer -ShareName $Share.Name -ErrorAction SilentlyContinue
        
        $RiskLevel = "Low"
        $RiskReason = @()

        # Check for over-permissive flags
        $IsOverPermissive = $OverPermissiveShares | Where-Object { $_.ComputerName -eq $Computer -and $_.ShareName -eq $Share.Name -and $_.OverPermissive -eq $true }
        if ($IsOverPermissive) {
            $RiskLevel = "High"
            $RiskReason += "Over-permissive share access detected (`"Everyone`" / `"Authenticated Users`" with Modify/FullControl)."
        }

        # Check for direct "Everyone" or "Authenticated Users" FullControl in NTFS (basic check)
        if ($Audit.NtfsPermissions) {
            foreach ($NtfsPerm in $Audit.NtfsPermissions) {
                if (($NtfsPerm.IdentityReference -like "*Everyone*" -or $NtfsPerm.IdentityReference -like "*Authenticated Users*") -and ($NtfsPerm.FileSystemRights -match "FullControl|Modify")) {
                    $RiskLevel = "High"
                    $RiskReason += "Over-permissive NTFS access detected (`"$($NtfsPerm.IdentityReference)`" with FullControl/Modify)."
                }
            }
        }
        
        $Result += [PSCustomObject]@{
            ComputerName = $Computer
            ShareName    = $Share.Name
            SharePath    = $Share.Path
            RiskLevel    = $RiskLevel
            RiskReason   = ($RiskReason -join "; ")
            # You can add more details from $Audit here if needed
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
