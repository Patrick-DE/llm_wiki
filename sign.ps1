param(
    [string]$Thumbprint = "FD10E795F1DC5045FA8448C6C8E99C59B127635F",
    [string]$TargetTriple = ""
)

# Cargo writes to target\release for the host triple, but target\<triple>\release
# when the build was invoked with an explicit --target.
$releaseDir = if ($TargetTriple) {
    "src-tauri\target\$TargetTriple\release"
} else {
    "src-tauri\target\release"
}

# 1. Locate signtool.exe (hardcoded default with automatic SDK fallback)
$signtool = "C:\Users\N4021286\repos\signtool.exe"
if (-Not (Test-Path $signtool)) {
    $found = Get-Command "signtool.exe" -ErrorAction SilentlyContinue
    if ($found) {
        $signtool = $found.Source
    } else {
        $sdkPaths = Get-ChildItem "C:\Program Files (x86)\Windows Kits\10\bin\*\x64\signtool.exe" -ErrorAction SilentlyContinue
        if ($sdkPaths) {
            $signtool = $sdkPaths[-1].FullName
        } else {
            Write-Error "signtool.exe not found. Please check your Windows SDK installation."
            exit 1
        }
    }
}

$sourceExe = Join-Path $releaseDir "llm-wiki.exe"
$distDir = "dist"
$targetExe = Join-Path $distDir "llm-wiki.exe"

# 2. Verify the binary exists
if (-Not (Test-Path $sourceExe)) {
    Write-Error "Standalone binary not found at $sourceExe. Please run '.\deploy.ps1' or 'npm run tauri build' first."
    exit 1
}

# 3. Create the /dist folder if it doesn't exist
if (-Not (Test-Path $distDir)) {
    Write-Host "Creating directory $distDir..."
    New-Item -ItemType Directory -Path $distDir | Out-Null
}

# 4. Copy standalone binary to /dist
Write-Host "Copying binary to $targetExe..."
Copy-Item -Path $sourceExe -Destination $targetExe -Force

# 4b. Copy WebView2Loader.dll next to the standalone binary if the build needs it.
# MSVC builds link the loader statically; MinGW builds import it from the DLL,
# so the standalone exe will not start without this file beside it.
$loaderDll = Join-Path $releaseDir "WebView2Loader.dll"
if (Test-Path $loaderDll) {
    Write-Host "Copying WebView2Loader.dll to $distDir..."
    Copy-Item -Path $loaderDll -Destination (Join-Path $distDir "WebView2Loader.dll") -Force
}

# 5. Copy NSIS installer to /dist if present
$nsisSetup = Get-ChildItem (Join-Path $releaseDir "bundle\nsis\*.exe") -ErrorAction SilentlyContinue | Select-Object -First 1
if ($nsisSetup) {
    $targetSetup = Join-Path $distDir $nsisSetup.Name
    Write-Host "Copying NSIS setup to $targetSetup..."
    Copy-Item -Path $nsisSetup.FullName -Destination $targetSetup -Force
}

# 6. Sign all executables in /dist
$filesToSign = Get-ChildItem -Path $distDir -Filter "*.exe"

foreach ($file in $filesToSign) {
    Write-Host "Signing $($file.Name) using Certum (time.certum.pl) timestamp server..."
    & $signtool sign /sha1 $Thumbprint /tr http://time.certum.pl/ /td sha512 /fd sha512 $file.FullName
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Failed to sign $($file.Name)."
        exit $LASTEXITCODE
    }
}

Write-Host "All binaries signed and packaged into /$distDir successfully!"