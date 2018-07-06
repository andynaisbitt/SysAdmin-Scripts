<#
    Update Group navigation

    TO DO:
        - Add HTML Table function to display links to WSUS Computer Group Reports in a navagation menu

#>





<#
    WSUS Report
    
    ** Requires WSUS Administrator Console Installed or UpdateServices Module available **        
    
    TO DO:
        - SUSDB Size
        - Computers in Active Directory but not in WSUS (OPTIONAL)
#>

#region User Specified WSUS Information
$WSUSServer = ''

#Accepted values are "80","443","8530" and "8531"
$Port = 8530 
$UseSSL = $False

#Specify when a computer is considered stale
$DaysComputerStale = 180 

#Send email of report
[bool]$SendEmail = $TRUE
#Display HTML file
[bool]$ShowFile = $TRUE
#endregion User Specified WSUS Information

#region User Specified Email Information
$EmailParams = @{
    To = ''
    From = ''    
    Subject = "$WSUSServer Server Report"
    SMTPServer = ''
    BodyAsHtml = $True
}
#endregion User Specified Email Information

#region Helper Functions
Function Set-AlternatingCSSClass {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$True,ValueFromPipeline=$True)]
        [string]$HTMLFragment,
        [Parameter(Mandatory=$True)]
        [string]$CSSEvenClass,
        [Parameter(Mandatory=$True)]
        [string]$CssOddClass
    )
    [xml]$xml = $HTMLFragment
    $table = $xml.SelectSingleNode('table')
    $classname = $CSSOddClass
    foreach ($tr in $table.tr) {
        if ($classname -eq $CSSEvenClass) {
            $classname = $CssOddClass
        } else {
            $classname = $CSSEvenClass
        }
        $class = $xml.CreateAttribute('class')
        $class.value = $classname
        $tr.attributes.append($class) | Out-null
    }
    $xml.innerxml | out-string
}
Function Convert-Size {
    <#
        .SYSNOPSIS
            Converts a size in bytes to its upper most value.
        
        .DESCRIPTION
            Converts a size in bytes to its upper most value.
        
        .PARAMETER Size
            The size in bytes to convert
        
        .NOTES
            Author: Boe Prox
            Date Created: 22AUG2012
        
        .EXAMPLE
        Convert-Size -Size 568956
        555 KB
        
        Description
        -----------
        Converts the byte value 568956 to upper most value of 555 KB
        
        .EXAMPLE
        Get-ChildItem  | ? {! $_.PSIsContainer} | Select -First 5 | Select Name, @{L='Size';E={$_ | Convert-Size}}
        Name                                                           Size                                                          
        ----                                                           ----                                                          
        Data1.cap                                                      14.4 MB                                                       
        Data2.cap                                                      12.5 MB                                                       
        Image.iso                                                      5.72 GB                                                       
        Index.txt                                                      23.9 KB                                                       
        SomeSite.lnk                                                   1.52 KB     
        SomeFile.ini                                                   152 bytes   
        
        Description
        -----------
        Used with Get-ChildItem and custom formatting with Select-Object to list the uppermost size.          
    #>
    [cmdletbinding()]
    Param (
        [parameter(ValueFromPipeline=$True,ValueFromPipelineByPropertyName=$True)]
        [Alias("Length")]
        [int64]$Size
    )
    Begin {
        If (-Not $ConvertSize) {
            Write-Verbose ("Creating signature from Win32API")
            $Signature =  @"
                 [DllImport("Shlwapi.dll", CharSet = CharSet.Auto)]
                 public static extern long StrFormatByteSize( long fileSize, System.Text.StringBuilder buffer, int bufferSize );
"@
            $Global:ConvertSize = Add-Type -Name SizeConverter -MemberDefinition $Signature -PassThru
        }
        Write-Verbose ("Building buffer for string")
        $stringBuilder = New-Object Text.StringBuilder 1024
    }
    Process {
        Write-Verbose ("Converting {0} to upper most size" -f $Size)
        $ConvertSize::StrFormatByteSize( $Size, $stringBuilder, $stringBuilder.Capacity ) | Out-Null
        $stringBuilder.ToString()
    }
}
#endregion Helper Functions

#region Load WSUS Required Assembly
If (-Not (Get-Module -ListAvailable -Name UpdateServices)) {
    #Add-Type "$Env:ProgramFiles\Update Services\Api\Microsoft.UpdateServices.Administration.dll"
    $Null = [reflection.assembly]::LoadWithPartialName("Microsoft.UpdateServices.Administration")
} Else {
    Import-Module -Name UpdateServices
}
#endregion Load WSUS Required Assembly

