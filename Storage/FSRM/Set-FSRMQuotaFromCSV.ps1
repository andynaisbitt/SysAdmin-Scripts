<#
.SYNOPSIS
Sets FSRM quotas from a CSV file.
#>
param (
    [string]$InputCsvPath
)

if (-not $InputCsvPath) {
    $InputCsvPath = Read-Host "Enter the path to the CSV file containing quota settings (Path, LimitGB, Template, EmailNotify)"
}

try {
    $QuotaSettings = Import-Csv -Path $InputCsvPath

    foreach ($Setting in $QuotaSettings) {
        $Path = $Setting.Path
        $LimitGB = $Setting.LimitGB
        $Template = $Setting.Template
        $EmailNotify = $Setting.EmailNotify -as [bool] # Convert to boolean

        if (-not (Test-Path -Path $Path)) {
            Write-Warning "Path '$Path' does not exist. Skipping quota creation."
            continue
        }

        # Check if quota already exists for the path
        $ExistingQuota = Get-FsrmQuota -Path $Path -ErrorAction SilentlyContinue

        if ($ExistingQuota) {
            Write-Host "Quota already exists for '$Path'. Updating existing quota."
            Set-FsrmQuota -Path $Path -Size ($LimitGB * 1GB) -Template $Template -QuotaType Hard -Threshold $ExistingQuota.Threshold -UpdateRule @{Type='Percent';Value=85;MailTo=$EmailNotify} -ErrorAction Stop
        }
        else {
            Write-Host "Creating new quota for '$Path'."
            New-FsrmQuota -Path $Path -Size ($LimitGB * 1GB) -Template $Template -QuotaType Hard -Threshold @{Type='Percent';Value=85;MailTo=$EmailNotify} -ErrorAction Stop
        }
        Write-Host "Quota set for '$Path' with limit $($LimitGB)GB."
    }
}
catch {
    Write-Error "An error occurred: $($_.Exception.Message)"
}
