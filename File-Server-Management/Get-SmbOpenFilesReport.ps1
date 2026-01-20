<#
.SYNOPSIS
Generates a report of open SMB files on a list of servers.
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
    try {
        $OpenFiles = Get-SmbOpenFile -ComputerName $Computer -ErrorAction Stop
        foreach ($File in $OpenFiles) {
            [PSCustomObject]@{
                ComputerName = $Computer
                Path         = $File.Path
                UserName     = $File.ClientUserName
                Client       = $File.ClientComputerName
                Duration     = (New-TimeSpan -Start $File.OpenTime).ToString()
            }
        }
    }
    catch {
        Write-Warning "Failed to get open files from '$Computer'."
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
    $Result
}
