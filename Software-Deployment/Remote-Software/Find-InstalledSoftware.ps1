<#
.SYNOPSIS
Finds installed software by name (with fuzzy matching) and shows uninstall strings.
#>
param (
    [string]$Name,
    [string]$ComputerName
)

if (-not $Name) {
    $Name = Read-Host "Enter the software name to find (e.g., TeamViewer)"
}
if (-not $ComputerName) {
    $ComputerName = $env:COMPUTERNAME
}

try {
    $InstalledSoftware = Get-InstalledSoftware -ComputerName $ComputerName

    $FoundSoftware = $InstalledSoftware | Where-Object { $_.Name -like "*$Name*" }

    $Result = foreach ($Software in $FoundSoftware) {
        $UninstallString = $null
        # Attempt to find uninstall string in registry
        $UninstallKeyPaths = @(
            "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall",
            "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall"
        )
        foreach ($KeyPath in $UninstallKeyPaths) {
            $Key = Get-Item -Path $KeyPath\* -ErrorAction SilentlyContinue | Where-Object { (Get-ItemProperty -LiteralPath $_.PSPath -Name DisplayName -ErrorAction SilentlyContinue).DisplayName -like "*$($Software.Name)*" }
            if ($Key) {
                $UninstallString = (Get-ItemProperty -LiteralPath $Key.PSPath -Name UninstallString -ErrorAction SilentlyContinue).UninstallString
                break
            }
        }

        [PSCustomObject]@{
            ComputerName    = $ComputerName
            Name            = $Software.Name
            Version         = $Software.Version
            Publisher       = $Software.Vendor
            UninstallString = $UninstallString
        }
    }
    $Result
}
catch {
    Write-Error "An error occurred while finding installed software on '$ComputerName': $($_.Exception.Message)"
}
