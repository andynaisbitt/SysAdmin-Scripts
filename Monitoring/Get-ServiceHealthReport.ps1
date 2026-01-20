<#
.SYNOPSIS
Checks the status of critical services per server role on one or more computers.
#>
param (
    [string[]]$ComputerName,
    [Hashtable]$ServiceRoleMap, # e.g., @{"DC" = "Netlogon", "KDC"; "SQL" = "MSSQLSERVER", "SQLBrowser"}
    [string]$ExportPath
)

if (-not $ComputerName) {
    $ComputerName = $env:COMPUTERNAME
}

if (-not $ServiceRoleMap) {
    # Default common critical services (can be expanded/customized by user)
    $ServiceRoleMap = @{
        "Domain Controller" = "Netlogon", "KDC", "DNS"
        "SQL Server"        = "MSSQLSERVER", "SQLBrowser"
        "Web Server"        = "W3SVC", "WAS"
        "File Server"       = "LanmanServer"
        "Workstation"       = "Spooler", "BITS", "wuauserv"
    }
}

$Result = foreach ($Computer in $ComputerName) {
    Write-Verbose "Checking service health on $Computer..."
    try {
        $Services = Get-Service -ComputerName $Computer -ErrorAction Stop

        # Determine potential role based on running services (simplified heuristic)
        $DetectedRoles = @()
        foreach ($Role in $ServiceRoleMap.Keys) {
            $CriticalServices = $ServiceRoleMap[$Role]
            $MatchCount = ($Services | Where-Object { $CriticalServices -contains $_.Name -and $_.Status -eq "Running" }).Count
            if ($MatchCount -gt 0) {
                $DetectedRoles += $Role
            }
        }
        if ($DetectedRoles.Count -eq 0) {
            $DetectedRoles += "Generic"
        }

        foreach ($Role in $DetectedRoles) {
            foreach ($ServiceName in $ServiceRoleMap[$Role]) {
                $Service = $Services | Where-Object { $_.Name -eq $ServiceName }
                if ($Service) {
                    [PSCustomObject]@{
                        ComputerName = $Computer
                        Role         = $Role
                        ServiceName  = $Service.Name
                        DisplayName  = $Service.DisplayName
                        Status       = $Service.Status
                        ExpectedStatus = "Running" # Assumed expected status
                        StatusMatch  = if ($Service.Status -eq "Running") { "OK" } else { "Warning" }
                    }
                }
                else {
                    [PSCustomObject]@{
                        ComputerName = $Computer
                        Role         = $Role
                        ServiceName  = $ServiceName
                        DisplayName  = "N/A"
                        Status       = "Not Found"
                        ExpectedStatus = "Running"
                        StatusMatch  = "Critical"
                    }
                }
            }
        }
    }
    catch {
        Write-Warning "Failed to check service health on '$Computer'. Error: $($_.Exception.Message)"
        [PSCustomObject]@{
            ComputerName = $Computer
            Role         = "N/A"
            ServiceName  = "N/A"
            DisplayName  = "N/A"
            Status       = "Error"
            ExpectedStatus = "N/A"
            StatusMatch  = "Critical"
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
