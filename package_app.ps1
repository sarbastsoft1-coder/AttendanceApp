# Package Attendance System for Sharing
# Run this from the project root: .\package_app.ps1

$ErrorActionPreference = "Stop"

$projectRoot = Get-Location
$flutterDir = Join-Path $projectRoot "recognition_based_automated_attendance_system"
$backendDir = Join-Path $projectRoot "backend"
$distDir = Join-Path $projectRoot "AttendanceSystem_Shared"

# List of processes that might lock the build folder
$lockedProcesses = @("recognition_based_automated_attendance_system", "dart", "flutter")

Write-Host "--- 0. Checking for locked files ---" -ForegroundColor Cyan
foreach ($proc in $lockedProcesses) {
    if (Get-Process -Name $proc -ErrorAction SilentlyContinue) {
        Write-Host "Closing running $proc process..." -ForegroundColor Yellow
        Stop-Process -Name $proc -Force -ErrorAction SilentlyContinue
    }
}

# Cleanup any stale drive mappings from previous runs
Write-Host "--- Clean up stale drive mappings ---" -ForegroundColor Gray
cmd /c "subst Z: /d" 2>$null
cmd /c "subst Y: /d" 2>$null
cmd /c "subst X: /d" 2>$null

Write-Host "--- 1. Cleaning and Building Flutter Windows App ---" -ForegroundColor Cyan

try {
    Set-Location $flutterDir
    
    Write-Host "Running flutter clean..."
    flutter clean
    
    Write-Host "Running flutter pub get..."
    flutter pub get
    
    Write-Host "Building Windows application (Release)..."
    flutter build windows --release
}
catch {
    Write-Error "Build failed: $_"
    throw
}
finally {
    Set-Location $projectRoot
}

Write-Host "--- 2. Creating Distribution Folder ---" -ForegroundColor Cyan
if (Test-Path $distDir) { Remove-Item -Recurse -Force $distDir }
New-Item -ItemType Directory -Path $distDir
New-Item -ItemType Directory -Path (Join-Path $distDir "app")
New-Item -ItemType Directory -Path (Join-Path $distDir "backend")

Write-Host "--- 3. Copying Flutter Files ---" -ForegroundColor Cyan
$flutterBuildPath = Join-Path $flutterDir "build\windows\x64\runner\Release\*"
if (-not (Test-Path (Split-Path $flutterBuildPath))) {
    throw "Build failed: Could not find Release folder at $(Split-Path $flutterBuildPath). Ensure Visual Studio 'Desktop development with C++' is installed."
}
Copy-Item -Path $flutterBuildPath -Destination (Join-Path $distDir "app") -Recurse

Write-Host "--- 4. Copying Backend Files ---" -ForegroundColor Cyan
$excludeList = @("*.log", "attendance.db", "__pycache__", ".venv", ".env")
Get-ChildItem -Path $backendDir -Exclude $excludeList | Copy-Item -Destination (Join-Path $distDir "backend") -Recurse

Write-Host "--- 5. Creating Setup and Launcher Scripts ---" -ForegroundColor Cyan

$setupBat = @"
@echo off
echo Setting up Attendance System Backend...
cd backend
python -m venv .venv
call .venv\Scripts\activate
pip install -r requirements.txt
echo Setup Complete!
pause
"@
$setupBat | Out-File -FilePath (Join-Path $distDir "Setup_First_Time.bat") -Encoding ascii

$launcherBat = @"
@echo off
echo Starting Attendance System...
start /b cmd /c "cd backend && .venv\Scripts\activate && python main.py"
echo Waiting for backend to start...
timeout /t 5 /nobreak > nul
start "" "app\recognition_based_automated_attendance_system.exe"
echo App is running!
"@
$launcherBat | Out-File -FilePath (Join-Path $distDir "Start_Project.bat") -Encoding ascii

$readme = @"
# Attendance System - Installation
1. Install Python 3.10+ (and add to PATH)
2. Run 'Setup_First_Time.bat' (Wait for it to finish)
3. Run 'Start_Project.bat' to start the app.
"@
$readme | Out-File -FilePath (Join-Path $distDir "README.txt") -Encoding ascii

Write-Host "--- SUCCESS! ---" -ForegroundColor Green
Write-Host "Your shareable folder is ready at: $distDir"
Set-Location $projectRoot
