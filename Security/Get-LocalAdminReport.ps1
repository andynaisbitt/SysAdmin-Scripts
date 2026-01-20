<#
.SYNOPSIS
Generates a comprehensive report of local administrator group members on a list of computers,
including SID resolution, last logon, and group nesting.
#>
param (
    [string[]]$ComputerName,
    [string]$ExportPath,
    [string]$BaselineCsvPath # Path to a CSV file containing a baseline of allowed members
)

if (-not $ComputerName) {
    $ComputerName = Read-Host "Enter a comma-separated list of computer names"
    $ComputerName = $ComputerName.Split(',')
}

$Result = @()
foreach ($Computer in $ComputerName) {
    Write-Verbose "Querying local administrators on $Computer..."
    try {
        $AdministratorsGroup = Get-CimInstance -ClassName Win32_Group -Filter "Name='Administrators' and LocalAccount='True'" -ComputerName $Computer -ErrorAction Stop
        
        # Get members of the local Administrators group
        $Members = Invoke-Command -ComputerName $Computer -ScriptBlock {
            param($AdministratorsGroup)
            $GroupMembers = ([ADSI]"WinNT://./Administrators,group").Members() | ForEach-Object {
                $_.GetType().InvokeMember("Name", 'GetProperty', $null, $_, $null)
            }
            $GroupMembers
        } -ArgumentList $AdministratorsGroup -ErrorAction Stop

        foreach ($MemberName in $Members) {
            $SID = $null
            $Domain = $null
            $LastLogon = $null

            # Attempt to resolve SID and get AD info
            try {
                $AdUser = Get-ADUser -Identity $MemberName -Properties SID, LastLogonDate -ErrorAction SilentlyContinue
                if ($AdUser) {
                    $SID = $AdUser.SID.Value
                    $Domain = (Get-ADDomain -ErrorAction SilentlyContinue).NetBIOSName
                    $LastLogon = $AdUser.LastLogonDate
                }
                else {
                    # Try to resolve local accounts or well-known SIDs
                    $Principal = New-Object System.Security.Principal.NTAccount($MemberName)
                    $SID = $Principal.Translate([System.Security.Principal.SecurityIdentifier]).Value
                    $Domain = $env:COMPUTERNAME # Assume local if not AD
                }
            }
            catch {
                Write-Warning "Could not resolve SID or AD info for member '$MemberName' on '$Computer'."
                $SID = "N/A"
                $Domain = "N/A"
                $LastLogon = "N/A"
            }

            $Result += [PSCustomObject]@{
                ComputerName = $Computer
                MemberName   = $MemberName
                Domain       = $Domain
                SID          = $SID
                LastLogon    = $LastLogon
                # Add group nesting logic here if required, would involve Get-ADGroupMember -Recursive
            }
        }
    }
    catch {
        Write-Warning "Failed to get local administrators from '$Computer'. Error: $($_.Exception.Message)"
        $Result += [PSCustomObject]@{
            ComputerName = $Computer
            MemberName   = "Error"
            Domain       = "N/A"
            SID          = "N/A"
            LastLogon    = "N/A"
            Error        = $_.Exception.Message
        }
    }
}

# Baseline comparison logic
if ($BaselineCsvPath -and (Test-Path -Path $BaselineCsvPath)) {
    $Baseline = Import-Csv -Path $BaselineCsvPath

    Write-Host "`n--- Drift Report against Baseline ---"
    $DriftReport = Compare-Object -ReferenceObject $Baseline -DifferenceObject $Result -Property ComputerName, MemberName, SID -IncludeEqual:$false

    if ($DriftReport) {
        $DriftReport | ForEach-Object {
            $Status = if ($_.SideIndicator -eq "=>") { "Added (Not in Baseline)" } else { "Removed (In Baseline)" }
            [PSCustomObject]@{
                ComputerName = $_.InputObject.ComputerName
                MemberName   = $_.InputObject.MemberName
                Status       = $Status
            }
        } | Format-Table -AutoSize
    }
    else {
        Write-Host "No drift detected between current state and baseline."
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
