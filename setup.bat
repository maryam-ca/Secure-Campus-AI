@echo off
REM SecureCampus - first-time setup (Windows).
REM What this automates: Python venv + deps for the iris AI service,
REM .env scaffolding, QR code generation.
REM What it cannot automate: your Firebase project, firebase_options.dart,
REM or anything needing a physical phone - see docs\LIMITATIONS.md.

setlocal
cd /d "%~dp0"

echo == SecureCampus setup ==

if not exist .env (
    copy .env.example .env >nul
    echo Created .env from .env.example - fill in your Firebase values before running.
) else (
    echo .env already exists, leaving it as-is.
)

if not exist secrets mkdir secrets
echo Put your Firebase service-account JSON at .\secrets\serviceAccountKey.json

echo -- iris_ai: creating Python virtual environment --
cd iris_ai
python -m venv .venv
call .venv\Scripts\activate.bat
python -m pip install --upgrade pip >nul
pip install -r requirements.txt
call .venv\Scripts\deactivate.bat
cd ..

echo -- bus_eta: creating Python virtual environment --
cd bus_eta
python -m venv .venv
call .venv\Scripts\activate.bat
python -m pip install --upgrade pip >nul
pip install -r requirements.txt
call .venv\Scripts\deactivate.bat
cd ..

echo -- functions: creating Python virtual environment (local import checks only - deploy via firebase CLI) --
cd functions
python -m venv venv
call venv\Scripts\activate.bat
python -m pip install --upgrade pip >nul
pip install -r requirements.txt
call venv\Scripts\deactivate.bat
cd ..

echo -- generating QR codes for the 5 seed library books --
python scripts\generate_qr_codes.py

where flutter >nul 2>nul
if %errorlevel%==0 (
    echo -- mobile: flutter pub get --
    cd mobile
    call flutter pub get
    cd ..
    echo NOTE: you still need to run "flutterfire configure" inside mobile\ against
    echo       your own Firebase project before the app will build - see README.
) else (
    echo Flutter SDK not found on PATH - skipping "flutter pub get".
    echo Install Flutter (https://flutter.dev) then run this script again,
    echo or run "flutter pub get" manually inside mobile\.
)

echo.
echo Setup finished. Still required before a full demo (see README\docs\LIMITATIONS.md):
echo   1. Create a Firebase project, enable Auth/Firestore/RTDB/Storage/FCM.
echo   2. Put the service-account key at .\secrets\serviceAccountKey.json and fill .env.
echo   3. Run "firebase deploy --only firestore:rules,storage:rules" from firebase\.
echo   4. Run "python scripts\seed_firebase.py" to create the 10 students/books/bus/driver.
echo   5. Run "flutterfire configure" inside mobile\.
echo   6. Install the RTSP camera app on the iPhone 13 and set CAMERA_RTSP_URL in .env.
echo.
echo Then run: run.bat
endlocal
