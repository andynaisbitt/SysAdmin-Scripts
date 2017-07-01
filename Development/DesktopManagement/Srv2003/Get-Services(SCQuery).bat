@echo off
TITLE Get running services (srv 2003+)
set /p UserInputPath= Which server?
sc \\%UserInputPath%  query type= service | findstr SERVICE_NAME
CMD -K
