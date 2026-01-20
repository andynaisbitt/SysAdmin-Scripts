<#
.SYNOPSIS
Reports on SQL Server Agent jobs, listing failed jobs with details like duration, last message, and owner.
#>
param (
    [string[]]$SqlServerInstance, # e.g., "SQL01", "SQL01\SQLEXPRESS"
    [string]$ExportPath
)

if (-not $SqlServerInstance) {
    $SqlServerInstance = Read-Host "Enter a comma-separated list of SQL Server instances"
    $SqlServerInstance = $SqlServerInstance.Split(',')
}

$Result = @()
foreach ($Instance in $SqlServerInstance) {
    Write-Verbose "Checking SQL Agent jobs for $Instance..."
    try {
        if (-not (Get-Command -Name Invoke-Sqlcmd -ErrorAction SilentlyContinue)) {
            Write-Warning "Invoke-Sqlcmd is not available for $Instance. Skipping SQL Agent job check."
            $Result += [PSCustomObject]@{
                SqlServerInstance = $Instance
                JobName           = "N/A"
                LastRunStatus     = "Skipped"
                LastRunDuration   = "N/A"
                LastRunMessage    = "Invoke-Sqlcmd not found."
                Owner             = "N/A"
            }
            continue
        }

        # Query to get failed SQL Agent jobs
        $Query = @"
            SELECT
                j.name AS JobName,
                jh.run_status AS LastRunStatus,
                msdb.dbo.fn_ms_format_time(jh.run_duration) AS LastRunDuration,
                jh.message AS LastRunMessage,
                SUSER_SNAME(j.owner_sid) AS Owner
            FROM
                msdb.dbo.sysjobs j
            JOIN
                msdb.dbo.sysjobhistory jh ON j.job_id = jh.job_id
            WHERE
                jh.step_id = 0 -- Overall job status
                AND jh.run_status = 0 -- Failed
                AND jh.instance_id = (SELECT MAX(instance_id) FROM msdb.dbo.sysjobhistory WHERE job_id = j.job_id AND step_id = 0)
            ORDER BY
                j.name;
"@
        $JobInfo = Invoke-Sqlcmd -ServerInstance $Instance -Query $Query -ErrorAction Stop

        foreach ($Job in $JobInfo) {
            $Result += [PSCustomObject]@{
                SqlServerInstance = $Instance
                JobName           = $Job.JobName
                LastRunStatus     = "Failed"
                LastRunDuration   = $Job.LastRunDuration
                LastRunMessage    = $Job.LastRunMessage
                Owner             = $Job.Owner
            }
        }
    }
    catch {
        Write-Warning "Failed to check SQL Agent jobs for instance '$Instance': $($_.Exception.Message)"
        $Result += [PSCustomObject]@{
            SqlServerInstance = $Instance
            JobName           = "N/A"
            LastRunStatus     = "Error"
            LastRunDuration   = "N/A"
            LastRunMessage    = $_.Exception.Message
            Owner             = "N/A"
        }
    }
}

if ($ExportPath) {
    if ($ExportPath.EndsWith(".csv")) {
        $Result | Export-Csv -Path $ExportPath -NoTypeInformation
    }
    elseif ($ExportPath.EndsWith(".html")) {
        $Result | ConvertTo-Html -Title "SQL Agent Jobs Report" | Out-File -Path $ExportPath
    }
    else {
        Write-Warning "Invalid export path. Please specify a .csv or .html file."
    }
}
else {
    $Result | Format-Table -AutoSize
}
