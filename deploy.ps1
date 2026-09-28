param(
    [string]$Thumbprint = "FD10E795F1DC5045FA8448C6C8E99C59B127635F",
    [string]$TargetTriple = "",
    [switch]$SkipBuild,
    [switch]$SkipSign
)

$ErrorActionPreference = "Stop"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host " LLM Wiki Deploy & Build Script" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

# 1. Build the Tauri application (standalone binary only, omitting bundles/installers)
if (-not $SkipBuild) {
    if (-not $env:CARGO_BUILD_JOBS) {
        $env:CARGO_BUILD_JOBS = "4"
    }
    Remove-Item -Path "src-tauri\target\release\deps\*.rcgu.o" -Force -ErrorAction SilentlyContinue

    Write-Host "`n[1/2] Building Tauri application (npm run tauri build -- --no-bundle)..." -ForegroundColor Yellow
    if ($TargetTriple) {
        npm run tauri build -- --no-bundle --target $TargetTriple
    } else {
        npm run tauri build -- --no-bundle
    }
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Build failed with exit code $LASTEXITCODE"
        exit $LASTEXITCODE
    }
    Write-Host "Build completed successfully!" -ForegroundColor Green
} else {
    Write-Host "`n[1/2] Skipping build step (-SkipBuild requested)..." -ForegroundColor Yellow
}

# 2. Invoke sign.ps1 to copy binary to /dist and optionally sign
if (-not $SkipSign) {
    Write-Host "`n[2/2] Signing binary and packaging into /dist..." -ForegroundColor Yellow
    & ".\sign.ps1" -Thumbprint $Thumbprint -TargetTriple $TargetTriple
} else {
    Write-Host "`n[2/2] Packaging binary into /dist (-SkipSign requested)..." -ForegroundColor Yellow
    & ".\sign.ps1" -Thumbprint $Thumbprint -TargetTriple $TargetTriple -SkipSign
}

if ($LASTEXITCODE -eq 0 -or $?) {
    Write-Host "`nDeployment completed successfully! Artifact is in /dist" -ForegroundColor Green
} else {
    Write-Error "Deployment failed during packaging/signing step."
    exit $LASTEXITCODE
}
