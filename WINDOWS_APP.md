# Windows Desktop App

This project now supports a Windows desktop build for the Flutter app, with the FastAPI backend started automatically.

## What was added

- `build_windows_app.ps1`: Builds the Flutter Windows EXE and auto-applies a path-length workaround.
- `run_windows_app.ps1`: Starts or reuses the attendance backend on the first healthy local port from `8000`, `8001`, `8010`, or `8011`, syncs that URL into the desktop app preferences, launches the app, then stops the backend it started when the app closes.
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

- The desktop app now validates the saved backend URL against the attendance API before using it.
- If another service is already using `8000`, the launcher will fall back to another healthy attendance backend port and update the saved desktop preference automatically.
- Backend logs are written to:
  - `backend/backend_windows.log`
  - `backend/backend_windows.err.log`
