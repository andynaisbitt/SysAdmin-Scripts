<#
.SYNOPSIS
Creates a comprehensive Cyber Essentials evidence pack by running various checks and exporting results.
#>
param (
    [string[]]$ComputerName,
    [string]$AdOuPath,
    [string]$OutputBasePath = (Join-Path $PSScriptRoot "..\..\Output\Compliance\CyberEssentials"),
    [string]$OrganizationName,
    [switch]$NoAutoOpen
)

# --- Load Core Get-Targets.ps1 ---
. (Join-Path -Path $PSScriptRoot -ChildPath "..\..\Core\Get-Targets.ps1")
# --- Load Core Export-Report.ps1 ---
. (Join-Path -Path $PSScriptRoot -ChildPath "..\..\Core\Export-Report.ps1")

if (-not $OrganizationName) {
    $OrganizationName = Read-Host "Enter the Organization Name for the report"
}

$Timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$EvidenceFolder = Join-Path -Path $OutputBasePath -ChildPath "$OrganizationName-CyberEssentials-Evidence-$Timestamp"

if (-not (Test-Path -Path $OutputBasePath)) {
    New-Item -Path $OutputBasePath -ItemType Directory -Force | Out-Null
}
New-Item -Path $EvidenceFolder -ItemType Directory -Force | Out-Null
Write-Host "Cyber Essentials evidence pack will be stored in: $EvidenceFolder"

$LogFile = Join-Path -Path $EvidenceFolder -ChildPath "EvidencePackGeneration.log"
function Write-EvidenceLog ([string]$Message, [string]$Level = "INFO") {
    $Time = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    "[$Time] [$Level] $Message" | Add-Content -Path $LogFile
    Write-Host "[$Level] $Message"
}

$ReportSummary = @()

