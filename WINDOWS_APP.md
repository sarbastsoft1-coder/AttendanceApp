# Windows Desktop App

This project now supports a Windows desktop build for the Flutter app, with the FastAPI backend started automatically.

## What was added

- `build_windows_app.ps1`: Builds the Flutter Windows EXE and auto-applies a path-length workaround.
- `run_windows_app.ps1`: Starts backend API on `127.0.0.1:8000`, waits for health, launches desktop app, then stops backend when app closes.
- `run_windows_app.bat`: Double-click launcher for Windows.

## Prerequisites

- Flutter installed and available in `PATH`
- Visual Studio 2022 with Desktop C++ workload (for Flutter Windows build)
- Python installed
- Backend dependencies installed (`backend/requirements.txt`)

## Build the Windows app

```powershell
.\build_windows_app.ps1 -Clean
```

Built EXE output:

`recognition_based_automated_attendance_system\build\windows\x64\runner\Release\recognition_based_automated_attendance_system.exe`

## Run as desktop app (backend + frontend)

PowerShell:

```powershell
.\run_windows_app.ps1
```

Or double-click:

`run_windows_app.bat`

Optional rebuild before run:

```powershell
.\run_windows_app.ps1 -Rebuild
```

## Notes

- API base URL is already set to `http://localhost:8000` in `recognition_based_automated_attendance_system/lib/config/api_config.dart`.
- Backend logs are written to:
  - `backend/backend_windows.log`
  - `backend/backend_windows.err.log`
