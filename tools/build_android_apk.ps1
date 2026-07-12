param(
  [string]$OutputName = 'ProShop-Tablet-Android.apk'
)

$ErrorActionPreference = 'Stop'
$ProjectRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
$Target = Join-Path $ProjectRoot 'Builds\Tablet_Edition\package'

function Copy-ProjectToAsciiStage {
  $stage = Join-Path $env:TEMP ("proshop_android_build_" + [Guid]::NewGuid().ToString('N'))
  New-Item -ItemType Directory -Path $stage | Out-Null
  robocopy $ProjectRoot $stage /E /XD build .dart_tool dist Builds .idea ephemeral .plugin_symlinks | Out-Null
  if ($LASTEXITCODE -gt 7) {
    throw "Failed to copy project to staging folder. Robocopy exit code: $LASTEXITCODE"
  }
  return $stage
}

if (!(Test-Path -LiteralPath $Target)) {
  New-Item -ItemType Directory -Path $Target | Out-Null
}

$stage = Copy-ProjectToAsciiStage

try {
  Push-Location $stage
  try {
    flutter pub get
    flutter build apk --release
  } finally {
    Pop-Location -ErrorAction SilentlyContinue
  }

  $SourceApk = Join-Path $stage 'build\app\outputs\flutter-apk\app-release.apk'
  if (!(Test-Path -LiteralPath $SourceApk)) {
    throw "Android APK was not created at $SourceApk"
  }

  $OutputPath = Join-Path $Target $OutputName
  Copy-Item -LiteralPath $SourceApk -Destination $OutputPath -Force

  & (Join-Path $PSScriptRoot 'generate_integrity_manifest.ps1') -PackagePath $Target

  Write-Host "Tablet Edition APK ready: $OutputPath"
} finally {
  if ($stage -and (Test-Path -LiteralPath $stage)) {
    Remove-Item -LiteralPath $stage -Recurse -Force
  }
}
