@echo off
TITLE Check Who's logged onto remote server
Set /p UserInputPath= Which Computer?
qwinsta /server:%UserInputPath
CMD /K
