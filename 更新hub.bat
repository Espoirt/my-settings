@echo off
setlocal enabledelayedexpansion

set "HOSTS_FILE=%SystemRoot%\System32\drivers\etc\hosts"
set "TEMP_FILE=%TEMP%\hosts_temp.txt"
set "NEW_HOSTS=%TEMP%\new_hosts.txt"

:: Check if running as administrator
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo ERROR: This script must be run as Administrator.
    echo Please right-click and select "Run as administrator".
    pause
    exit /b 1
)

:: Step 1: Remove the block between markers
echo Removing existing fetch-github-hosts block...
(
    set "skip=0"
    for /f "usebackq delims=" %%a in ("%HOSTS_FILE%") do (
        set "line=%%a"
        :: Check for begin marker
        echo !line! | findstr /c:"# fetch-github-hosts begin" >nul
        if !errorlevel! equ 0 (
            set "skip=1"
        )
        :: If not skipping, output the line
        if !skip! equ 0 echo !line!
        :: Check for end marker
        echo !line! | findstr /c:"# fetch-github-hosts end" >nul
        if !errorlevel! equ 0 (
            set "skip=0"
        )
    )
) > "%TEMP_FILE%"

:: Step 2: Download the new hosts content
echo Downloading new hosts from https://hosts.gitcdn.top/hosts.txt...
powershell -Command "Invoke-WebRequest -Uri 'https://hosts.gitcdn.top/hosts.txt' -OutFile '%NEW_HOSTS%'"

if %errorlevel% neq 0 (
    echo ERROR: Failed to download the file.
    pause
    exit /b 1
)

:: Step 3: Append the downloaded content to the filtered hosts file
echo Appending new content...
(
    type "%TEMP_FILE%"
    echo.
    type "%NEW_HOSTS%"
) > "%HOSTS_FILE%"

:: Cleanup
del "%TEMP_FILE%" "%NEW_HOSTS%" 2>nul

echo.
echo Hosts file updated successfully.
ipconfig /flushdns
echo DNS cache flushed.

pause