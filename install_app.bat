@echo off
REM Installs SecureCampus on the connected phone as a normal app, so it keeps
REM working after the cable is pulled out. Run it from the project root.
REM
REM   .\install_app.bat                 release build (fast, no debug banner)
REM   .\install_app.bat debug           debug build instead
REM   .\install_app.bat release R58M38FH13E   pick a phone by id (see: adb devices)
REM
REM The app finds the account service by itself (the service writes its address to
REM Firebase when it starts; start it with .\run.bat). Phone and PC must be on the
REM same WiFi for the Admin's account actions; everything else (login, library,
REM bus) goes straight to Firebase and works on any internet connection.
REM
REM If the phone refuses the update ("signatures do not match"), the script
REM falls back to "flutter install", which replaces the app. That clears the
REM app's local data on the phone (your Firebase data is not affected).
setlocal
cd /d "%~dp0mobile" || exit /b 1

set "MODE=release"
if /i "%~1"=="debug" set "MODE=debug"
set "DEVICE="
if not "%~2"=="" set "DEVICE=-s %~2"

echo Building the %MODE% app (the first build takes several minutes)...
call flutter build apk --%MODE%
if errorlevel 1 (
    echo Build failed.
    exit /b 1
)

adb %DEVICE% install -r build\app\outputs\flutter-apk\app-%MODE%.apk
if errorlevel 1 (
    echo Update refused - replacing the installed app instead...
    if "%~2"=="" (call flutter install --%MODE%) else (call flutter install -d %~2 --%MODE%)
)

adb %DEVICE% shell monkey -p com.example.securecampus -c android.intent.category.LAUNCHER 1 >nul 2>&1
echo Done. Unlock the phone and open SecureCampus. You can unplug the cable now.
endlocal
