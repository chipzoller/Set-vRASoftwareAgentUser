echo off
set arg1=%1
set arg2=%2
powershell.exe -ExecutionPolicy Bypass -File C:\opt\Set-vRASoftwareAgentUser.ps1 -userName %arg1% -userPass %arg2%