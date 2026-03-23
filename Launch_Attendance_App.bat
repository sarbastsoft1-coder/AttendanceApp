@echo off
REM Attendance System - Main Launcher
REM Starts the backend then opens the desktop app

cd /d "C:\AttendanceApp"

REM Activate virtual environment and start backend silently
start "" /b cmd /c ".venv\Scripts\activate && python backend\main.py > backend\backend_launcher.log 2>&1"

REM Wait for backend to initialize
timeout /t 4 /nobreak > nul

REM Launch the Flutter app
start "" "recognition_based_automated_attendance_system\build\windows\x64\runner\Release\recognition_based_automated_attendance_system.exe"
