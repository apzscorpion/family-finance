# ==============================================================================
# 🚀 Automated Release & README Update Script for Family Spend Tracker
# Usage: powershell -ExecutionPolicy Bypass -File scripts/update_release.ps1
# ==============================================================================

$ErrorActionPreference = "Stop"

# Set root directory to repository root
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$RepoRoot = Resolve-Path "$ScriptDir\.."
Set-Location $RepoRoot

Write-Host "🔍 Reading current version from mobile/pubspec.yaml..." -ForegroundColor Cyan

# 1. Parse Version from pubspec.yaml
$PubspecPath = Join-Path $RepoRoot "mobile\pubspec.yaml"
$PubspecContent = Get-Content $PubspecPath -Raw

if ($PubspecContent -match 'version:\s*([0-9]+\.[0-9]+\.[0-9]+)\+?([0-9]*)') {
    $Version = $Matches[1]
    $BuildNum = $Matches[2]
    Write-Host "📌 Current Version: v$Version (Build $BuildNum)" -ForegroundColor Green
} else {
    Write-Error "❌ Could not parse version string from mobile/pubspec.yaml"
    exit 1
}

# 2. Build Release APK via Flutter
Write-Host "📦 Building Flutter Release APK..." -ForegroundColor Cyan
Set-Location (Join-Path $RepoRoot "mobile")
$env:PATH = "$env:PATH;C:\src\flutter\bin"
flutter build apk --release
Set-Location $RepoRoot

$BuiltApk = Join-Path $RepoRoot "mobile\build\app\outputs\flutter-apk\app-release.apk"
if (-not (Test-Path $BuiltApk)) {
    Write-Error "❌ Build failed! $BuiltApk not found."
    exit 1
}

# 3. Clean releases directory & copy latest APK
Write-Host "🧹 Cleaning old APKs in releases/ folder..." -ForegroundColor Yellow
$ReleasesDir = Join-Path $RepoRoot "releases"
if (-not (Test-Path $ReleasesDir)) {
    New-Item -ItemType Directory -Path $ReleasesDir | Out-Null
}

# Remove any old versioned APK files
Get-ChildItem -Path $ReleasesDir -Filter "*.apk" | Remove-Item -Force

# Copy latest APK file as FamilySpendTracker-latest.apk
$TargetApk = Join-Path $ReleasesDir "FamilySpendTracker-latest.apk"
Copy-Item -Path $BuiltApk -Destination $TargetApk -Force
Write-Host "✅ Mapped latest build to $TargetApk" -ForegroundColor Green

# 4. Auto-update README.md with Version Badge & Download Link
Write-Host "📝 Auto-updating README.md..." -ForegroundColor Cyan
$ReadmePath = Join-Path $RepoRoot "README.md"
$ReadmeContent = Get-Content $ReadmePath -Raw

# Replace badge version string
$ReadmeContent = $ReadmeContent -replace '⚡_Download_Android_APK-v[0-9]+\.[0-9]+\.[0-9]+', "⚡_Download_Android_APK-v$Version"

Set-Content -Path $ReadmePath -Value $ReadmeContent -NoNewline
Write-Host "✅ README.md updated with badge v$Version" -ForegroundColor Green

# 5. Git Commit & Push Tag
Write-Host "📤 Committing and pushing release v$Version to GitHub..." -ForegroundColor Cyan
$commitMsg = "Release v${Version}: Map latest APK and update README"
$tagName = "v${Version}"
git add .
git commit -m $commitMsg
git tag -f $tagName
git push origin main --force
git push origin $tagName --force

Write-Host "🎉 Release v$Version successfully built, mapped to latest.apk, and pushed to GitHub!" -ForegroundColor Green

