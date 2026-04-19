$ErrorActionPreference = "Stop"

$w64devkit_url = "https://github.com/skeeto/w64devkit/releases/download/v1.23.0/w64devkit-1.23.0.zip"
$w64devkit_zip = "w64devkit.zip"
$raylib_url = "https://github.com/raysan5/raylib/releases/download/5.0/raylib-5.0_win64_mingw-w64.zip"
$raylib_zip = "raylib-5.0_win64_mingw-w64.zip"

Write-Host "Setting up Windows Build Environment for Aetheria3D..."

# Function to download with retry
function Download-FileWithRetry {
    param($url, $outFile)
    $maxRetries = 3
    $retryCount = 0
    $success = $false

    while (-not $success -and $retryCount -lt $maxRetries) {
        try {
            Write-Host "Downloading $outFile from $url..."
            Invoke-WebRequest -Uri $url -OutFile $outFile -UseBasicParsing
            $success = $true
        } catch {
            $retryCount++
            Write-Warning "Download failed. Retry $retryCount of $maxRetries..."
            Start-Sleep -Seconds 2
        }
    }

    if (-not $success) {
        throw "Failed to download $outFile after $maxRetries attempts."
    }
}

# 1. Download and extract w64devkit
if (-not (Test-Path "w64devkit")) {
    if (-not (Test-Path $w64devkit_zip)) {
        Download-FileWithRetry -url $w64devkit_url -outFile $w64devkit_zip
    }
    Write-Host "Extracting $w64devkit_zip..."
    Expand-Archive -Path $w64devkit_zip -DestinationPath "." -Force
} else {
    Write-Host "w64devkit already exists. Skipping."
}

# 2. Download and extract raylib
if (-not (Test-Path "raylib")) {
    if (-not (Test-Path $raylib_zip)) {
        Download-FileWithRetry -url $raylib_url -outFile $raylib_zip
    }
    Write-Host "Extracting $raylib_zip..."
    Expand-Archive -Path $raylib_zip -DestinationPath "raylib" -Force
} else {
    Write-Host "raylib already exists. Skipping."
}

Write-Host "Environment setup complete! You can now run build scripts."
