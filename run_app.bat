@echo off
REM Runs the whole SecureCampus app with ONE command, from the project root:
REM
REM   .\run_app.bat                    phone if one is connected, otherwise Chrome
REM   .\run_app.bat -d chrome          pick a device yourself (see: flutter devices)
REM
REM It (1) starts the account service in its own window if it is not already
REM running, (2) picks the connected phone (or Chrome), and (3) runs the app from
REM the mobile\ folder. Do NOT type plain "flutter run" in the project root: the
REM Flutter app lives in mobile\, and from the root Flutter walks up to an
REM unrelated project in your user folder and builds that one instead.
REM
REM The phone finds the account service by itself: the service writes its network
REM address to Firebase when it starts, and the app reads it from there. The phone
REM must be on the same WiFi as this PC.
setlocal
cd /d "%~dp0"

REM ---- 1. the account service (port 8000) ----
set "SVC=down"
for /f %%R in ('powershell -NoProfile -Command "try { $r = Invoke-RestMethod http://127.0.0.1:8000/health -TimeoutSec 3; if ($r.service -eq 'iris_ai') { 'ok' } else { 'other' } } catch { 'down' }"') do set "SVC=%%R"

if "%SVC%"=="ok" goto device
if "%SVC%"=="other" goto other

echo Starting the SecureCampus services in a new window...
start "SecureCampus services" cmd /k ""%~dp0run.bat""
powershell -NoProfile -Command "for ($i = 0; $i -lt 25; $i++) { try { if ((Invoke-RestMethod http://127.0.0.1:8000/health -TimeoutSec 2).service -eq 'iris_ai') { exit 0 } } catch {}; Start-Sleep 2 }; exit 1"
if errorlevel 1 goto failed
goto device

:other
echo Another program is answering on port 8000, not the SecureCampus account service.
echo Close that program (check: netstat -ano ^| findstr :8000), then run this again.
exit /b 1

:failed
echo The account service did not start. Look at the "SecureCampus services" window for the reason.
exit /b 1

REM ---- 2. which device ----
:device
set "DEVARGS=%*"
if not "%~1"=="" goto run
set "DEVICE="
for /f "skip=1 tokens=1,2" %%A in ('adb devices 2^>nul') do if "%%B"=="device" if not defined DEVICE set "DEVICE=%%A"
if defined DEVICE goto phone
echo No phone found - running in Chrome.
set "DEVARGS=-d chrome --web-port=59025"
goto run

:phone
echo Phone found: %DEVICE%
set "DEVARGS=-d %DEVICE%"

REM ---- 3. the app ----
:run
cd /d "%~dp0mobile" || exit /b 1
echo Running: flutter run %DEVARGS%
flutter run %DEVARGS%
endlocal
