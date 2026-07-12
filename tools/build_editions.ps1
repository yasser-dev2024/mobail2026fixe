param(
  [ValidateSet('Windows', 'Mac', 'Tablet', 'AppleBusinessSuite')]
  [string]$Edition = 'Windows'
)

$ErrorActionPreference = 'Stop'
$ProjectRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
$BuildsRoot = Join-Path $ProjectRoot 'Builds'

function New-CleanDirectory {
  param([string]$Path)
  if (!(Test-Path -LiteralPath $Path)) {
    New-Item -ItemType Directory -Path $Path | Out-Null
  }
}

function Copy-ProjectToAsciiStage {
  $stage = Join-Path $env:TEMP ("proshop_build_" + [Guid]::NewGuid().ToString('N'))
  New-Item -ItemType Directory -Path $stage | Out-Null
  robocopy $ProjectRoot $stage /E /XD build .dart_tool dist Builds .idea ephemeral .plugin_symlinks | Out-Null
  if ($LASTEXITCODE -gt 7) {
    throw "Failed to copy project to staging folder. Robocopy exit code: $LASTEXITCODE"
  }
  return $stage
}

function Build-WindowsEdition {
  $stage = Copy-ProjectToAsciiStage
  try {
    Push-Location $stage
    flutter pub get
    flutter build windows
    Pop-Location

    $source = Join-Path $stage 'build\windows\x64\runner\Release'
    $target = Join-Path $BuildsRoot 'Windows_Edition\package'
    New-CleanDirectory $target
    robocopy $source $target /E | Out-Null
    if ($LASTEXITCODE -gt 7) {
      throw "Failed to copy Windows package. Robocopy exit code: $LASTEXITCODE"
    }

    & (Join-Path $PSScriptRoot 'generate_integrity_manifest.ps1') -PackagePath $target
    Write-Host "Windows Edition package ready: $target"
  } finally {
    Pop-Location -ErrorAction SilentlyContinue
    if ($stage -and (Test-Path -LiteralPath $stage)) {
      Remove-Item -LiteralPath $stage -Recurse -Force
    }
  }
}

function Build-MacEdition {
  if (-not [System.Runtime.InteropServices.RuntimeInformation]::IsOSPlatform([System.Runtime.InteropServices.OSPlatform]::OSX)) {
    throw "Mac Edition must be built on macOS with Xcode installed."
  }

  Push-Location $ProjectRoot
  flutter pub get
  flutter build macos
  Pop-Location

  $source = Join-Path $ProjectRoot 'build\macos\Build\Products\Release'
  $target = Join-Path $BuildsRoot 'Mac_Edition\package'
  New-CleanDirectory $target
  Copy-Item -LiteralPath (Join-Path $source '*') -Destination $target -Recurse -Force
  & (Join-Path $PSScriptRoot 'generate_integrity_manifest.ps1') -PackagePath $target
  Write-Host "Mac Edition package ready: $target"
}

function Build-AppleBusinessSuite {
  Build-WindowsEdition

  if ([System.Runtime.InteropServices.RuntimeInformation]::IsOSPlatform([System.Runtime.InteropServices.OSPlatform]::OSX)) {
    Build-MacEdition
    Push-Location $ProjectRoot
    flutter build ios --release --no-codesign
    Pop-Location
    Write-Host "iPadOS build created. Sign/archive with Xcode for distribution."
  } else {
    Write-Warning "macOS and iPadOS builds require macOS with Xcode. Windows package was built; finish Apple targets on a Mac."
  }
}

function Build-TabletEdition {
  & (Join-Path $PSScriptRoot 'build_android_apk.ps1')
}

switch ($Edition) {
  'Windows' { Build-WindowsEdition }
  'Mac' { Build-MacEdition }
  'Tablet' { Build-TabletEdition }
  'AppleBusinessSuite' { Build-AppleBusinessSuite }
}
