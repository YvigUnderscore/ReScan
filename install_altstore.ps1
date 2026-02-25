#Requires -Version 5.1
<#
.SYNOPSIS
Installs AltServer and its dependencies (iTunes, iCloud) on Windows.
#>

$ErrorActionPreference = "Stop"

Write-Host "=============================================" -ForegroundColor Green
Write-Host "   DIET Capture AltStore Installer (Windows) " -ForegroundColor Green
Write-Host "=============================================" -ForegroundColor Green
Write-Host ""
Write-Host "This script will help you install AltServer and its Apple dependencies." -ForegroundColor Yellow
Write-Host "NOTE: You MUST use the direct download versions of iTunes and iCloud, NOT the Microsoft Store versions." -ForegroundColor Yellow
Write-Host ""

# 1. Open Dependency Downloads
Write-Host "Step 1: Downloading iTunes and iCloud (Direct versions)..." -ForegroundColor Cyan
Write-Host "Please install these if you haven't already. (Opening in your browser/downloader...)"
Start-Process "https://www.apple.com/itunes/download/win64"
Start-Process "https://updates.cdn-apple.com/2020/windows/001-39935-20200911-1A70AA56-F448-11EA-8CC0-99D41950005E/iCloudSetup.exe"

Write-Host ""
Write-Host "Please finish installing iTunes and iCloud, then press Enter to continue to AltServer..." -ForegroundColor Yellow
Read-Host

# 2. Download and Extract AltServer
$altStoreUrl = "https://cdn.altstore.io/file/altstore/altinstaller.zip"
$zipPath = "$env:TEMP\altinstaller.zip"
$extractPath = "$env:TEMP\AltInstaller"

Write-Host "Step 2: Downloading AltServer..." -ForegroundColor Cyan
Invoke-WebRequest -Uri $altStoreUrl -OutFile $zipPath

Write-Host "Extracting AltServer..." -ForegroundColor Cyan
if (Test-Path $extractPath) { Remove-Item -Path $extractPath -Recurse -Force }
Expand-Archive -Path $zipPath -DestinationPath $extractPath -Force

# 3. Run Setup
Write-Host "Step 3: Running AltServer Setup." -ForegroundColor Cyan
Write-Host "Please follow the standard installation wizard prompts." -ForegroundColor Yellow
Start-Process -FilePath "$extractPath\setup.exe" -Wait

# 4. Clean up
Remove-Item -Path $zipPath -Force
Remove-Item -Path $extractPath -Recurse -Force

Write-Host ""
Write-Host "=============================================" -ForegroundColor Green
Write-Host "               INSTALLATION COMPLETE         " -ForegroundColor Green
Write-Host "=============================================" -ForegroundColor Green
Write-Host "1. Launch AltServer from your Windows Start Menu."
Write-Host "2. Connect your iPhone via USB and unlock it."
Write-Host "3. Trust the computer on your iPhone if prompted."
Write-Host "4. Click the AltServer icon in your system tray (bottom right)."
Write-Host "5. Hold the Shift key, click the AltServer icon, and choose 'Sideload .ipa'."
Write-Host "6. Select the ReScan .ipa file to install it to your phone!"
Write-Host "=============================================" -ForegroundColor Green
Write-Host ""
Write-Host "Press any key to exit..."
$Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown") | Out-Null
