@echo off
REM Builds the debug APK and installs it on the connected phone, then starts it.
REM Faster than "flutter run" when you only want the app on the phone (no
REM hot-reload session). Run from the project root.
REM
REM   install_app.bat
REM   install_app.bat R58M38FH13E      pick a device by id (see: adb devices)
REM
REM If the phone refuses the update ("signatures do not match"), the script
REM falls back to "flutter install", which replaces the app. That clears the
REM app's local data on the phone (your Firebase data is not affected).

setlocal
cd /d "%~dp0mobile" || exit /b 1

set DEVICE=
if not "%~1"=="" set DEVICE=-s %~1

if not exist demo_accounts.json (
    if exist "%~dp0CREDENTIALS.md" python "%~dp0scripts\make_demo_defines.py"
)
set DEFINES=
if exist demo_accounts.json set DEFINES=--dart-define-from-file=demo_accounts.json

call flutter build apk --debug %DEFINES%
if errorlevel 1 (
    echo Build failed.
    exit /b 1
)

adb %DEVICE% install -r build\app\outputs\flutter-apk\app-debug.apk
if errorlevel 1 (
    echo Update refused - replacing the installed app instead...
    if "%~1"=="" (call flutter install --debug) else (call flutter install -d %~1 --debug)
)

adb %DEVICE% shell monkey -p com.example.securecampus -c android.intent.category.LAUNCHER 1 >nul 2>&1
echo Done. Unlock the phone and open SecureCampus.
endlocal
