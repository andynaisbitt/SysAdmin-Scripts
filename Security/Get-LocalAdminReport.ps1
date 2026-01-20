<#
.SYNOPSIS
Generates a report of the members of the local administrators group on a list of computers.
#>
param (
    [string[]]$ComputerName,
    [string]$FilePath
)

if ($FilePath) {
    $ComputerName = Get-Content -Path $FilePath
}

if (-not $ComputerName) {
    $ComputerName = Read-Host "Enter a comma-separated list of computer names"
    $ComputerName = $ComputerName.Split(',')
}

$Result = foreach ($Computer in $ComputerName) {
    try {
        $Group = Get-CimInstance -ClassName Win32_Group -Filter "Name='Administrators' and LocalAccount='True'" -ComputerName $Computer
        $Members = Get-CimAssociatedInstance -InputObject $Group -ResultClassName Win32_UserAccount
        foreach ($Member in $Members) {
            [PSCustomObject]@{
                ComputerName = $Computer
                MemberName   = $Member.Name
                Domain       = $Member.Domain
                SID          = $Member.SID
            }
        }
    }
    catch {
        Write-Warning "Failed to get local administrators from '$Computer'."
        [PSCustomObject]@{
            ComputerName = $Computer
            MemberName   = "N/A"
            Domain       = "N/A"
            SID          = "N/A"
        }
    }
}

$Result
