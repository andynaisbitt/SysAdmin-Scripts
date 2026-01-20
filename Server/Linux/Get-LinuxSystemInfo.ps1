<#
.SYNOPSIS
Gets basic system information from a Linux server using PowerShell Remoting over SSH.
#>
param (
    [string]$ComputerName,
    [string]$UserName
)

if (-not $ComputerName) {
    $ComputerName = Read-Host "Enter the Linux server name"
}
if (-not $UserName) {
    $UserName = Read-Host "Enter the user name"
}

$SshConnection = "$UserName@$ComputerName"

try {
    $Result = Invoke-Command -HostName $SshConnection -ScriptBlock {
        $OS = Get-Content -Path /etc/os-release | Where-Object { $_ -like "PRETTY_NAME=*" } | ForEach-Object { $_.Split('=')[1].Trim('"') }
        $Uptime = (Get-Uptime).ToString()
        $Memory = Get-Content -Path /proc/meminfo | Where-Object { $_ -like "MemTotal*" } | ForEach-Object { $_.Split(':')[1].Trim() }

        [PSCustomObject]@{
            OS      = $OS
            Uptime  = $Uptime
            Memory  = $Memory
        }
    }
    $Result
}
catch {
    Write-Error "Failed to get system information from '$ComputerName'. Please ensure that PowerShell Remoting over SSH is configured and that the user has the necessary permissions."
}
