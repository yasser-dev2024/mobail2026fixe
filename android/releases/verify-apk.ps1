param(
    [string]$ApkPath = (Join-Path $PSScriptRoot "Maintenance-Assistant-v1.0.3-universal.apk")
)

$ErrorActionPreference = "Stop"

$expectedPackage = "com.proshop.mobile_shop_pro"
$expectedVersionName = "1.0.3"
$expectedVersionCode = "4"
$expectedCertificate = "6401ff72d3ad598507fc773d328fbfc61ad9a0966d2e30ddb5e696c97e8eba47"
$requiredAbis = @("arm64-v8a", "armeabi-v7a", "x86", "x86_64")

if (-not (Test-Path -LiteralPath $ApkPath)) {
    throw "APK not found: $ApkPath"
}

$checksumPath = Join-Path $PSScriptRoot "SHA256SUMS.txt"
$expectedHash = ((Get-Content -Raw -LiteralPath $checksumPath) -split "\s+")[0].ToUpperInvariant()
$actualHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $ApkPath).Hash.ToUpperInvariant()
if ($actualHash -ne $expectedHash) {
    throw "SHA-256 mismatch. Expected $expectedHash but found $actualHash"
}

# Some Android SDK tools on Windows cannot open paths containing Arabic or
# invisible Unicode characters. Verify an identical temporary copy by its hash.
$temporaryDirectory = Join-Path $env:TEMP "MaintenanceAssistantApkVerification"
$toolApkPath = Join-Path $temporaryDirectory "app.apk"
New-Item -ItemType Directory -Force -Path $temporaryDirectory | Out-Null
Copy-Item -Force -LiteralPath $ApkPath -Destination $toolApkPath

$sdkRoot = if ($env:ANDROID_HOME) {
    $env:ANDROID_HOME
} elseif ($env:ANDROID_SDK_ROOT) {
    $env:ANDROID_SDK_ROOT
} else {
    Join-Path $env:LOCALAPPDATA "Android\Sdk"
}

$buildToolsRoot = Join-Path $sdkRoot "build-tools"
$buildTools = Get-ChildItem -Directory -LiteralPath $buildToolsRoot |
    Sort-Object { [version]$_.Name } -Descending |
    Select-Object -First 1
if ($null -eq $buildTools) {
    throw "Android build-tools were not found under $buildToolsRoot"
}

$aapt = Join-Path $buildTools.FullName "aapt.exe"
$apksigner = Join-Path $buildTools.FullName "apksigner.bat"
$zipalign = Join-Path $buildTools.FullName "zipalign.exe"

$androidStudioJdk = Join-Path ${env:ProgramFiles} "Android\Android Studio1\jbr"
if (Test-Path -LiteralPath (Join-Path $androidStudioJdk "bin\java.exe")) {
    $env:JAVA_HOME = $androidStudioJdk
} elseif (-not $env:JAVA_HOME -or -not (Test-Path -LiteralPath (Join-Path $env:JAVA_HOME "bin\java.exe"))) {
    throw "A working Java runtime was not found for apksigner"
}

$badging = (& $aapt dump badging $toolApkPath) -join "`n"
if ($LASTEXITCODE -ne 0) {
    throw "aapt could not read the APK"
}
if ($badging -notmatch "package: name='$([regex]::Escape($expectedPackage))'") {
    throw "Unexpected package name"
}
if ($badging -notmatch "versionCode='$expectedVersionCode'") {
    throw "Unexpected versionCode"
}
if ($badging -notmatch "versionName='$([regex]::Escape($expectedVersionName))'") {
    throw "Unexpected versionName"
}
if ($badging -notmatch "(?m)^application-label:'.+'$") {
    throw "The application label is missing"
}
foreach ($abi in $requiredAbis) {
    if ($badging -notmatch "'$([regex]::Escape($abi))'") {
        throw "Missing ABI: $abi"
    }
}

