<#
.SYNOPSIS
Compares local administrator group members on computers against a baseline allowlist and reports any discrepancies.
#>
param (
    [string[]]$ComputerName,
    [string[]]$BaselineMembers, # Array of usernames/SIDs that ARE allowed to be local admins
    [string]$ExportPath
)

if (-not $ComputerName) {
    $ComputerName = Read-Host "Enter a comma-separated list of computer names"
    $ComputerName = $ComputerName.Split(',')
}
if (-not $BaselineMembers) {
    $BaselineMembers = Read-Host "Enter a comma-separated list of baseline local administrator members (e.g., Administrator,Domain Admins)"
    $BaselineMembers = $BaselineMembers.Split(',')
}

$Result = foreach ($Computer in $ComputerName) {
    Write-Verbose "Checking local administrators on $Computer..."
    try {
        $LocalAdmins = Invoke-Command -ComputerName $Computer -ScriptBlock {
            ([ADSI]"WinNT://$env:COMPUTERNAME/Administrators,group").Members() | ForEach-Object {
                $_.GetType().InvokeMember("Name", 'GetProperty', $null, $_, $null)
            }
        } -ErrorAction Stop

        $Discrepancies = Compare-Object -ReferenceObject $BaselineMembers -DifferenceObject $LocalAdmins -IncludeEqual:$false

        foreach ($Discrepancy in $Discrepancies) {
            [PSCustomObject]@{
                ComputerName = $Computer
                Member       = $Discrepancy.InputObject
                Status       = if ($Discrepancy.SideIndicator -eq "=>") { "Added (Not in Baseline)" } else { "Removed (In Baseline)" }
            }
        }
    }
    catch {
        Write-Warning "Failed to check local administrators on '$Computer'. Error: $($_.Exception.Message)"
        [PSCustomObject]@{
            ComputerName = $Computer
            Member       = "Error"
            Status       = $_.Exception.Message
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
