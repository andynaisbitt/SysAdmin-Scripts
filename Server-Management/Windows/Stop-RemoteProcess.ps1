<#
.SYNOPSIS
Safely stops a remote process by PID or name, with confirmation and logging.
#>
[CmdletBinding(SupportsShouldProcess = $true)]
param (
    [string]$ComputerName,
    [int]$PID,
    [string]$ProcessName
)

if (-not $ComputerName) {
    $ComputerName = Read-Host "Enter the computer name"
}

if (-not $PID -and -not $ProcessName) {
    Write-Error "Please specify either a PID or a ProcessName to stop."
    return
}

try {
    Write-Verbose "Attempting to stop process on $ComputerName..."
    Invoke-Command -ComputerName $ComputerName -ScriptBlock {
        param ($PID, $ProcessName)

        $TargetProcesses = $null
        if ($PID) {
            $TargetProcesses = Get-Process -Id $PID -ErrorAction SilentlyContinue
        }
        elseif ($ProcessName) {
            $TargetProcesses = Get-Process -Name $ProcessName -ErrorAction SilentlyContinue
        }

        if ($TargetProcesses) {
            foreach ($Process in $TargetProcesses) {
                if ($pscmdlet.ShouldProcess("Stop process '$($Process.ProcessName)' (PID: $($Process.Id)) on '$using:ComputerName'", "Stop Process")) {
                    Stop-Process -Id $Process.Id -Force -ErrorAction Stop
                    Write-Host "Process '$($Process.ProcessName)' (PID: $($Process.Id)) stopped on '$using:ComputerName'."
                }
            }
        }
        else {
            Write-Warning "No process found matching PID '$PID' or Name '$ProcessName' on '$using:ComputerName'."
        }
    } -ArgumentList $PID, $ProcessName -WhatIf:$pscmdlet.WhatIf -Confirm:$pscmdlet.Confirm -ErrorAction Stop
}
catch {
    Write-Error "An error occurred while stopping the remote process on '$ComputerName': $($_.Exception.Message)"
}
