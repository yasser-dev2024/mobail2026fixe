param(
  [Parameter(Mandatory = $true)]
  [string]$PackagePath
)

$ErrorActionPreference = 'Stop'
$root = (Resolve-Path -LiteralPath $PackagePath).Path
$rootWithSeparator = $root
if (-not $rootWithSeparator.EndsWith([System.IO.Path]::DirectorySeparatorChar)) {
  $rootWithSeparator += [System.IO.Path]::DirectorySeparatorChar
}
$manifestPath = Join-Path $root 'integrity_manifest.json'
$files = @{}

Get-ChildItem -LiteralPath $root -Recurse -File |
  Where-Object {
    $_.Name -ne 'integrity_manifest.json'
  } |
  ForEach-Object {
    $relative = $_.FullName.Substring($rootWithSeparator.Length)
    $hash = (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
    $files[$relative.Replace('\', '/')] = $hash
  }

$manifest = [ordered]@{
  generated_at = (Get-Date).ToString('o')
  algorithm = 'SHA256'
  files = $files
}

$manifest | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $manifestPath -Encoding UTF8
Write-Host "Integrity manifest created: $manifestPath"
