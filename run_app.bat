@echo off
REM Runs the SecureCampus mobile app on a connected phone/emulator.
REM
REM Use this from the project root (or double-click it). Plain "flutter run" in
REM this folder does NOT work: the Flutter app lives in mobile\, and from here
REM Flutter walks up to an unrelated project in your user folder instead.
REM
REM   run_app.bat                      run on the connected device
REM   run_app.bat -d R58M38FH13E       pick a device (see: flutter devices)
REM
REM Debug builds also get the "Demo accounts" button on the login screen when
REM CREDENTIALS.md exists (the list is generated into mobile\demo_accounts.json,
REM which is git-ignored).

setlocal
cd /d "%~dp0mobile" || exit /b 1

if not exist demo_accounts.json (
    if exist "%~dp0CREDENTIALS.md" (
        echo Creating demo_accounts.json from CREDENTIALS.md ...
        python "%~dp0scripts\make_demo_defines.py"
    )
)

set DEFINES=
if exist demo_accounts.json set DEFINES=--dart-define-from-file=demo_accounts.json

echo Running: flutter run %DEFINES% %*
flutter run %DEFINES% %*
endlocal
