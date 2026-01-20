<#
.SYNOPSIS
Collects installed software inventory (applications, versions, install dates) from remote computers.
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
    Write-Verbose "Collecting software inventory from $Computer..."
    try {
        Invoke-Command -ComputerName $Computer -ScriptBlock {
            Get-ItemProperty HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*, HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\* |
                Where-Object { $_.DisplayName -and $_.InstallDate } |
                Select-Object DisplayName, DisplayVersion, Publisher, InstallDate, UninstallString |
                ForEach-Object {
                    [PSCustomObject]@{
                        ComputerName  = $using:Computer
                        DisplayName   = $_.DisplayName
                        DisplayVersion = $_.DisplayVersion
                        Publisher     = $_.Publisher
                        InstallDate   = $_.InstallDate
                        UninstallString = $_.UninstallString
                    }
                }
        } -ErrorAction Stop
    }
    catch {
        Write-Warning "Failed to collect software inventory from '$Computer'. Error: $($_.Exception.Message)"
        [PSCustomObject]@{
            ComputerName = $Computer
            DisplayName  = "Error"
            DisplayVersion = "N/A"
            Publisher    = "N/A"
            InstallDate  = "N/A"
            UninstallString = "N/A"
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
