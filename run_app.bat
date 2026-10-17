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
setlocal
cd /d "%~dp0mobile" || exit /b 1

echo Running: flutter run %*
flutter run %*
endlocal
