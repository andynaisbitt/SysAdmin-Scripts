$computer = Read-Host "enter computer name..."
$user = (gwmi win32_computersystem -computer $computer).username.split('\')[-1]
$sid = (get-aduser $user).sid.value
invoke-command -computer $computer -scriptblock {
set-location registry::\HKEY_USERS
New-PSDrive HKU Registry HKEY_USERS
Set-Location HKU:
$drives = (gci -Path Microsoft.PowerShell.Core\Registry::HKEY_USERS\$($args[0])\Network -recurse)

$driveresults = foreach ($d in $drives){$q =  ("Microsoft.PowerShell.Core\Registry::HKEY_USERS\$($args[0])\Network\" + $d.pschildname);get-itemproperty -Path $q;}

$driveresults|Format-Table PSChildName,RemotePath -autosize -hidetableheaders

} -argumentlist $sid