#region CSS Layout
$head=@"
    <style> 
        h1 {
            text-align:center;
            border-bottom:1px solid #666666;
            color:#1e56a9;
        }
		TABLE {
			TABLE-LAYOUT: fixed; 
			FONT-SIZE: 100%; 
			WIDTH: 100%
		}
		* {
			margin:0
		}

		.pageholder {
			margin: 0px auto;
		}
					
		td {
			VERTICAL-ALIGN: TOP; 
			FONT-FAMILY: Calibri Light
		}
					
		th {
			VERTICAL-ALIGN: TOP; 
			COLOR: #018AC0; 
			TEXT-ALIGN: left;
            background-color:DarkGrey;
            color:Black;
		}
        body {
            text-align:left;
            font-smoothing:always;
            width:100%;
        }
        .odd { background-color:#ffffff; }
        .even { background-color:#dddddd; }               
    </style>
"@
#endregion CSS Layout

#region Initial WSUS Connection
$ErrorActionPreference = 'Stop'
Try {
    $Wsus = [Microsoft.UpdateServices.Administration.AdminProxy]::GetUpdateServer($WSUSServer,$UseSSL,$Port)
} Catch {
    Write-warning "$($WSUSServer)<$($Port)>: $($_)"
    Break
}
$ErrorActionPreference = 'Continue'
#endregion Initial WSUS Connection

#region Pre-Stage -- Used in more than one location
$htmlFragment = ''
$WSUSConfig = $Wsus.GetConfiguration()
$WSUSStats = $Wsus.GetStatus()
$TargetGroups = $Wsus.GetComputerTargetGroups()
$EmptyTargetGroups = $TargetGroups | Where {
    $_.GetComputerTargets().Count -eq 0 -AND $_.Name -ne 'Unassigned Computers'
}

#Stale Computers
$computerscope = New-Object Microsoft.UpdateServices.Administration.ComputerTargetScope
$computerscope.ToLastReportedStatusTime = (Get-Date).AddDays(-$DaysComputerStale)
$StaleComputers = $wsus.GetComputerTargets($computerscope) | ForEach {
    [pscustomobject]@{
        Computername = $_.FullDomainName
        ID=  $_.Id
        IPAddress = $_.IPAddress
        LastReported = $_.LastReportedStatusTime
        LastSync = $_.LastSyncTime
        TargetGroups = ($_.GetComputerTargetGroups() | Select -Expand Name) -join ', '
    }
}

#Pending Reboots
$updateScope = New-Object Microsoft.UpdateServices.Administration.UpdateScope
$updateScope.IncludedInstallationStates = 'InstalledPendingReboot'
$computerScope = New-Object Microsoft.UpdateServices.Administration.ComputerTargetScope
$computerScope.IncludedInstallationStates = 'InstalledPendingReboot'
$GroupRebootHash=@{}
$ComputerPendingReboot = $wsus.GetComputerTargets($computerScope) | ForEach {
    $Update = ($_.GetUpdateInstallationInfoPerUpdate($updateScope) | ForEach {
        $Update = $_.GetUpdate()
        $Update.title
    }) -join ', '
    If ($Update) {
        $TempTargetGroups = ($_.GetComputerTargetGroups() | Select -Expand Name)
        $TempTargetGroups | ForEach {
            $GroupRebootHash[$_]++
        }
        [pscustomobject] @{
            Computername = $_.FullDomainName
            ID = $_.Id
            IPAddress = $_.IPAddress
            TargetGroups = $TempTargetGroups -join ', '
            #Updates = $Update
        }
    }
} | Sort Computername

#Failed Installations
$updateScope = New-Object Microsoft.UpdateServices.Administration.UpdateScope
$updateScope.IncludedInstallationStates = 'Failed'
$computerScope = New-Object Microsoft.UpdateServices.Administration.ComputerTargetScope
$computerScope.IncludedInstallationStates = 'Failed'
$GroupFailHash=@{}
$ComputerHash = @{}
$UpdateHash = @{}
$ComputerFailInstall = $wsus.GetComputerTargets($computerScope) | ForEach {
    $Computername = $_.FullDomainName
    $Update = ($_.GetUpdateInstallationInfoPerUpdate($updateScope) | ForEach {
        $Update = $_.GetUpdate()
        $Update.title
        $ComputerHash[$Computername] += ,$Update.title
        $UpdateHash[$Update.title] += ,$Computername
    }) -join ', '
    If ($Update) {
        $TempTargetGroups = ($_.GetComputerTargetGroups() | Select -Expand Name)
        $TempTargetGroups | ForEach {
            $GroupFailHash[$_]++
        }
        [pscustomobject] @{
            Computername = $_.FullDomainName
            ID = $_.Id
            IPAddress = $_.IPAddress
            TargetGroups = $TempTargetGroups -join ', '
            Updates = $Update
        }
    }
} | Sort Computername
#endregion Pre-Stage -- Used in more than one location

#region WSUS SERVER INFORMATION
$Pre = @"
<div style='margin: 0px auto; BACKGROUND-COLOR:#1e56a9;Color:White;font-weight:bold;FONT-SIZE: 16pt;'>
    WSUS Server Information
</div>
"@
    #region WSUS Version
                    $WSUSVersion = [pscustomobject]@{
    Computername = $WSUS.ServerName
    Version = $Wsus.Version
    Port = $Wsus.PortNumber
    ServerProtocolVersion = $Wsus.ServerProtocolVersion
    }
    $Pre += @"
        <div style='margin: 0px auto; BACKGROUND-COLOR:LightBlue;Color:Black;font-weight:bold;FONT-SIZE: 14pt;'>
            WSUS Information
        </div>

"@
    $Body = $WSUSVersion | ConvertTo-Html -Fragment | Out-String | Set-AlternatingCSSClass -CSSEvenClass 'even' -CssOddClass 'odd'
    $Post = "<br>"
    $htmlFragment += $Pre,$Body,$Post
    #endregion WSUS Version

    #region WSUS Server Content
    $drive = $WSUSConfig.LocalContentCachePath.Substring(0,2)
    $Data = Get-CIMInstance -ComputerName $WSUSServer -ClassName Win32_LogicalDisk -Filter "DeviceID='$drive'"
    $UsedSpace = $data.Size - $data.Freespace
    $PercentFree = "{0:P}" -f ($Data.Freespace / $Data.Size)
    $Pre = @"
        <div style='margin: 0px auto; BACKGROUND-COLOR:LightBlue;Color:Black;font-weight:bold;FONT-SIZE: 14pt;'>
            WSUS Server Content Drive
        </div>

"@
    $WSUSDrive = [pscustomobject]@{
        LocalContentPath = $WSUSConfig.LocalContentCachePath
        TotalSpace = $data.Size | Convert-Size
        UsedSpace = $UsedSpace | Convert-Size
        FreeSpace = $Data.freespace | Convert-Size
        PercentFree = $PercentFree
    }
    $Body = $WSUSDrive | ConvertTo-Html -Fragment | Out-String | Set-AlternatingCSSClass -CSSEvenClass 'even' -CssOddClass 'odd'
    $Post = "<br>"
    $htmlFragment += $Pre,$Body,$Post
    #endregion WSUS Server Content

    #region Last Synchronization
    $synch = $wsus.GetSubscription()
    $SynchHistory = $Synch.GetSynchronizationHistory()[0]
    $WSUSSynch = [pscustomobject]@{
        IsAuto = $synch.SynchronizeAutomatically
        SynchTime = $synch.SynchronizeAutomaticallyTimeOfDay
        LastSynch = $synch.LastSynchronizationTime
        Result = $SynchHistory.Result
    }
    If ($SynchHistory.Result -eq 'Failed') {
        $WSUSSynch = $WSUSSynch | Add-Member -MemberType NoteProperty -Name ErrorType -Value $SynchHistory.Error -PassThru |
        Add-Member -MemberType NoteProperty -Name ErrorText -Value $SynchHistory.ErrorText -PassThru
    }
    $Pre = @"
        <div style='margin: 0px auto; BACKGROUND-COLOR:LightBlue;Color:Black;font-weight:bold;FONT-SIZE: 14pt;'>
            Last Server Synchronization
        </div>

"@
    $Body = $WSUSSynch | ConvertTo-Html -Fragment | Out-String | Set-AlternatingCSSClass -CSSEvenClass 'even' -CssOddClass 'odd'
    $Post = "<br>"
    $htmlFragment += $Pre,$Body,$Post
    #endregion Last Synchronization

    #region Upstream Server Config
    $WSUSUpdateConfig = [pscustomobject]@{
        SyncFromMU = $WSUSConfig.SyncFromMicrosoftUpdate
        UpstreamServer = $WSUSConfig.UpstreamWsusServerName
        UpstreamServerPort = $WSUSConfig.UpstreamWsusServerPortNumber
        SSLConnection = $WSUSConfig.UpstreamWsusServerUseSsl
    }
    $Pre = @"
        <div style='margin: 0px auto; BACKGROUND-COLOR:LightBlue;Color:Black;font-weight:bold;FONT-SIZE: 14pt;'>
            Upstream Server Information
        </div>

"@
    $Body = $WSUSUpdateConfig | ConvertTo-Html -Fragment | Out-String | Set-AlternatingCSSClass -CSSEvenClass 'even' -CssOddClass 'odd'
    $Post = "<br>"
    $htmlFragment += $Pre,$Body,$Post
    #endregion Upstream Server Config

    #region Automatic Approvals
    $Rules = $wsus.GetInstallApprovalRules()
    $ApprovalRules = $Rules | ForEach {
        [pscustomobject]@{
            Name=  $_.Name
            ID = $_.ID
            Enabled = $_.Enabled
            Action = $_.Action
            Categories = ($_.GetCategories() | Select -ExpandProperty Title) -join ', '
            Classifications = ($_.GetUpdateClassifications() | Select -ExpandProperty Title) -join ', '
            TargetGroups = ($_.GetComputerTargetGroups() | Select -ExpandProperty Name) -join ', '
        }
    }
    $Pre = @"
        <div style='margin: 0px auto; BACKGROUND-COLOR:LightBlue;Color:Black;font-weight:bold;FONT-SIZE: 14pt;'>
            Automatic Approvals
        </div>

"@
    $Body = $ApprovalRules | ConvertTo-Html -Fragment | Out-String | Set-AlternatingCSSClass -CSSEvenClass 'even' -CssOddClass 'odd'
    $Post = "<br>"
    $htmlFragment += $Pre,$Body,$Post
    #endregion Automatic Approvals

    #region WSUS Child Servers
    $ChildUpdateServers = $wsus.GetChildServers()
    If ($ChildUpdateServers) {
        $ChildServers =  $ChildUpdateServers | ForEach {
            [pscustomobject]@{
                ChildServer = $_.FullDomainName
                Version = $_.Version
                UpstreamServer = $_.UpdateServer.Name
                LastSyncTime = $_.LastSyncTime
                SyncsFromDownStreamServer = $_.SyncsFromDownStreamServer
                LastRollUpTime = $_.LastRollupTime
                IsReplica = $_.IsReplica
            }
        }
    }
    $Pre = @"
        <div style='margin: 0px auto; BACKGROUND-COLOR:LightBlue;Color:Black;font-weight:bold;FONT-SIZE: 14pt;'>
            Child Servers
        </div>

"@
    $Body = $ChildServers | ConvertTo-Html -Fragment | Out-String | Set-AlternatingCSSClass -CSSEvenClass 'even' -CssOddClass 'odd'
    $Post = "<br>"
    $htmlFragment += $Pre,$Body,$Post
    #endregion WSUS Child Servers

    #region Database Information
    $WSUSDB = $WSUS.GetDatabaseConfiguration()
    $DBInfo = [pscustomobject]@{
        DatabaseName = $WSUSDB.databasename
        Server = $WSUSDB.ServerName
        IsDatabaseInternal = $WSUSDB.IsUsingWindowsInternalDatabase
        Authentication = $WSUSDB.authenticationmode
    }
    $Pre = @"
        <div style='margin: 0px auto; BACKGROUND-COLOR:LightBlue;Color:Black;font-weight:bold;FONT-SIZE: 14pt;'>
            WSUS Database
        </div>

"@
    $Body = $DBInfo | ConvertTo-Html -Fragment | Out-String | Set-AlternatingCSSClass -CSSEvenClass 'even' -CssOddClass 'odd'
    $Post = "<br>"
    $htmlFragment += $Pre,$Body,$Post
    #endregion Database Information

#endregion WSUS SERVER INFORMATION

#region CLIENT INFORMATION
$Pre = @"
<div style='margin: 0px auto; BACKGROUND-COLOR:#1e56a9;Color:White;font-weight:bold;FONT-SIZE: 16pt;'>
    WSUS Client Information
</div>
"@
    #region Computer Statistics
    $WSUSComputerStats = [pscustomobject]@{
        TotalComputers = [int]$WSUSStats.ComputerTargetCount    
        "Stale($DaysComputerStale Days)" = ($StaleComputers | Measure-Object).count
        NeedingUpdates = [int]$WSUSStats.ComputerTargetsNeedingUpdatesCount
        FailedInstall = [int]$WSUSStats.ComputerTargetsWithUpdateErrorsCount
        PendingReboot = ($ComputerPendingReboot | Measure-Object).Count
    }

    $Pre += @"
        <div style='margin: 0px auto; BACKGROUND-COLOR:LightBlue;Color:Black;font-weight:bold;FONT-SIZE: 14pt;'>
            Computer Statistics
        </div>

"@
    $Body = $WSUSComputerStats | ConvertTo-Html -Fragment | Out-String | Set-AlternatingCSSClass -CSSEvenClass 'even' -CssOddClass 'odd'
    $Post = "<br>"
    $htmlFragment += $Pre,$Body,$Post
    #endregion Computer Statistics

   
   
   
   
   
    #region SCRIPT MERGED FROM ORINGINAL REPORT
    #https://community.spiceworks.com/topic/2146262-trouble-merging-powershell-script-s?page=1#entry-7823822






# Create empty arrays.
$UpdateStatus = @()
$SummaryStatus = @()
$ServersPerUpdate = @()

# Load WSUS assembly.
[reflection.assembly]::LoadWithPartialName("Microsoft.UpdateServices.Administration") | Out-Null
# Connect to WSUS server and set the connection object into a variable.
$WSUS = [Microsoft.UpdateServices.Administration.AdminProxy]::getUpdateServer("$WSUSServer", $false, 8530)

# Record the last time that WSUS was syncronized with updates.
$LastSync = ($wsus.GetSubscription()).LastSynchronizationTime

# Create a default update scope object.
$UpdateScope = New-Object Microsoft.UpdateServices.Administration.UpdateScope
# Modify the update scope ApprovedStates value from "Any" to "LatesRevisionApproved".
$UpdateScope.ApprovedStates = [Microsoft.UpdateServices.Administration.ApprovedStates]::LatestRevisionApproved
# Create a computerscope object for use as an a requred part of a method below.
$ComputerScope = New-Object Microsoft.UpdateServices.Administration.ComputerTargetScope

# Get the "Servers" WSUS group using a hardcoded ID value.
$ComputerTargetGroups = $WSUS.GetComputerTargetGroups() `
| Where { $_.id -eq 'a0a08746-4dbe-4a37-9adf-9e7652c0b421' }
# Get all the computers objects that are members of the "Servers" group and set into variable
$MemberOfGroup = $wsus.getComputerTargetGroup($ComputerTargetGroups.Id).GetComputerTargets()

# Use a foreach loop to process summaries per computer for each member of the "Servers" group. `
#  Then populate an array with a updates needed.
Foreach ($Object in $wsus.GetSummariesPerComputerTarget($updatescope, $computerscope)) {
	# Use a nested foreach to process the CES Mail Servers members.	
	foreach ($object1 in $MemberOfGroup) {
		# Use an if statement to match the wsus objects that contain update summaries with
		#  the members of the CES Mail servers members.
		If ($object.computertargetid -match $object1.id) {
			# Set the fulldomain name of the CES Mail Server member in a variable.
			$ComputerTargetToUpdate = $wsus.GetComputerTargetByName($object1.FullDomainName)
			# Filter the server for updates that are marked for install with the state
			#  being either downloaded or notinstalled.  These are updates that are needed.
			$NeededUpdate = $ComputerTargetToUpdate.GetUpdateInstallationInfoPerUpdate() `
			| where {
				($_.UpdateApprovalAction -eq "install") -and `
				(($_.UpdateInstallationState -eq "downloaded") -or `
				($_.UpdateInstallationState -eq "notinstalled"))
			}
			
			# Null out the following variables so that they don't contaminate
			#  op_addition variables in the below nested foreach loop.
			$FailedUpdateReport = $null
			$NeededUpdateReport = $null
			# Use a nested foreach loop to accumulate and convert the needed updates to the KB number with URL in
			# an HTML format.
			if ($NeededUpdate -ne $null) {
				foreach ($Update in $NeededUpdate) {
					$myObject2 = New-Object -TypeName PSObject
					$myObject2 | add-member -type Noteproperty -Name Server -Value (($object1 | select -ExpandProperty FullDomainName) -replace ".FQDN", "")
					$myObject2 | add-member -type Noteproperty -Name Update -Value ('<a href' + '=' + '"' + ($wsus.GetUpdate([Guid]$update.updateid).AdditionalInformationUrls) + '"' + '>' + (($wsus.GetUpdate([Guid]$update.updateid)).title) + '<' + '/' + 'a' + '>')
					$UpdateStatus += $myObject2
					
					if ($Update.UpdateInstallationState -eq "Failed") {
						$FailedUpdateReport += ('<a href' + '=' + '"' + ($wsus.GetUpdate([Guid]$update.updateid).AdditionalInformationUrls) `
						+ '"' + '>' + "(" + (($wsus.GetUpdate([Guid]$update.updateid)).KnowledgebaseArticles) + ") " + '<' + '/' + 'a' + '>')
					}
					if ($Update.UpdateInstallationState -eq "Notinstalled" -or $Update.UpdateInstallationState -eq "Downloaded") {
						$NeededUpdateReport += ('<a href' + '=' + '"' + ($wsus.GetUpdate([Guid]$update.updateid).AdditionalInformationUrls) `
						+ '"' + '>' + "(" + (($wsus.GetUpdate([Guid]$update.updateid)).KnowledgebaseArticles) + ") " + '<' + '/' + 'a' + '>')
					}
				}
			}
			# Create a custom PSObject to contain summary data about each server and updates needed.
			$myObject1 = New-Object -TypeName PSObject
			$myObject1 | add-member -type Noteproperty -Name Server -Value (($object1 | select -ExpandProperty FullDomainName) -replace ".FQDN", "")
			$myObject1 | add-member -type Noteproperty -Name UnkownCount -Value $object.UnknownCount
			$myObject1 | add-member -type Noteproperty -Name NotInstalledCount -Value $object.NotInstalledCount
			$myObject1 | add-member -type Noteproperty -Name NotApplicable -Value $object.NotApplicableCount
			$myObject1 | add-member -type Noteproperty -Name DownloadedCount -Value $object.DownloadedCount
			$myObject1 | add-member -type Noteproperty -Name InstalledCount -Value $object.InstalledCount
			$myObject1 | add-member -type Noteproperty -Name InstalledPendingRebootCount -Value $object.InstalledPendingRebootCount
			$myObject1 | add-member -type Noteproperty -Name FailedCount -Value $object.FailedCount
			$myObject1 | add-member -type Noteproperty -Name ComputerTargetId -Value $object.ComputerTargetId
			$myObject1 | add-member -type Noteproperty -Name NeededCount -Value ($NeededUpdate | measure).count
			$myObject1 | add-member -type Noteproperty -Name Failed -Value $FailedUpdateReport
			$myObject1 | add-member -type Noteproperty -Name Needed -Value $NeededUpdateReport
			$SummaryStatus += $myObject1
		}
	}
}
$uniqueupdates = $UpdateStatus | sort -Unique update | select update

foreach ($uniqueupdate in $uniqueupdates) {
	$servers = $null
	$myObject3 = New-Object -TypeName PSObject
	$myObject3 | add-member -type Noteproperty -Name Update -Value $uniqueupdate.update
	foreach ($object in $UpdateStatus) {
		if ($object.Update -eq $uniqueupdate.update) {
			$servers += $object.server + " "
		}
	}
	$myObject3 | add-member -type Noteproperty -Name Servers -Value $servers
	$ServersPerUpdate += $myObject3
}

# Rewrite the array and eliminate servers that have 0 for needed updates.
$SummaryStatus = $SummaryStatus | where { $_.neededcount -ne 0 } | sort server

# List a summary of changes in a special table leveraging the "First" table class style listed above.
$WSUSHead += "<table class=`"First`">`r`n"
# Note the LastSync time.
$WSUSHead += "<tr><td class=`"First`"><b>Last Sync:</b></td><td class=`"First`"> " + `
$LastSync + "</td></tr>`r`n"
$WSUSHead += "</Body>`r`n"
$WSUSHead += "</Style>`r`n"
$WSUSHead += "</Head>`r`n"

# Build a variable with HTML for sending a report.
$UpdatesHTML = $HTMLHead
# Continue building HTML with the updates needed
$UpdatesHTML += $SummaryStatus | convertto-html -Fragment `
@{ Label = "Server"; Expression = { $_.server } }, @{ Label = "Needed Count"; Expression = { $_.NeededCount } }, @{ Label = "Not Installed"; Expression = { $_.NotInstalledCount } }, `
@{ Label = "Downloaded"; Expression = { $_.DownloadedCount } }, @{ Label = "Pending Reboot"; Expression = { $_.InstalledPendingRebootCount } }, @{ Label = "Failed Updates"; Expression = { $_.FailedCount } }, `
@{ Label = "Needed"; Expression = { $_.Needed } }

$ServersHTML = $ServersPerUpdate | convertto-html -Fragment `
@{ Label = "Update"; Expression = { $_.update } }, @{ Label = "Servers"; Expression = { $_.servers } }

# Add an assembly to fix up powershell HTML markup. Ensures all special characters
# are converted correctly.
Add-Type -AssemblyName System.Web
$UpdatesHTML = [System.Web.HttpUtility]::HtmlDecode($UpdatesHTML)
$ServersHTML = [System.Web.HttpUtility]::HtmlDecode($ServersHTML)
$MailMessage = "
<html>
 <body>
  $WSUSHead
  $UpdatesHTML
   <br>
  $ServersHTML
 </body>
</html>
"

        #region Client Update Status
    $Pre = @"
        <div style='margin: 0px auto; BACKGROUND-COLOR:LightBlue;Color:Black;font-weight:bold;FONT-SIZE: 14pt;'>
            Client update status(s)
        </div>

"@
    $Body = $summarystatus  | select Server, @{ Label = "Needed Count"; Expression = { $_.NeededCount } }, @{ Label = "Not Installed"; Expression = { $_.NotInstalledCount } }, @{ Label = "Downloaded"; Expression = { $_.DownloadedCount } }, @{ Label = "Pending Reboot"; Expression = { $_.InstalledPendingRebootCount } }, @{ Label = "Failed Updates"; Expression = { $_.FailedCount } } |
    sort "Needed Count" -Descending | convertto-html -Fragment | out-string | Set-AlternatingCSSClass -CSSEvenClass 'even' -CssOddClass 'odd' # removed Select Name, ID | ConvertTo-Html -Fragment from before OUT-STRING
    
    $Post = "<br>"
    $htmlFragment += $Pre,$Body,$Post
    #endregion Client Update Status

#endregion SCRIPT MERGED FROM ORINGINAL REPORT













    #region Operating System
    $Pre = @"
        <div style='margin: 0px auto; BACKGROUND-COLOR:LightBlue;Color:Black;font-weight:bold;FONT-SIZE: 14pt;'>
            By Operating System
        </div>

"@
    $Body = $wsus.GetComputerTargets() | Group OSDescription |
    Select @{L='OperatingSystem';E={$_.Name}}, Count  | 
    ConvertTo-Html -Fragment | Out-String | Set-AlternatingCSSClass -CSSEvenClass 'even' -CssOddClass 'Odd'
    $Post = "<br>"
    $htmlFragment += $Pre,$Body,$Post    
    #endregion Operating System

    #region Stale Computers
    $Pre = @"
        <div style='margin: 0px auto; BACKGROUND-COLOR:LightBlue;Color:Black;font-weight:bold;FONT-SIZE: 14pt;'>
            Stale Computers ($DaysComputerStale Days)
        </div>

"@
    $Body = $StaleComputers | ConvertTo-Html -Fragment | Out-String | Set-AlternatingCSSClass -CSSEvenClass 'even' -CssOddClass 'odd'
    $Post = "<br>"
    $htmlFragment += $Pre,$Body,$Post
    #endregion Stale Computers

    #region Unassigned Computers
    $Unassigned = ($TargetGroups | Where {
        $_.Name -eq 'Unassigned Computers'
    }).GetComputerTargets() | ForEach {
        [pscustomobject]@{
            Computername = $_.FullDomainName
            OperatingSystem = $_.OSDescription
            ID=  $_.Id
            IPAddress = $_.IPAddress
            LastReported = $_.LastReportedStatusTime
            LastSync = $_.LastSyncTime
        }    
    }
    $Pre = @"
        <div style='margin: 0px auto; BACKGROUND-COLOR:LightBlue;Color:Black;font-weight:bold;FONT-SIZE: 14pt;'>
            Unassigned Computers (in Unassigned Target Group)
        </div>

"@
    $Body = $Unassigned | ConvertTo-Html -Fragment | Out-String | Set-AlternatingCSSClass -CSSEvenClass 'even' -CssOddClass 'odd'
    $Post = "<br>"
    $htmlFragment += $Pre,$Body,$Post
    #endregion Unassigned Computers

    #region Failed Update Install
    $Pre = @"
        <div style='margin: 0px auto; BACKGROUND-COLOR:LightBlue;Color:Black;font-weight:bold;FONT-SIZE: 14pt;'>
            Failed Update Installations By Computer
        </div>

"@
    $Body = $ComputerFailInstall | ConvertTo-Html -Fragment | Out-String | Set-AlternatingCSSClass -CSSEvenClass 'even' -CssOddClass 'odd'
    $Post = "<br>"
    $htmlFragment += $Pre,$Body,$Post
    #endregion Failed Update Install

    #region Pending Reboot 
    $Pre = @"
        <div style='margin: 0px auto; BACKGROUND-COLOR:LightBlue;Color:Black;font-weight:bold;FONT-SIZE: 14pt;'>
            Computers with Pending Reboot
        </div>

"@
    $Body = $ComputerPendingReboot | ConvertTo-Html -Fragment | Out-String | Set-AlternatingCSSClass -CSSEvenClass 'even' -CssOddClass 'odd'
    $Post = "<br>"
    $htmlFragment += $Pre,$Body,$Post
    #endregion Pending Reboot

#endregion CLIENT INFORMATION

#region UPDATE INFORMATION
$Pre = @"
<div style='margin: 0px auto; BACKGROUND-COLOR:#1e56a9;Color:White;font-weight:bold;FONT-SIZE: 16pt;'>
    WSUS Update Information
</div>
"@
    #region Update Statistics
    $WSUSUpdateStats = [pscustomobject]@{
        TotalUpdates = [int]$WSUSStats.UpdateCount    
        Needed = [int]$WSUSStats.UpdatesNeededByComputersCount
        Approved = [int]$WSUSStats.ApprovedUpdateCount
        Declined = [int]$WSUSStats.DeclinedUpdateCount
        ClientInstallError = [int]$WSUSStats.UpdatesWithClientErrorsCount
        UpdatesNeedingFiles = [int]$WSUSStats.ExpiredUpdateCount    
    }
    $Pre += @"
        <div style='margin: 0px auto; BACKGROUND-COLOR:LightBlue;Color:Black;font-weight:bold;FONT-SIZE: 14pt;'>
            Update Statistics
        </div>

"@
    $Body = $WSUSUpdateStats | ConvertTo-Html -Fragment | Out-String | Set-AlternatingCSSClass -CSSEvenClass 'even' -CssOddClass 'odd'
    $Post = "<br>"
    $htmlFragment += $Pre,$Body,$Post
    #endregion Update Statistics

    #region Failed Update Installations
    $FailedUpdateInstall = $UpdateHash.GetEnumerator() | ForEach {
        [pscustomobject]@{
            Update = $_.Name
            Computername = ($_.Value) -join ', '
        }
    }
    $Pre = @"
        <div style='margin: 0px auto; BACKGROUND-COLOR:LightBlue;Color:Black;font-weight:bold;FONT-SIZE: 14pt;'>
            Failed Update Installations By Update
        </div>

"@
    $Body = $FailedUpdateInstall | ConvertTo-Html -Fragment | Out-String | Set-AlternatingCSSClass -CSSEvenClass 'even' -CssOddClass 'odd'
    $Post = "<br>"
    $htmlFragment += $Pre,$Body,$Post
    #endregion Failed Update Installations

#endregion UPDATE INFORMATION

#region TARGET GROUP INFORMATION
$Pre = @"
<div style='margin: 0px auto; BACKGROUND-COLOR:#1e56a9;Color:White;font-weight:bold;FONT-SIZE: 16pt;'>
    WSUS Target Group Information
</div>
"@
    #region Target Group Statistics
    $GroupStats = [pscustomobject]@{
        TotalGroups = [int]$TargetGroups.count
        TotalEmptyGroups = [int]$EmptyTargetGroups.Count
    }
    $Pre += @"
        <div style='margin: 0px auto; BACKGROUND-COLOR:LightBlue;Color:Black;font-weight:bold;FONT-SIZE: 14pt;'>
            Target Group Statistics
        </div>

"@
    $Body = $GroupStats | ConvertTo-Html -Fragment | Out-String | Set-AlternatingCSSClass -CSSEvenClass 'even' -CssOddClass 'odd'
    $Post = "<br>"
    $htmlFragment += $Pre,$Body,$Post
    #endregion Target Group Statistics

    #region Empty Groups
    $Pre = @"
        <div style='margin: 0px auto; BACKGROUND-COLOR:LightBlue;Color:Black;font-weight:bold;FONT-SIZE: 14pt;'>
            Empty Target Groups
        </div>

"@
    $Body = $EmptyTargetGroups | Select Name, ID | ConvertTo-Html -Fragment | Out-String | Set-AlternatingCSSClass -CSSEvenClass 'even' -CssOddClass 'odd'
    $Post = "<br>"
    $htmlFragment += $Pre,$Body,$Post
    #endregion Empty Groups

#endregion TARGET GROUP INFORMATION




#region Compile HTML Report
$HTMLParams = @{
    Head = $Head
    Title = "WSUS Report for $WSUSServer"
    PreContent = "<H1><font color='white'>Please view in html!</font><br>$WSUSServer Server Report</H1>"
    PostContent = "$($htmlFragment)<i>Report generated on $((Get-Date).ToString())</i>" 
}
$Report = ConvertTo-Html @HTMLParams | Out-String
#endregion Compile HTML Report

If ($ShowFile) {
    $Report | Out-File "\\1it01\f$\Support Documents\Maintenance\WMC - Windows Updates\1WSUS01\WSUS_Server_Report\$(Get-Date -Format dd.MM.yyyy)_Server_Report.html"
}

#region Send Email
If ($SendEmail) {
    $EmailParams.Body = $Report
    Send-MailMessage @EmailParams
}
#endregion Send Email
