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

function Remove-WindowsBuildArtifacts {
  param(
    [string]$FlutterProjectPath
  )

  $pathsToRemove = @(
    (Join-Path $FlutterProjectPath "build\windows"),
    (Join-Path $FlutterProjectPath "windows\flutter\ephemeral")
  )

  foreach ($path in $pathsToRemove) {
    if (Test-Path $path) {
      Remove-Item -LiteralPath $path -Recurse -Force
    }
  }
}

function Get-NormalizedPath {
  param(
    [string]$Path
  )

  return ($Path.Replace("\", "/").TrimEnd("/").ToLowerInvariant())
}

function Test-WindowsBuildArtifactsNeedReset {
  param(
    [string]$FlutterProjectPath,
    [string]$ExpectedBuildProjectPath
  )

  $cmakeCachePath = Join-Path $FlutterProjectPath "build\windows\x64\CMakeCache.txt"
  if (-not (Test-Path $cmakeCachePath)) {
    return $false
  }

  $expectedBuildDir = Get-NormalizedPath -Path (Join-Path $ExpectedBuildProjectPath "build\windows\x64")
  foreach ($line in Get-Content -Path $cmakeCachePath) {
    if ($line -match '^# For build in directory:\s*(.+)$') {
      $actualBuildDir = Get-NormalizedPath -Path $Matches[1]
      return ($actualBuildDir -ne $expectedBuildDir)
    }
  }

  return $true
}

$driveCandidates = @("X", "Y", "Z", "W", "V", "U", "T")
$mountedDrive = $null
$buildProjectPath = $flutterProject
$mountRoot = $projectRoot
$didPush = $false

$freeLetter = Get-FreeDriveLetter -Candidates $driveCandidates
if ($freeLetter) {
  $mountedDrive = "$freeLetter`:"
  $resolvedMountRoot = (Resolve-Path $mountRoot).Path
  # Mount the parent directory instead of the Flutter project root. Building
  # from X:\ breaks Flutter's generated Windows env vars because PROJECT_DIR
  # ends with a bare drive-root slash.
  cmd /c "subst $mountedDrive `"$resolvedMountRoot`""
  if ($LASTEXITCODE -ne 0) {
    throw "Could not create subst drive at $mountedDrive"
  }
  $buildProjectPath = Join-Path $mountedDrive (Split-Path -Leaf $flutterProject)
}
else {
  Write-Warning "No free drive letter found. Continuing without subst path shortening."
}

try {
  # The Windows desktop build caches absolute paths in CMake. If the project was
  # previously built from a different path (for example C:\... instead of the
  # subst drive, or a different drive letter), reset the Windows build cache.
  if (Test-WindowsBuildArtifactsNeedReset -FlutterProjectPath $flutterProject -ExpectedBuildProjectPath $buildProjectPath) {
    Remove-WindowsBuildArtifacts -FlutterProjectPath $flutterProject
  }

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
