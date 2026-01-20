<#
.SYNOPSIS
Detects file shares with overly permissive access (e.g., Everyone/Authenticated Users with Modify/FullControl).
#>
param (
    [string[]]$ComputerName,
    [string]$ExportPath
)

if (-not $ComputerName) {
    $ComputerName = $env:COMPUTERNAME
}

$Result = @()
foreach ($Computer in $ComputerName) {
    Write-Verbose "Checking shares on $Computer for over-permissive access..."
    try {
        $Shares = Get-SmbShare -ComputerName $Computer -ErrorAction Stop

        foreach ($Share in $Shares) {
            $SharePermissions = Get-SmbShareAccess -ComputerName $Computer -Name $Share.Name -ErrorAction SilentlyContinue

            $OverPermissiveUsers = @("Everyone", "Authenticated Users")
            $OverPermissiveRights = @("Change", "Full") # Corresponds to Modify and Full Control

            foreach ($Permission in $SharePermissions) {
                if (($OverPermissiveUsers -contains $Permission.AccountName) -and ($OverPermissiveRights -contains $Permission.AccessRight)) {
                    $Result += [PSCustomObject]@{
                        ComputerName = $Computer
                        ShareName    = $Share.Name
                        Path         = $Share.Path
                        AccountName  = $Permission.AccountName
                        AccessRight  = $Permission.AccessRight
                        OverPermissive = $true
                    }
                }
            }
        }
    }
    catch {
        Write-Warning "Failed to check shares on '$Computer'. Error: $($_.Exception.Message)"
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
