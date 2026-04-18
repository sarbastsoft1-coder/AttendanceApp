@echo off
setlocal
call "%~dp0run_windows_app.bat" %*
exit /b %errorlevel%
