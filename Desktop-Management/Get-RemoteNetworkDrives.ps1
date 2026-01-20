<#
.SYNOPSIS
Gets the remote network drives of a user on a specific computer.
#>
param (
    [string]$ComputerName,
    [string]$UserName
)

if (-not $ComputerName) {
    $ComputerName = Read-Host "Enter the computer name"
}

if (-not $UserName) {
    try {
        $UserName = (Get-WmiObject -Class Win32_ComputerSystem -ComputerName $ComputerName).UserName.Split('\')[-1]
    }
    catch {
        Write-Error "Failed to get the logged on user from '$ComputerName'. Please ensure the computer name is correct and you have the necessary permissions."
    }
}

try {
    $sid = (Get-ADUser -Identity $UserName).SID.Value
    Invoke-Command -ComputerName $ComputerName -ScriptBlock {
        param($sid)
        $Drives = Get-ChildItem -Path "Registry::HKEY_USERS\$sid\Network" -Recurse
        foreach ($Drive in $Drives) {
            Get-ItemProperty -Path $Drive.PSPath
        }
    } -ArgumentList $sid
}
catch {
    Write-Error "Failed to get remote network drives for user '$UserName' on computer '$ComputerName'. Please ensure the user and computer names are correct and you have the necessary permissions."
}
