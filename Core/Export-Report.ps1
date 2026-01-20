<#
.SYNOPSIS
Provides a consistent way to export report data to various formats (CSV, HTML).
#>
param (
    [Parameter(Mandatory=$true, ValueFromPipeline=$true)]
    [psobject]$InputObject,
    [string]$ExportPath,
    [switch]$NoTypeInformation,
    [string]$HtmlTitle = "Report",
    [string]$HtmlBodyPreContent = "",
    [string]$HtmlBodyPostContent = ""
)

try {
    if (-not $ExportPath) {
        Write-Error "ExportPath is mandatory."
        return
    }

    $Extension = [System.IO.Path]::GetExtension($ExportPath).ToLower()

    switch ($Extension) {
        ".csv" {
            $InputObject | Export-Csv -Path $ExportPath -NoTypeInformation:$NoTypeInformation -ErrorAction Stop
            Write-Host "Report exported to CSV: $ExportPath"
        }
        ".html" {
            # Basic HTML styling
            $HtmlHead = @"
<style>
    body { font-family: Arial, sans-serif; margin: 20px; }
    h1 { color: #333; }
    table { width: 100%; border-collapse: collapse; margin-top: 20px; }
    th, td { border: 1px solid #ddd; padding: 8px; text-align: left; }
    th { background-color: #f2f2f2; }
    tr:nth-child(even) { background-color: #f9f9f9; }
</style>
"@
            $InputObject | ConvertTo-Html -Head $HtmlHead -Title $HtmlTitle -PreContent $HtmlBodyPreContent -PostContent $HtmlBodyPostContent | Out-File -FilePath $ExportPath -ErrorAction Stop
            Write-Host "Report exported to HTML: $ExportPath"
        }
        default {
            Write-Error "Unsupported export format. Please specify a .csv or .html file."
        }
    }
}
catch {
    Write-Error "Failed to export report to '$ExportPath': $($_.Exception.Message)"
}
