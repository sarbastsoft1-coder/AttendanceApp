@echo off
echo Starting Attendance System...
start /b cmd /c "cd backend && .venv\Scripts\activate && python main.py"
echo Waiting for backend to start...
timeout /t 5 /nobreak > nul
start "" "app\recognition_based_automated_attendance_system.exe"
echo App is running!
