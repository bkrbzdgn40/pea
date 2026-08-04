param(
    [switch]$RunFullTests,
    [switch]$LaunchProfile,
    [string]$OutputPath = "performance_logs/market_template_profile_snapshot.json"
)

$ErrorActionPreference = "Stop"
$projectRoot = Split-Path -Parent $PSScriptRoot
Set-Location $projectRoot

if (-not (Test-Path "pubspec.yaml")) {
    throw "Run this script from the market-template repository."
}

flutter pub get
dart analyze
flutter test test/features/market

if ($RunFullTests) {
    flutter test
}

flutter build apk --profile

$apk = Get-Item "build/app/outputs/flutter-apk/app-profile.apk"
$marketAssets = Get-ChildItem "assets/market/products" -Filter "*.webp" -File
$assetBytes = ($marketAssets | Measure-Object -Property Length -Sum).Sum
if ($null -eq $assetBytes) {
    $assetBytes = 0
}

$gitCommit = "unknown"
try {
    $gitCommit = (git rev-parse HEAD).Trim()
} catch {
    $gitCommit = "unavailable"
}

$snapshot = [ordered]@{
    capturedAtUtc = [DateTime]::UtcNow.ToString("o")
    gitCommit = $gitCommit
    profileApkBytes = $apk.Length
    marketVisualAssetBytes = [int64]$assetBytes
    marketVisualAssetCount = $marketAssets.Count
    flutterMode = "profile"
    deviceMeasurements = [ordered]@{
        coldStartMedianMs = $null
        marketExitRetainedMemoryMb = $null
        liveUiFrameMedianMs = $null
        liveRasterFrameMedianMs = $null
        poseProcessingMedianMs = $null
        notes = "Fill from three comparable physical-device runs in DevTools."
    }
}

$outputFile = Join-Path $projectRoot $OutputPath
$outputDirectory = Split-Path -Parent $outputFile
New-Item -ItemType Directory -Path $outputDirectory -Force | Out-Null
$snapshot | ConvertTo-Json -Depth 5 | Set-Content -Path $outputFile -Encoding UTF8

Write-Host "Profile APK: $($apk.Length) bytes"
Write-Host "Market visuals: $assetBytes bytes across $($marketAssets.Count) files"
Write-Host "Snapshot: $outputFile"

if ($LaunchProfile) {
    flutter run --profile
}
