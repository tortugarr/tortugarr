$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $MyInvocation.MyCommand.Path

function Get-FlutterCommand {
  if ($env:FLUTTER_BIN -and (Test-Path $env:FLUTTER_BIN)) {
    return $env:FLUTTER_BIN
  }

  $candidate = "C:\flutter\bin\flutter.bat"
  if (Test-Path $candidate) { return $candidate }

  $flutterCmd = Get-Command flutter -ErrorAction SilentlyContinue
  if ($flutterCmd) { return $flutterCmd.Source }

  throw "Flutter not found. Install Flutter, add it to PATH, or set FLUTTER_BIN to the full flutter executable path."
}

function Get-AppVersion {
  $pubspecPath = Join-Path $repoRoot "pubspec.yaml"
  if (-not (Test-Path $pubspecPath)) {
    throw "pubspec.yaml not found at $pubspecPath"
  }

  $versionLine = Get-Content $pubspecPath | Where-Object { $_ -match '^version\s*:\s*' } | Select-Object -First 1
  if (-not $versionLine) {
    throw "Could not find version in pubspec.yaml"
  }

  $fullVersion = ($versionLine -split ':', 2)[1].Trim()
  $appVersion = ($fullVersion -split '\+', 2)[0].Trim()
  if ([string]::IsNullOrWhiteSpace($appVersion)) {
    throw "Invalid version value in pubspec.yaml: $fullVersion"
  }

  return $appVersion
}

$flutterExe = Get-FlutterCommand
$appVersion = Get-AppVersion
$apkSource = Join-Path $repoRoot "build\app\outputs\flutter-apk\app-androidTv-release.apk"
$apkOutput = Join-Path $repoRoot "Tortugarr_Android_v$appVersion.apk"
$checkerScript = Join-Path $repoRoot "scripts\check-android-16kb-pages.sh"

Push-Location $repoRoot
try {
  Write-Host "Tortugarr version: $appVersion"

  Write-Host "Cleaning previous Flutter outputs..."
  & $flutterExe clean
  if ($LASTEXITCODE -ne 0) {
    throw "flutter clean failed with exit code $LASTEXITCODE"
  }

  Write-Host "Resolving Dart and Flutter packages..."
  & $flutterExe pub get
  if ($LASTEXITCODE -ne 0) {
    throw "flutter pub get failed with exit code $LASTEXITCODE"
  }

  Write-Host "Building Tortugarr Android TV release APK (armeabi-v7a)..."
  $maxAttempts = 3
  $attempt = 1
  $buildSuccess = $false

  while (-not $buildSuccess -and $attempt -le $maxAttempts) {
    & $flutterExe build apk --release --flavor androidTv --target-platform android-arm
    if ($LASTEXITCODE -eq 0) {
      $buildSuccess = $true
    } else {
      if ($attempt -lt $maxAttempts) {
        Write-Host "Build failed (attempt $attempt/$maxAttempts); clearing pdfium cache and retrying..."
        # Clear pdfium cache which sometimes has corrupted downloads
        $pdfiumCachePaths = @(
          (Join-Path $repoRoot "build\android\*\release\pdfium"),
          (Join-Path $repoRoot "build\android\*\release\.lib\*")
        )
        foreach ($path in $pdfiumCachePaths) {
          Get-ChildItem -Path $path -ErrorAction SilentlyContinue | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
        }
        Start-Sleep -Seconds ($attempt * 10)
      }
      $attempt++
    }
  }

  if (-not $buildSuccess) {
    throw "flutter build apk failed after $maxAttempts attempts"
  }

  if (-not (Test-Path $apkSource)) {
    throw "APK not found at expected path: $apkSource"
  }

  Copy-Item -Path $apkSource -Destination $apkOutput -Force

  if (Test-Path $checkerScript) {
    $bashCmd = Get-Command bash -ErrorAction SilentlyContinue
    if ($bashCmd) {
      Write-Host "Running 16 KB page-size compatibility check on APK..."
      & $bashCmd.Source $checkerScript $apkSource
      if ($LASTEXITCODE -ne 0) {
        throw "16 KB page-size compatibility check failed with exit code $LASTEXITCODE"
      }
    }
    else {
      Write-Warning "bash not found; skipping 16 KB page-size compatibility check"
    }
  }
  else {
    Write-Warning "16 KB checker script not found at $checkerScript"
  }

  Write-Host ""
  Write-Host "APK created:" $apkSource
  Write-Host "APK copied to root:" $apkOutput
}
finally {
  Pop-Location
}
