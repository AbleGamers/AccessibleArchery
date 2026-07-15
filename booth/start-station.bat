@echo off
REM Double-click to launch this machine as a PLAY STATION (the game).
REM
REM Preferred: this .bat sits in the booth package folder NEXT TO
REM AccessibleArchery.exe (the exported build). Fallback: run from source
REM with Godot.exe next to the AccessibleArchery project folder.
setlocal

if exist "%~dp0AccessibleArchery.exe" (
	start "" "%~dp0AccessibleArchery.exe" -- --station --kiosk
	exit /b 0
)

set "DIR=%~dp0.."
set "BUNDLED_GODOT=%DIR%\..\Godot.exe"

if exist "%BUNDLED_GODOT%" (
	set "GODOT=%BUNDLED_GODOT%"
	goto :launch
)
where godot4.exe >nul 2>nul
if %ERRORLEVEL%==0 (
	set "GODOT=godot4.exe"
	goto :launch
)
where godot.exe >nul 2>nul
if %ERRORLEVEL%==0 (
	set "GODOT=godot.exe"
	goto :launch
)

echo Godot wasn't found.
echo Put Godot.exe next to the AccessibleArchery folder, or install Godot 4 on this machine.
pause
exit /b 1

:launch
"%GODOT%" --path "%DIR%" -- --station --kiosk
