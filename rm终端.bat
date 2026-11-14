@echo off
set "filePath=C:\Users\Anea\AppData\Roaming\Microsoft\Windows\PowerShell\PSReadline\ConsoleHost_history.txt"

echo working...
if exist "%filePath%" (
    del /f /q "%filePath%"
    echo delete ok!
) else (
    echo poi no files found.
)

pause