# setup.ps1 - Bootstrap script for Godot 4.3 (Windows)
# Safe, standalone, zero-installation setup for all developers.

$ErrorActionPreference = "Stop"

$GODOT_VERSION = "4.3-stable"
$DOWNLOAD_URL = "https://github.com/godotengine/godot/releases/download/$GODOT_VERSION/Godot_v$GODOT_VERSION`_win64.exe.zip"
$PROJECT_ROOT = $PSScriptRoot
$TOOLS_DIR = Join-Path $PROJECT_ROOT ".tools"
$GODOT_DIR = Join-Path $TOOLS_DIR "godot"
$GODOT_EXE = Join-Path $GODOT_DIR "godot.exe"
$ORIGINAL_EXE = Join-Path $GODOT_DIR "Godot_v4.3-stable_win64.exe"
$CONSOLE_EXE = Join-Path $GODOT_DIR "Godot_v4.3-stable_win64_console.exe"

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host " Project Setup: It's a Feature, Not a Bug (Godot 4.3)" -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan

# 1. Check if Godot is already present in PATH
$systemGodot = Get-Command godot -ErrorAction SilentlyContinue
if ($systemGodot) {
    Write-Host "[OK] Found system Godot at: $($systemGodot.Source)" -ForegroundColor Green
    $TARGET_GODOT = "godot"
} elseif (Test-Path $GODOT_EXE) {
    Write-Host "[OK] Found local portable Godot at: $GODOT_EXE" -ForegroundColor Green
    $TARGET_GODOT = $GODOT_EXE
} else {
    Write-Host "[*] Godot 4.3 not found on system. Downloading portable version (~57 MB)..." -ForegroundColor Yellow
    
    if (-not (Test-Path $GODOT_DIR)) {
        New-Item -ItemType Directory -Force -Path $GODOT_DIR | Out-Null
    }

    $zipPath = Join-Path $TOOLS_DIR "godot_temp.zip"

    # Download with progress using curl.exe if available, otherwise Invoke-WebRequest
    $curlCmd = Get-Command curl.exe -ErrorAction SilentlyContinue
    if ($curlCmd) {
        Write-Host "Downloading via curl..." -ForegroundColor Gray
        & curl.exe -L --fail --progress-bar -o $zipPath $DOWNLOAD_URL
    } else {
        Write-Host "Downloading via PowerShell..." -ForegroundColor Gray
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        Invoke-WebRequest -Uri $DOWNLOAD_URL -OutFile $zipPath
    }

    Write-Host "[*] Extracting Godot to .tools/godot/..." -ForegroundColor Yellow
    Expand-Archive -Path $zipPath -DestinationPath $GODOT_DIR -Force
    Remove-Item -Path $zipPath -Force

    # Ensure Godot_v4.3-stable_win64.exe exists and godot.exe is created for easy reference
    if (Test-Path $ORIGINAL_EXE) {
        Copy-Item -Path $ORIGINAL_EXE -Destination $GODOT_EXE -Force
    }

    if (Test-Path $GODOT_EXE) {
        Write-Host "[OK] Successfully configured Godot 4.3 at $GODOT_EXE" -ForegroundColor Green
        $TARGET_GODOT = $GODOT_EXE
    } else {
        Write-Error "Failed to locate extracted Godot executable."
        exit 1
    }
}

# 2. Create open_project.bat convenience launcher in project root
$launcherBat = Join-Path $PROJECT_ROOT "open_project.bat"
$relativeExePath = if ($TARGET_GODOT -eq "godot") { "godot" } else { ".tools\godot\godot.exe" }

$lines = @(
    "@echo off",
    "setlocal",
    'cd /d "%~dp0"',
    "echo Launching Godot Editor...",
    "if exist `"$relativeExePath`" (",
    "    start `"`" `"$relativeExePath`" -e --path .",
    ") else (",
    "    start `"`" godot -e --path .",
    ")"
)
[System.IO.File]::WriteAllLines($launcherBat, $lines, [System.Text.Encoding]::ASCII)
Write-Host "[OK] Created launcher shortcut: open_project.bat (double-click to open editor)" -ForegroundColor Green

# 3. Print summary and IDE instructions
Write-Host "`nEnvironment is ready!" -ForegroundColor Cyan
Write-Host "----------------------------------------------------------"
Write-Host "You can develop using ANY editor you prefer:"
Write-Host " - Built-in Godot Editor: Double-click 'open_project.bat' to launch"
Write-Host " - Antigravity IDE / VS Code / Cursor: Edit GDScript files directly"
Write-Host "   Godot automatically starts an LSP on port 6005 when the editor is open"
Write-Host "----------------------------------------------------------"
