<#
.SYNOPSIS
Performs a health check on a list of servers and generates an HTML report.
#>
param (
    [string]$ServerListFile = ".\servers.txt",
    [string]$OutputFile = ".\HealthCheck.htm"
)

$Result = @()
$ServerList = Get-Content -Path $ServerListFile -ErrorAction SilentlyContinue

foreach ($computername in $ServerList) {
    try {
        $AVGProc = Get-CimInstance -ComputerName $computername -ClassName Win32_Processor |
            Measure-Object -Property LoadPercentage -Average | Select-Object -ExpandProperty Average
        $OS = Get-CimInstance -ClassName Win32_OperatingSystem -ComputerName $computername
        $MemoryUsage = (1 - ($OS.FreePhysicalMemory / $OS.TotalVisibleMemorySize)) * 100
        $vol = Get-CimInstance -ClassName Win32_Volume -ComputerName $computername -Filter "DriveLetter = 'C:'"
        $CPercentFree = ($vol.FreeSpace / $vol.Capacity) * 100

        $Result += [PSCustomObject]@{
            ServerName = $computername
            CPULoad    = [math]::Round($AVGProc, 2)
            MemLoad    = [math]::Round($MemoryUsage, 2)
            CDrive     = [math]::Round($CPercentFree, 2)
        }
    }
    catch {
        Write-Warning "Failed to get health check information from '$computername'."
        $Result += [PSCustomObject]@{
            ServerName = $computername
            CPULoad    = "N/A"
            MemLoad    = "N/A"
            CDrive     = "N/A"
        }
    }
}

$Header = @"
<style>
    body {
        font-family: Arial, sans-serif;
    }
    table {
        border-collapse: collapse;
        width: 100%;
    }
    th, td {
        border: 1px solid #dddddd;
        text-align: left;
        padding: 8px;
    }
    th {
        background-color: #f2f2f2;
    }
    .high-utilization {
        background-color: #ffcccc;
    }
</style>
"@

$Body = $Result | ConvertTo-Html -Property ServerName, CPULoad, MemLoad, CDrive -Head $Header | ForEach-Object {
    if ($_ -match '<td>(\d+\.\d+)</td>' -and [double]$matches[1] -ge 80) {
        $_ -replace '<tr>', '<tr class="high-utilization">'
    }
    else {
        $_
    }
}

$Body | Out-File -FilePath $OutputFile

Invoke-Expression $OutputFile
