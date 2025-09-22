@echo off
setlocal

REM Go to the folder of this .bat
pushd "%~dp0"

REM Prefer camel-case name, fall back to lower-case variant
set "SCRIPT=%~dp0Compare-Users-Main.ps1"
if not exist "%SCRIPT%" set "SCRIPT=%~dp0Compare-users-main.ps1"

if not exist "%SCRIPT%" (
  echo Could not find the main PowerShell script next to this .bat.
  echo Expected: Compare-Users-Main.ps1  OR  Compare-users-main.ps1
  pause
  exit /b 1
)

REM Use Windows PowerShell in STA, no profile, bypass policy
"%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe" ^
  -NoProfile -ExecutionPolicy Bypass -STA -File "%SCRIPT%"

popd
endlocal
