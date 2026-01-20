<#
.SYNOPSIS
Retrieves processes from remote computers, allowing filtering by name and including command line and owner information.
#>
param (
    [string[]]$ComputerName,
    [string]$ProcessName, # Filter by process name (supports wildcards)
    [string]$ExportPath
)

if (-not $ComputerName) {
    $ComputerName = $env:COMPUTERNAME
}

$Result = foreach ($Computer in $ComputerName) {
    Write-Verbose "Getting processes from $Computer..."
    try {
        Invoke-Command -ComputerName $Computer -ScriptBlock {
            $Processes = Get-CimInstance -ClassName Win32_Process -ErrorAction Stop
            if ($using:ProcessName) {
                $Processes = $Processes | Where-Object { $_.Name -like "$($using:ProcessName)" }
            }

            foreach ($Process in $Processes) {
                $Owner = ($Process.GetOwner()).User
                [PSCustomObject]@{
                    ComputerName = $using:Computer
                    ProcessName  = $Process.Name
                    PID          = $Process.ProcessId
                    Owner        = $Owner
                    CommandLine  = $Process.CommandLine
                    CreationDate = $Process.CreationDate
                }
            }
        } -ErrorAction Stop
    }
    catch {
        Write-Warning "Failed to get processes from '$Computer'. Error: $($_.Exception.Message)"
        [PSCustomObject]@{
            ComputerName = $Computer
            ProcessName  = "Error"
            PID          = "Error"
            Owner        = "Error"
            CommandLine  = "Error"
            CreationDate = "Error"
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
