<#
.SYNOPSIS
Queries an Active Directory OU for computers and generates a combined pending reboot report in CSV and HTML formats.
#>
param (
    [string]$AdOuPath,           # Distinguished Name of an AD OU to query for computers
    [string]$ExportBasePath      # Base path to save the combined CSV and HTML reports
)

if (-not $AdOuPath) {
    $AdOuPath = Read-Host "Enter the full distinguished name of the AD OU to scan for computers"
}
if (-not $ExportBasePath) {
    $ExportBasePath = Read-Host "Enter the base path to save the combined reports (e.g., C:\Reports\PendingReboot)"
}

if (-not (Test-Path -Path $ExportBasePath)) {
    New-Item -Path $ExportBasePath -ItemType Directory -Force | Out-Null
}

try {
    Write-Host "Retrieving computers from AD OU '$AdOuPath'..."
    $Computers = Get-ADComputer -Filter * -SearchBase $AdOuPath -ErrorAction Stop | Select-Object -ExpandProperty Name

    if (-not $Computers) {
        Write-Warning "No computers found in the specified OU: $AdOuPath. Exiting."
        return
    }

    Write-Host "Found $($Computers.Count) computers. Running pending reboot report..."
    
    # Path to the core Get-PendingRebootReport.ps1 script
    $PendingRebootScriptPath = Join-Path -Path $PSScriptRoot -ChildPath "Get-PendingRebootReport.ps1"

    if (-not (Test-Path -Path $PendingRebootScriptPath)) {
        Write-Error "The core Get-PendingRebootReport.ps1 script was not found at '$PendingRebootScriptPath'."
        return
    }

    # Execute the pending reboot report script with the list of computers
    $CombinedResults = & $PendingRebootScriptPath -ComputerName $Computers -ErrorAction Stop

    $Timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $CsvExportPath = Join-Path -Path $ExportBasePath -ChildPath "PendingReboot_Estate_Report_$Timestamp.csv"
    $HtmlExportPath = Join-Path -Path $ExportBasePath -ChildPath "PendingReboot_Estate_Report_$Timestamp.html"

    if ($CombinedResults) {
        $CombinedResults | Export-Csv -Path $CsvExportPath -NoTypeInformation -Force
        Write-Host "Combined pending reboot report exported to CSV: $CsvExportPath"
        
        $CombinedResults | ConvertTo-Html -Title "Pending Reboot Estate Report" -As Table | Out-File -FilePath $HtmlExportPath -Force
        Write-Host "Combined pending reboot report exported to HTML: $HtmlExportPath"
    }
    else {
        Write-Host "No pending reboots detected across the estate."
    }
}
catch {
    Write-Error "An error occurred during pending reboot estate report generation: $($_.Exception.Message)"
}
