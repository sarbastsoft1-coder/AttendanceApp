param(
  [switch]$Rebuild
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$projectRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$backendDir = Join-Path $projectRoot "backend"
$flutterProject = Join-Path $projectRoot "recognition_based_automated_attendance_system"
$buildScript = Join-Path $projectRoot "build_windows_app.ps1"
$exePath = Join-Path $flutterProject "build\windows\x64\runner\Release\recognition_based_automated_attendance_system.exe"

function Test-PythonBackendStack {
  param(
    [string]$PythonExe
  )

  if (-not (Test-Path $PythonExe)) {
    return $false
  }

  $previousPreference = $ErrorActionPreference
  $ErrorActionPreference = "Continue"
  try {
    & $PythonExe -X utf8 -c "import uvicorn, fastapi, cv2, face_recognition" 1>$null 2>$null
    return ($LASTEXITCODE -eq 0)
  }
  finally {
    $ErrorActionPreference = $previousPreference
  }
}

if (-not (Test-Path $backendDir)) {
  throw "Backend folder not found at: $backendDir"
}

if ($Rebuild -or -not (Test-Path $exePath)) {
  if (-not (Test-Path $buildScript)) {
    throw "Build script not found at: $buildScript"
  }
  & $buildScript
}

$pythonCandidates = @(
  (Join-Path $projectRoot ".venv\Scripts\python.exe"),
  (Join-Path $backendDir "venv\Scripts\python.exe")
)

$pythonCmd = Get-Command python -ErrorAction SilentlyContinue
if ($pythonCmd) {
  $pythonCandidates += $pythonCmd.Source
}

$pythonPath = $null
foreach ($candidate in ($pythonCandidates | Where-Object { $_ } | Select-Object -Unique)) {
  if (Test-PythonBackendStack -PythonExe $candidate) {
    $pythonPath = $candidate
    break
  }
}

if (-not $pythonPath) {
  throw "No Python environment with required backend packages was found (uvicorn, fastapi, cv2, face_recognition)."
}

$backendLog = Join-Path $backendDir "backend_windows.log"
$backendErr = Join-Path $backendDir "backend_windows.err.log"

Write-Host "Starting backend API..."
$backendProcess = Start-Process `
  -FilePath $pythonPath `
  -ArgumentList @("-X", "utf8", "-m", "uvicorn", "main:app", "--host", "127.0.0.1", "--port", "8000") `
  -WorkingDirectory $backendDir `
  -RedirectStandardOutput $backendLog `
  -RedirectStandardError $backendErr `
  -PassThru

try {
  $backendReady = $false
  for ($i = 0; $i -lt 30; $i++) {
    Start-Sleep -Seconds 1

    if ($backendProcess.HasExited) {
      throw "Backend exited early. Check logs: $backendLog and $backendErr"
    }

    try {
      $health = Invoke-RestMethod -Uri "http://127.0.0.1:8000/health" -Method Get -TimeoutSec 2
      if ($health.status -eq "healthy") {
        $backendReady = $true
        break
      }
    }
    catch {
      # Keep waiting until backend is ready.
    }
  }

  if (-not $backendReady) {
    throw "Backend did not become healthy within 30 seconds. Check: $backendErr"
  }

  Write-Host "Launching desktop app..."
  $appProcess = Start-Process -FilePath $exePath -PassThru
  Wait-Process -Id $appProcess.Id
}
finally {
  if ($backendProcess -and -not $backendProcess.HasExited) {
    Write-Host "Stopping backend..."
    Stop-Process -Id $backendProcess.Id -Force
  }
}
