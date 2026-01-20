<#
.SYNOPSIS
Enables the .NET Framework 3.5 feature on Windows.
#>
param (
    [string]$SourcePath
)

if ($SourcePath) {
    try {
        DISM /Online /Enable-Feature /FeatureName:NetFx3 /All /LimitAccess /Source:$SourcePath
    }
    catch {
        Write-Error "Failed to enable .NET Framework 3.5. Please ensure the source path is correct and you have administrative privileges."
    }
}
else {
    try {
        DISM /Online /Enable-Feature /FeatureName:NetFx3 /All
    }
    catch {
        Write-Error "Failed to enable .NET Framework 3.5. Please ensure you have administrative privileges."
    }
}
