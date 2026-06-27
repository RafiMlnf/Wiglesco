@echo off
:: Wiglesco Local Development Launcher
:: Starts both the FastAPI backend and Next.js frontend on localhost.

setlocal
set "SCRIPT_DIR=%~dp0"
set "API_DIR=%SCRIPT_DIR%apps\api"
set "VENV_PYTHON=%API_DIR%\venv\Scripts\python.exe"

echo ==============================================
echo Wiglesco — Launching Local Dev Environment
echo ==============================================

:: Check virtual environment
if not exist "%VENV_PYTHON%" (
    echo [ERROR] Python virtual environment not found at: %VENV_PYTHON%
    echo Please set up the environment first by running Phase 1.
    pause
    exit /b 1
)

:: Ensure uvicorn is installed in the virtual environment
echo Checking uvicorn...
"%VENV_PYTHON%" -m pip show uvicorn >nul 2>&1
if %ERRORLEVEL% NEQ 0 (
    echo Installing uvicorn...
    "%VENV_PYTHON%" -m pip install uvicorn
)

:: Start Backend in a new minimized window
echo Starting FastAPI Backend (port 8000)...
set PYTHONUTF8=1
set HF_HUB_DISABLE_SYMLINKS_WARNING=1
start "Wiglesco Backend" /min cmd /c "cd /d "%API_DIR%" && venv\Scripts\python.exe -m uvicorn main:app --host 127.0.0.1 --port 8000"

:: Wait a moment for backend to initialize
timeout /t 3 /nobreak >nul

:: Start Frontend in current console (or via npm)
echo Starting Next.js Frontend (port 3000)...
cd /d "%SCRIPT_DIR%"
npm run dev

pause
