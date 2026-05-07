# RustyCode Installer for Windows
$ErrorActionPreference = "Stop"

$Repo = "rustycode-ai/rustycode"
$Platform = "windows-x64"
$Ext = "zip"
$InstallDir = Join-Path $env:USERPROFILE ".local\bin"

Write-Host "RustyCode Installer" -ForegroundColor Cyan
Write-Host "==================="

# Get latest release
Write-Host "Fetching latest release..."
$Release = Invoke-RestMethod -Uri "https://api.github.com/repos/$Repo/releases/latest"
$Asset = $Release.assets | Where-Object { $_.name -like "*$Platform*$Ext" } | Select-Object -First 1

if (-not $Asset) {
    Write-Error "No $Platform binary found in latest release."
    Write-Host "Build from source: cargo install --git https://github.com/$Repo"
    exit 1
}

# Download
$TmpFile = Join-Path $env:TEMP "rustycode.zip"
Write-Host "Downloading $($Asset.name)..."
Invoke-WebRequest -Uri $Asset.browser_download_url -OutFile $TmpFile

# Extract
$TmpDir = Join-Path $env:TEMP "rustycode-install"
if (Test-Path $TmpDir) { Remove-Item $TmpDir -Recurse -Force }
New-Item -Path $TmpDir -ItemType Directory | Out-Null

Expand-Archive -Path $TmpFile -DestinationPath $TmpDir

# Find binary
$Binary = Get-ChildItem -Path $TmpDir -Recurse -Filter "rustycode-cli.exe" | Select-Object -First 1
if (-not $Binary) {
    $Binary = Get-ChildItem -Path $TmpDir -Reverise -Filter "rustycode.exe" | Select-Object -First 1
}

if (-not $Binary) {
    Write-Error "Binary not found in archive."
    exit 1
}

# Install
if (-not (Test-Path $InstallDir)) {
    New-Item -Path $InstallDir -ItemType Directory | Out-Null
}

$DestPath = Join-Path $InstallDir "rustycode.exe"
Copy-Item -Path $Binary.FullName -Destination $DestPath -Force

Write-Host ""
Write-Host "Installed to $DestPath" -ForegroundColor Green

# Check PATH
$PathDirs = $env:PATH -split ";"
if ($PathDirs -notcontains $InstallDir) {
    Write-Host ""
    Write-Host "Add to PATH (run in an admin PowerShell):" -ForegroundColor Yellow
    Write-Host "  [Environment]::SetEnvironmentVariable('PATH', `$env:PATH + ';$InstallDir', 'User')"
}

Write-Host ""
Write-Host "Run 'rustycode --help' to get started." -ForegroundColor Green

# Cleanup
Remove-Item $TmpFile -Force
Remove-Item $TmpDir -Recurse -Force
