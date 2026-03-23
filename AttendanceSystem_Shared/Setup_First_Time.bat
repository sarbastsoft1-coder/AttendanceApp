@echo off
echo Setting up Attendance System Backend...
cd backend
python -m venv .venv
call .venv\Scripts\activate
pip install -r requirements.txt
echo Setup Complete!
pause
