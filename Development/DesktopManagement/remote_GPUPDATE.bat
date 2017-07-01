@echo off
TITLE Force Group Policy Update
set /p UserInputPath= Which computer?
CD C:\Scripts\Sysinternals\PSTools\

REM Refreshing Group Policy..
psexec.exe \\%UserInputPath% gpupdate
