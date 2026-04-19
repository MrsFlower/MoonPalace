@echo off
setlocal

:: Set w64devkit path to ensure gcc and other tools are available
set "W64DEVKIT_BIN=C:\Users\15866\Documents\codeheaven\moonbit-game\moonpalace\w64devkit\bin"
set "PATH=%W64DEVKIT_BIN%;%PATH%"
set "CC=gcc"
set "MOON_CC=gcc"

echo [INFO] Building Moonbit project for native target...
moon build --target native
if %ERRORLEVEL% neq 0 (
    echo [ERROR] Build failed!
    exit /b %ERRORLEVEL%
)

echo [INFO] Copying executables to root directory...
if exist "_build\native\debug\build\cmd\main\main.exe" (
    copy /y "_build\native\debug\build\cmd\main\main.exe" "AetheriaStudio_v4.exe"
    echo [SUCCESS] AetheriaStudio_v4.exe generated successfully!
)

if exist "_build\native\debug\build\src\llm_worker\llm_worker.exe" (
    copy /y "_build\native\debug\build\src\llm_worker\llm_worker.exe" "llm_worker_v4.exe"
)

if exist "_build\native\debug\build\src\comfy_worker\comfy_worker.exe" (
    copy /y "_build\native\debug\build\src\comfy_worker\comfy_worker.exe" "comfy_worker_v4.exe"
)

if exist "_build\native\debug\build\src\comfy_3d_worker\comfy_3d_worker.exe" (
    copy /y "_build\native\debug\build\src\comfy_3d_worker\comfy_3d_worker.exe" "comfy_3d_worker_v4.exe"
)

endlocal
