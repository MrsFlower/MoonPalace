@echo off
setlocal

:: Set w64devkit path to ensure gcc and other tools are available
set "W64DEVKIT_BIN=..\w64devkit\bin"
set "PATH=%W64DEVKIT_BIN%;%PATH%"

echo [INFO] Building Moonbit project for native target...
moon build --target native

echo [INFO] Copying executable to root directory...
if exist "_build\native\debug\build\cmd_glb\cmd_glb.exe" (
    copy /y "_build\native\debug\build\cmd_glb\cmd_glb.exe" "Aetheria3D_GLB.exe"
    echo [SUCCESS] Aetheria3D_GLB.exe generated successfully!
) else (
    echo [ERROR] Could not find the built executable at _build\native\debug\build\cmd_glb\cmd_glb.exe
    exit /b 1
)

endlocal
