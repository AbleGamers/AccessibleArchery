@echo off
REM Double-click to launch this machine as the leaderboard server.
REM Run this on the back machine (the one that also drives the display monitor).
REM No export/build needed -- runs the project directly through Godot.
setlocal

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
"%GODOT%" --headless --path "%DIR%" -- --server --headless
