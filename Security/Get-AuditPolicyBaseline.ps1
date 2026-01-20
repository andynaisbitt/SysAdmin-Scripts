<#
.SYNOPSIS
Retrieves the current audit policy settings on a local or remote computer.
#>
param (
    [string]$ComputerName,
    [string]$ExportPath
)

if (-not $ComputerName) {
    $ComputerName = $env:COMPUTERNAME
}

try {
    Write-Host "Retrieving audit policy settings from '$ComputerName'..."
    
    # Using auditpol.exe for simplicity, as it's built-in and comprehensive for audit policy
    $AuditPolicyRaw = (Invoke-Command -ComputerName $ComputerName -ScriptBlock { auditpol /get /category:* }).Trim()
    
    $Result = @()
    $CurrentCategory = ""
    $AuditPolicyRaw -split "`r`n" | ForEach-Object {
        $Line = $_.Trim()
        if ($Line -match "^\s*Category\s+(.+)$") {
            $CurrentCategory = $matches[1]
        }
        elseif ($Line -match "^\s*(.+)\s*(\(Success\)\s*(.+)\s*\(Failure\)\s*(.+))$") {
            $Subcategory = $matches[1].Trim()
            $SuccessAudit = $matches[3].Trim()
            $FailureAudit = $matches[4].Trim()
            
            $Result += [PSCustomObject]@{
                ComputerName = $ComputerName
                Category     = $CurrentCategory
                Subcategory  = $Subcategory
                SuccessAudit = $SuccessAudit
                FailureAudit = $FailureAudit
            }
        }
    }

    if ($Result) {
        Write-Host "Audit policy settings retrieved for '$ComputerName'."
    }
    else {
        Write-Warning "No audit policy settings found or parsed for '$ComputerName'."
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
}
catch {
    Write-Error "An error occurred while retrieving audit policy settings from '$ComputerName': $($_.Exception.Message)"
}
