@echo off
setlocal
cd /d "%~dp0"
echo Launching Godot Editor...
if exist ".tools\godot\godot.exe" (
    start "" ".tools\godot\godot.exe" -e --path .
) else (
    start "" godot -e --path .
)
