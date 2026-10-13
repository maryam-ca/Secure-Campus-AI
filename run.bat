@echo off
REM Starts the iris_ai service locally. Does NOT start the Flutter app -
REM that needs an attached device/emulator and interactive "flutter run"
REM (or your IDE's run button).

setlocal
cd /d "%~dp0"

if not exist .env (
    echo No .env found - run setup.bat first.
    exit /b 1
)

echo == Starting bus_eta job in a new window ==
start "SecureCampus bus_eta" cmd /k "cd bus_eta && call .venv\Scripts\activate.bat && python -m app.main"

echo == Starting overdue_checker in a new window ==
start "SecureCampus overdue_checker" cmd /k "cd overdue_checker && call .venv\Scripts\activate.bat && python -m app.main"

echo == Starting iris_ai service on http://localhost:8000 ==
cd iris_ai
call .venv\Scripts\activate.bat
for /f "usebackq tokens=1,2 delims==" %%A in ("..\.env") do set %%A=%%B
uvicorn app.main:app --host 0.0.0.0 --port %API_PORT% --reload
endlocal
