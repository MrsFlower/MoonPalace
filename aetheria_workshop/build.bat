@echo off
setlocal

:: Set w64devkit path to ensure gcc and other tools are available
set "W64DEVKIT_BIN=..\w64devkit\bin"
set "PATH=%W64DEVKIT_BIN%;%PATH%"

echo [INFO] Cleaning up old build artifacts...
if exist "_build" (
    rmdir /s /q "_build"
)

echo [INFO] Building Moonbit project for native target...
moon build --target native
if %ERRORLEVEL% neq 0 (
    echo [ERROR] Build failed!
    exit /b %ERRORLEVEL%
)

echo [INFO] Copying executable to root directory...
if exist "_build\native\debug\build\src\main\main.exe" (
    copy /y "_build\native\debug\build\src\main\main.exe" "AetheriaWorkshop.exe"
    echo [SUCCESS] AetheriaWorkshop.exe generated successfully!
) else (
    echo [ERROR] Could not find the built executable at _build\native\debug\build\src\main\main.exe
    exit /b 1
)

:: Copy raylib.dll to the current directory so the exe can run
copy /y "..\raylib.dll" "raylib.dll"

endlocal
