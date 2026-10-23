@echo off
cd /d "%~dp0"
echo Launching Godot Editor...
if exist ".\.tools\godot\godot.exe" (
    start "" ".\.tools\godot\godot.exe" -e --path "%~dp0"
) else (
    godot -e --path "%~dp0"
)
