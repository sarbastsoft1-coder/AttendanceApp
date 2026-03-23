@echo off
setlocal
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0run_windows_app.ps1" %*
exit /b %errorlevel%
