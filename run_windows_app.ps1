param(
  [switch]$Rebuild,
  [string]$BackendUrl
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

function Test-BackendHealthy {
  param(
    [int]$Port
  )

  $previousPreference = $ErrorActionPreference
  $ErrorActionPreference = "Continue"
  try {
    $health = Invoke-RestMethod -Uri "http://127.0.0.1:$Port/health" -Method Get -TimeoutSec 2
    if ($health.status -ne "healthy") {
      return $false
    }

    $openApi = Invoke-RestMethod -Uri "http://127.0.0.1:$Port/openapi.json" -Method Get -TimeoutSec 2
    return (
      $openApi.info.title -eq "Recognition Based Automated Attendance System" -and
      $null -ne $openApi.paths."/api/auth/register" -and
      $null -ne $openApi.paths."/api/auth/login-json"
    )
  }
  catch {
    return $false
  }
  finally {
    $ErrorActionPreference = $previousPreference
  }
}

function Get-NormalizedBaseUrl {
  param(
    [string]$Url
  )

  return $Url.Trim().TrimEnd("/")
}

function Test-BackendHealthyUrl {
  param(
    [string]$BaseUrl
  )

  $normalizedUrl = Get-NormalizedBaseUrl -Url $BaseUrl
  if ([string]::IsNullOrWhiteSpace($normalizedUrl)) {
    return $false
  }

  $previousPreference = $ErrorActionPreference
  $ErrorActionPreference = "Continue"
  try {
    $health = Invoke-RestMethod -Uri "$normalizedUrl/health" -Method Get -TimeoutSec 5
    if ($health.status -ne "healthy") {
      return $false
    }

    $openApi = Invoke-RestMethod -Uri "$normalizedUrl/openapi.json" -Method Get -TimeoutSec 5
    return (
      $openApi.info.title -eq "Recognition Based Automated Attendance System" -and
      $null -ne $openApi.paths."/api/auth/register" -and
      $null -ne $openApi.paths."/api/auth/login-json"
    )
  }
  catch {
    return $false
  }
  finally {
    $ErrorActionPreference = $previousPreference
  }
}

function Test-PortListening {
  param(
    [int]$Port
  )

  return [bool](Get-NetTCPConnection -LocalPort $Port -ErrorAction SilentlyContinue | Select-Object -First 1)
}

function Get-BackendPortSelection {
  param(
    [int[]]$Candidates
  )

  foreach ($port in $Candidates) {
    if (Test-BackendHealthy -Port $port) {
      return @{
        Port = $port
        StartBackend = $false
      }
    }

    if (-not (Test-PortListening -Port $port)) {
      return @{
        Port = $port
        StartBackend = $true
      }
    }
  }

  throw "No usable backend port was found in: $($Candidates -join ', ')"
}

function Sync-DesktopAppBaseUrlPreference {
  param(
    [string]$BaseUrl
  )

  $prefsDir = Join-Path $env:APPDATA "com.example\recognition_based_automated_attendance_system"
  $prefsPath = Join-Path $prefsDir "shared_preferences.json"

  if (-not (Test-Path $prefsDir)) {
    New-Item -ItemType Directory -Path $prefsDir -Force | Out-Null
  }

  $prefsObject = $null
  if (Test-Path $prefsPath) {
    try {
      $raw = Get-Content -Path $prefsPath -Raw
      if (-not [string]::IsNullOrWhiteSpace($raw)) {
        $prefsObject = $raw | ConvertFrom-Json
      }
    }
    catch {
      Write-Warning "Could not parse shared preferences. Recreating $prefsPath"
    }
  }

  if ($null -eq $prefsObject) {
    $prefsObject = [pscustomobject]@{}
  }

  $prefsObject | Add-Member -NotePropertyName 'flutter.api_base_url' -NotePropertyValue $BaseUrl -Force
  $prefsObject | ConvertTo-Json -Compress | Set-Content -Path $prefsPath -Encoding UTF8
}

if ($Rebuild -or -not (Test-Path $exePath)) {
  if (-not (Test-Path $buildScript)) {
    throw "Build script not found at: $buildScript"
  }
  & $buildScript
}

$backendBaseUrl = $null
$startBackend = $false

if (-not [string]::IsNullOrWhiteSpace($BackendUrl)) {
  $backendBaseUrl = Get-NormalizedBaseUrl -Url $BackendUrl
  if (-not (Test-BackendHealthyUrl -BaseUrl $backendBaseUrl)) {
    throw "Backend URL is not healthy or is not this attendance API: $backendBaseUrl"
  }
  Write-Host "Using remote backend API at $backendBaseUrl"
}
else {
  if (-not (Test-Path $backendDir)) {
    throw "Backend folder not found at: $backendDir"
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
  $backendPortCandidates = @(8000, 8001, 8010, 8011)
  $backendSelection = Get-BackendPortSelection -Candidates $backendPortCandidates
  $backendPort = [int]$backendSelection.Port
  $startBackend = [bool]$backendSelection.StartBackend

  if ($startBackend) {
    Write-Host "Starting backend API on port $backendPort..."
    $backendProcess = Start-Process `
      -FilePath $pythonPath `
      -ArgumentList @("-X", "utf8", "-m", "uvicorn", "main:app", "--host", "127.0.0.1", "--port", "$backendPort") `
      -WorkingDirectory $backendDir `
      -RedirectStandardOutput $backendLog `
      -RedirectStandardError $backendErr `
      -PassThru
  }
  else {
    Write-Host "Using existing backend API on port $backendPort..."
  }
}

try {
  if ($null -eq $backendBaseUrl) {
    $backendReady = $false
    for ($i = 0; $i -lt 30; $i++) {
      Start-Sleep -Seconds 1

      if ($startBackend -and $backendProcess.HasExited) {
        throw "Backend exited early. Check logs: $backendLog and $backendErr"
      }

      try {
        $health = Invoke-RestMethod -Uri "http://127.0.0.1:$backendPort/health" -Method Get -TimeoutSec 2
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
      throw "Backend did not become healthy within 30 seconds on port $backendPort. Check: $backendErr"
    }

    $backendBaseUrl = "http://127.0.0.1:$backendPort"
  }

  Sync-DesktopAppBaseUrlPreference -BaseUrl $backendBaseUrl
  Write-Host "Using backend API URL $backendBaseUrl"

  Write-Host "Launching desktop app..."
  $appProcess = Start-Process -FilePath $exePath -PassThru
  Wait-Process -Id $appProcess.Id
}
finally {
  if ($startBackend -and (Get-Variable -Name "backendProcess" -ErrorAction SilentlyContinue) -and -not $backendProcess.HasExited) {
    Write-Host "Stopping backend..."
    Stop-Process -Id $backendProcess.Id -Force
  }
}
