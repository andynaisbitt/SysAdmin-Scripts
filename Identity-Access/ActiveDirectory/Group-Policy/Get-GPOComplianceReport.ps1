<#
.SYNOPSIS
Generates a report on key Group Policy Object (GPO) settings for audit purposes.
#>
param (
    [string]$Domain,
    [string]$ExportPath
)

if (-not $Domain) {
    $Domain = (Get-ADDomain).DNSRoot
    Write-Host "Using current domain: $Domain"
}

try {
    # Get all GPOs in the domain
    $GPOs = Get-GPO -Domain $Domain -All -ErrorAction Stop

    $Result = @()
    foreach ($GPO in $GPOs) {
        Write-Verbose "Analyzing GPO: $($GPO.DisplayName)"

        # Get GPO Report XML
        $GpoReportXml = (Get-GPOReport -Guid $GPO.Id -ReportType Xml).Report
        [xml]$Xml = $GpoReportXml # Convert string to XML object

        # Example: Audit Policy settings (just a few for demonstration)
        $AuditSettings = $Xml.GPO.Computer.ExtensionData.Extension | Where-Object { $_.Name -eq "Security" }
        $AccountLogonEvents = $AuditSettings.AuditSettings.AuditCategory | Where-Object { $_.Name -eq "Account Logon Events" }
        $AccountManagement = $AuditSettings.AuditSettings.AuditCategory | Where-Object { $_.Name -eq "Account Management" }

        # Example: Password Policy settings
        $PasswordPolicy = $Xml.GPO.Computer.ExtensionData.Extension | Where-Object { $_.Name -eq "Password Policy" }
        $MinPasswordLength = ($PasswordPolicy.PolicySetting | Where-Object { $_.Name -eq "Minimum password length" }).Value
        $PasswordHistory = ($PasswordPolicy.PolicySetting | Where-Object { $_.Name -eq "Enforce password history" }).Value

        $Result += [PSCustomObject]@{
            GPOName             = $GPO.DisplayName
            GPOEnabled          = $GPO.Enabled
            MinPasswordLength   = $MinPasswordLength
            PasswordHistory     = $PasswordHistory
            AuditAccountLogon   = ($AccountLogonEvents.AuditSetting | Select-Object -ExpandProperty SettingValue) -join ", "
            AuditAccountManage  = ($AccountManagement.AuditSetting | Select-Object -ExpandProperty SettingValue) -join ", "
            # Add more settings as needed
        }
    }

    if ($Result) {
        Write-Host "GPO compliance report generated."
        $Result | Format-Table -AutoSize
    }
    else {
        Write-Host "No GPOs found or an error occurred during retrieval."
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
}
catch {
    Write-Error "An error occurred: $($_.Exception.Message)"
}
