@echo off
:: WiggleAI — Easy Launcher
:: Drag & drop a photo onto this file, or run: wiggle.bat path\to\photo.jpg

setlocal
set "SCRIPT_DIR=%~dp0"
set "API_DIR=%SCRIPT_DIR%apps\api"
set "VENV=%API_DIR%\venv\Scripts\python.exe"
set "PROTOTYPE=%SCRIPT_DIR%ml\scripts\prototype_wiggle.py"

:: Check venv exists
if not exist "%VENV%" (
    echo [ERROR] Python venv not found at: %VENV%
    echo Run setup first: see README.md
    pause
    exit /b 1
)

:: Get input photo
if "%~1"=="" (
    echo WiggleAI - Wiggle 3D Effect Generator
    echo ======================================
    echo.
    echo Usage: wiggle.bat path\to\photo.jpg [options]
    echo.
    echo Options (all optional):
    echo   --output  output.mp4   Output file path (default: same folder as input)
    echo   --style   nishika      Style: normal, nishika, vintage, cinematic, glitch, cyberpunk
    echo   --strength 0.7         Parallax strength 0.1-1.0 (default: 0.6)
    echo   --frames  6            Number of frames: 3, 4, 6, 8 (default: 4)
    echo   --fps     15           Frames per second (default: 15)
    echo.
    echo Example:
    echo   wiggle.bat C:\Photos\portrait.jpg --style nishika --strength 0.8
    echo.
    pause
    exit /b 0
)

set "INPUT=%~1"
set "INPUT_DIR=%~dp1"
set "INPUT_NAME=%~n1"

:: Default output next to input file
set "OUTPUT=%INPUT_DIR%%INPUT_NAME%_wiggle.mp4"

:: Run prototype
set PYTHONUTF8=1
set HF_HUB_DISABLE_SYMLINKS_WARNING=1

echo.
echo  WiggleAI Processing: %INPUT_NAME%
echo  -----------------------------------------------
"%VENV%" "%PROTOTYPE%" --input "%INPUT%" --output "%OUTPUT%" %2 %3 %4 %5 %6 %7 %8

if %ERRORLEVEL% EQU 0 (
    echo.
    echo  Opening output...
    start "" "%OUTPUT%"
) else (
    echo.
    echo [ERROR] Processing failed. Check output above for details.
)

pause
