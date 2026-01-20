<#
.SYNOPSIS
Audits members of highly privileged Active Directory groups.
#>
param (
    [string]$ExportPath
)

try {
    $PrivilegedGroups = @("Domain Admins", "Enterprise Admins", "Schema Admins", "Account Operators", "Server Operators", "Print Operators", "Backup Operators")

    $Result = @()
    foreach ($Group in $PrivilegedGroups) {
        try {
            $Members = Get-ADGroupMember -Identity $Group -Recursive -ErrorAction Stop | Select-Object -ExpandProperty Name
            foreach ($Member in $Members) {
                $Result += [PSCustomObject]@{
                    GroupName = $Group
                    Member    = $Member
                }
            }
        }
        catch {
            Write-Warning "Could not retrieve members for group '$Group': $($_.Exception.Message)"
        }
    }

    if ($Result) {
        Write-Host "Audit of Privileged Groups complete."
        $Result | Format-Table -AutoSize
    }
    else {
        Write-Host "No privileged group members found or an error occurred during retrieval."
    }

    if ($ExportPath) {
        if ($ExportPath.EndsWith(".csv")) {
            $Result | Export-Csv -Path $ExportPath -NoTypeInformation
        }
        else {
            Write-Warning "Invalid export path. Please specify a .csv file."
        }
    }
}
catch {
    Write-Error "An unexpected error occurred: $($_.Exception.Message)"
}