try {
    # Resolve target computers
    $TargetComputers = Get-Targets -ComputerName $ComputerName -AdOuPath $AdOuPath
    if (-not $TargetComputers) {
        Write-EvidenceLog "No target computers found for checks." "WARN"
        throw "No target computers found."
    }

    Write-EvidenceLog "Starting Cyber Essentials Evidence Pack generation for $($TargetComputers.Count) computers."

    # --- 1. Boundary Firewall (High-level check, relies on Get-FirewallPostureReport.ps1) ---
    Write-EvidenceLog "Collecting Firewall Posture Report..."
    $FirewallReportPath = Join-Path -Path $EvidenceFolder -ChildPath "FirewallPostureReport.csv"
    $FirewallReportHtmlPath = Join-Path -Path $EvidenceFolder -ChildPath "FirewallPostureReport.html"
    $FirewallScriptPath = Join-Path -Path $PSScriptRoot -ChildPath "Get-FirewallPostureReport.ps1" # This script needs to be created
    if (Test-Path -Path $FirewallScriptPath) {
        $FirewallResults = & $FirewallScriptPath -ComputerName $TargetComputers -ExportPath $FirewallReportPath -ErrorAction SilentlyContinue
        if ($FirewallResults) {
            $FirewallResults | Export-Report -ExportPath $FirewallReportHtmlPath -HtmlTitle "Firewall Posture Report"
            Write-EvidenceLog "Firewall Posture Report saved to $FirewallReportPath."
            $ReportSummary += [PSCustomObject]@{ Check = "Firewall Posture"; Status = "Completed"; Details = "See $FirewallReportPath" }
        }
        else {
             Write-EvidenceLog "Firewall Posture Report script ran, but no results returned." "WARN"
             $ReportSummary += [PSCustomObject]@{ Check = "Firewall Posture"; Status = "Warning"; Details = "No results returned." }
        }
    } else {
        Write-EvidenceLog "Firewall Posture Report script not found at $FirewallScriptPath." "WARN"
        $ReportSummary += [PSCustomObject]@{ Check = "Firewall Posture"; Status = "Skipped"; Details = "Script not found." }
    }


    # --- 2. Secure Configuration (RDP Exposure, SMB Shares, LAPS) ---
    Write-EvidenceLog "Collecting Secure Configuration evidence..."
    
    # RDP Exposure
    $RdpExposureReportPath = Join-Path -Path $EvidenceFolder -ChildPath "RdpExposureReport.csv"
    $RdpExposureScriptPath = Join-Path -Path $PSScriptRoot -ChildPath "..\..\Security\Get-RDPExposureReport.ps1"
    if (Test-Path -Path $RdpExposureScriptPath) {
        & $RdpExposureScriptPath -ComputerName $TargetComputers -ExportPath $RdpExposureReportPath -ErrorAction SilentlyContinue
        Write-EvidenceLog "RDP Exposure Report saved to $RdpExposureReportPath."
        $ReportSummary += [PSCustomObject]@{ Check = "RDP Exposure"; Status = "Completed"; Details = "See $RdpExposureReportPath" }
    } else {
        Write-EvidenceLog "RDP Exposure Report script not found." "WARN"
        $ReportSummary += [PSCustomObject]@{ Check = "RDP Exposure"; Status = "Skipped"; Details = "Script not found." }
    }

    # SMB Share Risk (relies on File-Server-Management\Get-ShareRiskSummary.ps1)
    $ShareRiskReportPath = Join-Path -Path $EvidenceFolder -ChildPath "ShareRiskSummaryReport.csv"
    $ShareRiskScriptPath = Join-Path -Path $PSScriptRoot -ChildPath "..\..\File-Server-Management\Get-ShareRiskSummary.ps1"
    if (Test-Path -Path $ShareRiskScriptPath) {
        & $ShareRiskScriptPath -ComputerName $TargetComputers -ExportPath $ShareRiskReportPath -ErrorAction SilentlyContinue
        Write-EvidenceLog "SMB Share Risk Summary Report saved to $ShareRiskReportPath."
        $ReportSummary += [PSCustomObject]@{ Check = "SMB Share Risk"; Status = "Completed"; Details = "See $ShareRiskReportPath" }
    } else {
        Write-EvidenceLog "SMB Share Risk Summary Report script not found." "WARN"
        $ReportSummary += [PSCustomObject]@{ Check = "SMB Share Risk"; Status = "Skipped"; Details = "Script not found." }
    }

    # LAPS Status
    $LapsStatusReportPath = Join-Path -Path $EvidenceFolder -ChildPath "LapsStatusReport.csv"
    $LapsScriptPath = Join-Path -Path $PSScriptRoot -ChildPath "..\..\Security\Get-LAPSStatus.ps1"
    if (Test-Path -Path $LapsScriptPath) {
        & $LapsScriptPath -ComputerName $TargetComputers -ExportPath $LapsStatusReportPath -ErrorAction SilentlyContinue
        Write-EvidenceLog "LAPS Status Report saved to $LapsStatusReportPath."
        $ReportSummary += [PSCustomObject]@{ Check = "LAPS Status"; Status = "Completed"; Details = "See $LapsStatusReportPath" }
    } else {
        Write-EvidenceLog "LAPS Status Report script not found." "WARN"
        $ReportSummary += [PSCustomObject]@{ Check = "LAPS Status"; Status = "Skipped"; Details = "Script not found." }
    }

    # --- 3. Access Control (Local Admin Membership) ---
    Write-EvidenceLog "Collecting Access Control evidence (Local Admin)..."
    $LocalAdminControlReportPath = Join-Path -Path $EvidenceFolder -ChildPath "LocalAdminControlReport.csv"
    $LocalAdminControlScriptPath = Join-Path -Path $PSScriptRoot -ChildPath "Get-LocalAdminControlReport.ps1" # This script needs to be created
    if (Test-Path -Path $LocalAdminControlScriptPath) {
        & $LocalAdminControlScriptPath -ComputerName $TargetComputers -ExportPath $LocalAdminControlReportPath -ErrorAction SilentlyContinue
        Write-EvidenceLog "Local Admin Control Report saved to $LocalAdminControlReportPath."
        $ReportSummary += [PSCustomObject]@{ Check = "Local Admin Control"; Status = "Completed"; Details = "See $LocalAdminControlReportPath" }
    } else {
        Write-EvidenceLog "Local Admin Control Report script not found." "WARN"
        $ReportSummary += [PSCustomObject]@{ Check = "Local Admin Control"; Status = "Skipped"; Details = "Script not found." }
    }

    # --- 4. Malware Protection (Defender Status) ---
    Write-EvidenceLog "Collecting Malware Protection evidence..."
    $MalwareProtectionReportPath = Join-Path -Path $EvidenceFolder -ChildPath "MalwareProtectionReport.csv"
    $MalwareProtectionScriptPath = Join-Path -Path $PSScriptRoot -ChildPath "Get-MalwareProtectionReport.ps1" # This script needs to be created
    if (Test-Path -Path $MalwareProtectionScriptPath) {
        & $MalwareProtectionScriptPath -ComputerName $TargetComputers -ExportPath $MalwareProtectionReportPath -ErrorAction SilentlyContinue
        Write-EvidenceLog "Malware Protection Report saved to $MalwareProtectionReportPath."
        $ReportSummary += [PSCustomObject]@{ Check = "Malware Protection"; Status = "Completed"; Details = "See $MalwareProtectionReportPath" }
    } else {
        Write-EvidenceLog "Malware Protection Report script not found." "WARN"
        $ReportSummary += [PSCustomObject]@{ Check = "Malware Protection"; Status = "Skipped"; Details = "Script not found." }
    }


    # --- 5. Patch Management (Windows Update Status) ---
    Write-EvidenceLog "Collecting Patch Management evidence..."
    $PatchComplianceReportPath = Join-Path -Path $EvidenceFolder -ChildPath "PatchComplianceReport.csv"
    $PatchComplianceScriptPath = Join-Path -Path $PSScriptRoot -ChildPath "Get-PatchComplianceReport.ps1" # This script needs to be created
    if (Test-Path -Path $PatchComplianceScriptPath) {
        $PatchComplianceResults = & $PatchComplianceScriptPath -ComputerName $TargetComputers -ExportPath $PatchComplianceReportPath -ErrorAction SilentlyContinue
        if ($PatchComplianceResults) {
            $PatchComplianceResults | Export-Report -ExportPath (Join-Path $EvidenceFolder -ChildPath "PatchComplianceReport.html") -HtmlTitle "Patch Compliance Report"
            Write-EvidenceLog "Patch Compliance Report saved to $PatchComplianceReportPath."
            $ReportSummary += [PSCustomObject]@{ Check = "Patch Compliance"; Status = "Completed"; Details = "See $PatchComplianceReportPath" }
        }
        else {
             Write-EvidenceLog "Patch Compliance Report script ran, but no results returned." "WARN"
             $ReportSummary += [PSCustomObject]@{ Check = "Patch Compliance"; Status = "Warning"; Details = "No results returned." }
        }
    } else {
        Write-EvidenceLog "Patch Compliance Report script not found." "WARN"
        $ReportSummary += [PSCustomObject]@{ Check = "Patch Compliance"; Status = "Skipped"; Details = "Script not found." }
    }

    # --- Final Summary Report ---
    Write-EvidenceLog "Generating overall summary report."
    $SummaryHtmlPath = Join-Path -Path $EvidenceFolder -ChildPath "Index.html"
    $ReportSummary | Export-Report -ExportPath $SummaryHtmlPath -HtmlTitle "$OrganizationName Cyber Essentials Evidence Pack Summary"
    Write-EvidenceLog "Overall summary saved to $SummaryHtmlPath."

    Write-EvidenceLog "Cyber Essentials Evidence Pack generation complete."

    if (-not $NoAutoOpen) {
        Invoke-Item -Path $EvidenceFolder
    }
}
catch {
    Write-EvidenceLog "An error occurred during evidence pack creation: $($_.Exception.Message)" "ERROR"
    throw $_
}
