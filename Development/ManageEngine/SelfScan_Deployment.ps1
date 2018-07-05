CD C:\ProgramData\
MKDIR ManageEngine
CD ManageEngine
$client = new-object System.Net.WebClient 
$client.DownloadFile("https://ithelp.filtronic.com/scanscript/SelfScan.exe","C:\ProgramData\ManageEngine\selfscan.exe")
$client.DownloadFile("file.xml","C:\ProgramData\ManageEngine\schedule.xml")

Register-ScheduledTask -Xml 'C:\ProgramData\ManageEngine\schedule.xml' -TaskName "ManageEngine SelfScan Task"
