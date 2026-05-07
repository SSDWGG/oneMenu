<#
.SYNOPSIS
    Build and package oneMenu for Windows.
.DESCRIPTION
    - Restores NuGet packages
    - Builds in Release mode
    - Runs unit tests
    - Publishes as self-contained win-x64
    - Creates a zip package for distribution
.PARAMETER OutputDir
    Directory for the final zip artifact. Default: .\dist
.PARAMETER Version
    Version tag to embed. Defaults to reading from git describe.
.EXAMPLE
    .\publish.ps1
    .\publish.ps1 -OutputDir ..\dist -Version 0.2.0
#>

param(
    [string]$OutputDir = "$PSScriptRoot\dist",
    [string]$Version = ""
)

$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot

# Resolve version
if (-not $Version) {
    try {
        $Version = git describe --tags --always 2>$null
    } catch {
        $Version = "0.2.0-dev"
    }
}
Write-Host "=== oneMenu Windows Build v$Version ===" -ForegroundColor Cyan

# Clean
Write-Host "`n[1/4] Cleaning..." -ForegroundColor Yellow
Remove-Item -Recurse -Force $OutputDir -ErrorAction SilentlyContinue
dotnet clean -c Release --nologo 2>$null

# Restore
Write-Host "`n[2/4] Restoring packages..." -ForegroundColor Yellow
dotnet restore --nologo

# Build & Test
Write-Host "`n[3/4] Building and testing..." -ForegroundColor Yellow
dotnet build -c Release --nologo
dotnet test -c Release --nologo --no-build

# Publish self-contained
Write-Host "`n[4/4] Publishing self-contained win-x64..." -ForegroundColor Yellow
$publishDir = "$OutputDir\publish"

dotnet publish OneMenu.App\OneMenu.App.csproj `
    -c Release `
    -r win-x64 `
    --self-contained true `
    -p:PublishSingleFile=false `
    -p:IncludeNativeLibrariesForSelfExtract=true `
    --nologo `
    -o $publishDir

# Package as zip
Write-Host "`nPackaging..." -ForegroundColor Yellow
$zipName = "oneMenu-windows-$Version.zip"
$zipPath = "$OutputDir\$zipName"

if (Test-Path $zipPath) { Remove-Item $zipPath }
Compress-Archive -Path "$publishDir\*" -DestinationPath $zipPath

# Report
$publishSize = "{0:N1} MB" -f ((Get-ChildItem -Recurse $publishDir | Measure-Object Length -Sum).Sum / 1MB)
$zipSize = "{0:N1} MB" -f ((Get-Item $zipPath).Length / 1MB)

Write-Host "`n=== Done ===" -ForegroundColor Green
Write-Host "  Publish dir : $publishDir  ($publishSize)"
Write-Host "  Zip package : $zipPath  ($zipSize)"
Write-Host "  Run         : $publishDir\OneMenu.App.exe" -ForegroundColor Cyan