$signature = (& $apksigner verify --verbose --print-certs $toolApkPath) -join "`n"
if ($LASTEXITCODE -ne 0 -or $signature -notmatch "(?m)^Verifies$") {
    throw "APK signature verification failed"
}
if ($signature -notmatch "Verified using v2 scheme \(APK Signature Scheme v2\): true") {
    throw "APK Signature Scheme v2 is missing"
}
if ($signature -notmatch [regex]::Escape($expectedCertificate)) {
    throw "The APK is signed by a different update certificate"
}

$manifest = (& $aapt dump xmltree $toolApkPath AndroidManifest.xml) -join "`n"
if ($LASTEXITCODE -ne 0) {
    throw "AndroidManifest.xml could not be inspected"
}
if ($manifest -match "android:debuggable.*0xffffffff") {
    throw "The APK is debuggable and must not be published"
}
if ($manifest -notmatch "android:allowBackup.*0x0") {
    throw "Android backups must be disabled for customer data"
}
if ($manifest -notmatch "android:usesCleartextTraffic.*0x0") {
    throw "Cleartext HTTP traffic must be disabled"
}
if ($manifest -notmatch [regex]::Escape("com.proshop.mobile_shop_pro.StrongAlertActivity")) {
    throw "The native full-screen alert activity is missing"
}
if ($manifest -notmatch "android:showWhenLocked.*0xffffffff") {
    throw "The alert activity must remain visible on the lock screen"
}
if ($manifest -notmatch "android:turnScreenOn.*0xffffffff") {
    throw "The alert activity must wake the screen"
}

$permissions = (& $aapt dump permissions $toolApkPath) -join "`n"
foreach ($permission in @(
    "android.permission.POST_NOTIFICATIONS",
    "android.permission.SCHEDULE_EXACT_ALARM",
    "android.permission.USE_FULL_SCREEN_INTENT",
    "android.permission.WAKE_LOCK"
)) {
    if ($permissions -notmatch [regex]::Escape($permission)) {
        throw "Required alert permission is missing: $permission"
    }
}

# Verify the release binary itself contains the restored full-screen path and
# the device-data payload. This prevents publishing a stale APK from the site.
Add-Type -AssemblyName System.IO.Compression.FileSystem
$archive = [System.IO.Compression.ZipFile]::OpenRead($toolApkPath)
try {
    $requiredDexMarkers = @(
        "StrongAlertActivity",
        "setFullScreenIntent",
        "strong_alert_devices",
        "fullScreenAlertsGranted",
        "canUseFullScreenIntent"
    )
    $foundDexMarkers = @{}
    foreach ($marker in $requiredDexMarkers) {
        $foundDexMarkers[$marker] = $false
    }
    foreach ($entry in $archive.Entries | Where-Object { $_.FullName -match '^classes\d*\.dex$' }) {
        $entryStream = $entry.Open()
        try {
            $memory = New-Object System.IO.MemoryStream
            $entryStream.CopyTo($memory)
            $dexText = [System.Text.Encoding]::ASCII.GetString($memory.ToArray())
            foreach ($marker in $requiredDexMarkers) {
                if ($dexText.Contains($marker)) {
                    $foundDexMarkers[$marker] = $true
                }
            }
        } finally {
            $entryStream.Dispose()
        }
    }
    foreach ($marker in $requiredDexMarkers) {
        if (-not $foundDexMarkers[$marker]) {
            throw "Required alert feature is missing from the APK: $marker"
        }
    }
} finally {
    $archive.Dispose()
}

& $zipalign -c 4 $toolApkPath | Out-Null
if ($LASTEXITCODE -ne 0) {
    throw "APK zip alignment verification failed"
}

$size = (Get-Item -LiteralPath $ApkPath).Length
if ($size -lt 10MB) {
    throw "APK size is unexpectedly small: $size bytes"
}

Write-Output "APK verification passed"
Write-Output "Path: $ApkPath"
Write-Output "Size: $size bytes"
Write-Output "SHA-256: $actualHash"
Write-Output "Package: $expectedPackage"
Write-Output "Version: $expectedVersionName ($expectedVersionCode)"
Write-Output "Certificate SHA-256: $expectedCertificate"
Write-Output "ABIs: $($requiredAbis -join ', ')"

Remove-Item -Force -LiteralPath $toolApkPath
Remove-Item -Force -LiteralPath $temporaryDirectory
