param(
    [string]$Thumbprint = "FD10E795F1DC5045FA8448C6C8E99C59B127635F",
    [string]$TargetTriple = "",
    [switch]$SkipSign
)

# Cargo writes to target\release for the host triple, but target\<triple>\release
# when the build was invoked with an explicit --target.
$releaseDir = if ($TargetTriple) {
    "src-tauri\target\$TargetTriple\release"
} else {
    "src-tauri\target\release"
}

# 1. Locate signtool.exe (hardcoded default with automatic SDK fallback)
$signtool = "C:\Program Files (x86)\Windows Kits\10\bin\10.0.26100.0\x64\signtool.exe"
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
$loaderDll = Join-Path $releaseDir "WebView2Loader.dll"
if (Test-Path $loaderDll) {
    Write-Host "Copying WebView2Loader.dll to $distDir..."
    Copy-Item -Path $loaderDll -Destination (Join-Path $distDir "WebView2Loader.dll") -Force
}

# 4c. Copy pdfium.dll next to the standalone binary
$pdfiumDll = "src-tauri\pdfium\pdfium.dll"
if (Test-Path $pdfiumDll) {
    Write-Host "Copying pdfium.dll to $distDir..."
    Copy-Item -Path $pdfiumDll -Destination (Join-Path $distDir "pdfium.dll") -Force
}

# 4d. Package mcp-server into /dist
$mcpSrc = "mcp-server"
if (Test-Path $mcpSrc) {
    if (-Not (Test-Path "$mcpSrc\dist\src\index.js")) {
        Write-Host "Building mcp-server (npm run mcp:build)..."
        npm run mcp:build
    }
    $mcpDist = Join-Path $distDir "mcp-server"
    if (-Not (Test-Path $mcpDist)) {
        New-Item -ItemType Directory -Path $mcpDist | Out-Null
    }
    Write-Host "Packaging mcp-server into $mcpDist..."
    Copy-Item -Path "$mcpSrc\package.json" -Destination $mcpDist -Force
    if (Test-Path "$mcpSrc\dist") {
        Copy-Item -Path "$mcpSrc\dist" -Destination $mcpDist -Recurse -Force
    }
    if (Test-Path "$mcpSrc\node_modules") {
        Copy-Item -Path "$mcpSrc\node_modules" -Destination $mcpDist -Recurse -Force
    }
}

# 5. Sign standalone binary in /dist
if (-not $SkipSign) {
    Write-Host "Signing $targetExe using Certum (time.certum.pl) timestamp server..."
    & $signtool sign /sha1 $Thumbprint /tr http://time.certum.pl/ /td sha512 /fd sha512 $targetExe
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Failed to sign $targetExe."
        exit $LASTEXITCODE
    }
    Write-Host "Binary signed and packaged into /$distDir successfully!" -ForegroundColor Green
} else {
    Write-Host "Signing skipped. Standalone binary ready in $targetExe" -ForegroundColor Yellow
}
exit 0