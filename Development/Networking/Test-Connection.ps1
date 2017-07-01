$Destination = Read-Host -Prompt 'Input server to ping'
$Source = Read-Host -Prompt 'Input source server'
$Count = Read-Host -Prompt 'Number of requests to send'
$Date = Get-Date
Write-Host "We are now testing the connection between '$Destination' and '$Source' @ '$Date'"
Test-Connection -ComputerName $Destination -Source $Source -Count $Count
