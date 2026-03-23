param(
  [switch]$Clean
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$projectRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$flutterProject = Join-Path $projectRoot "recognition_based_automated_attendance_system"
$pubspecPath = Join-Path $flutterProject "pubspec.yaml"

if (-not (Test-Path $pubspecPath)) {
  throw "Flutter project not found at: $flutterProject"
}

function Get-FreeDriveLetter {
  param(
    [string[]]$Candidates
  )

  foreach ($letter in $Candidates) {
    if (-not (Test-Path "$letter`:\")) {
      return $letter
    }
  }

  return $null
}

$driveCandidates = @("X", "Y", "Z", "W", "V", "U", "T")
$mountedDrive = $null
$buildProjectPath = $flutterProject
$didPush = $false

$freeLetter = Get-FreeDriveLetter -Candidates $driveCandidates
if ($freeLetter) {
  $mountedDrive = "$freeLetter`:"
  # Using absolute path to ensure robustness
  cmd /c "subst $mountedDrive `"$($flutterProject.ToUpper())`""
  if ($LASTEXITCODE -ne 0) {
    throw "Could not create subst drive at $mountedDrive"
  }
  $buildProjectPath = $mountedDrive
}
else {
  Write-Warning "No free drive letter found. Continuing without subst path shortening."
}

try {
  Push-Location $buildProjectPath
  $didPush = $true

  if ($Clean) {
    flutter clean
    if ($LASTEXITCODE -ne 0) {
      throw "flutter clean failed with exit code $LASTEXITCODE"
    }
  }

  flutter pub get
  if ($LASTEXITCODE -ne 0) {
    throw "flutter pub get failed with exit code $LASTEXITCODE"
  }

  flutter build windows
  if ($LASTEXITCODE -ne 0) {
    throw "flutter build windows failed with exit code $LASTEXITCODE"
  }
}
finally {
  if ($didPush) {
    Pop-Location
  }

  if ($mountedDrive) {
    cmd /c "subst $mountedDrive /d" | Out-Null
  }
}

$exePath = Join-Path $flutterProject "build\windows\x64\runner\Release\recognition_based_automated_attendance_system.exe"
if (-not (Test-Path $exePath)) {
  throw "Build finished but EXE was not found at: $exePath"
}

Write-Host "Windows build completed:"
Write-Host $exePath
