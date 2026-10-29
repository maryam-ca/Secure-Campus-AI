@echo off
REM Builds the Flutter web app from the CURRENT code and deploys it to the live
REM Vercel site (https://securecampus-seven.vercel.app).
REM
REM Run it from the repo root:   .\deploy_web.bat
REM
REM First time (or if it says wrong account):   vercel logout   then   vercel login
REM and sign in as the account that owns the site: maryamfatima454.
REM See docs\DEPLOY_WEB.md.

setlocal
cd /d "%~dp0"

echo == Checking the Vercel account ==
set VUSER=
for /f "delims=" %%U in ('vercel whoami 2^>nul') do set VUSER=%%U
echo Signed in to Vercel as: %VUSER%
if /i not "%VUSER%"=="maryamfatima454" (
    echo.
    echo WRONG ACCOUNT. The live site belongs to maryamfatima454.
    echo Run:  vercel logout    then    vercel login
    echo and sign in as maryamfatima454, then run this script again.
    exit /b 1
)

echo.
echo == Building the web app from the current code ==
cd mobile
call flutter build web --release || (echo Build failed. & exit /b 1)
cd ..

set OUT=%TEMP%\securecampus_web_deploy
if exist "%OUT%" rmdir /s /q "%OUT%"
mkdir "%OUT%"
xcopy /e /i /y /q "mobile\build\web\*" "%OUT%\" >nul

> "%OUT%\vercel.json" (
  echo {
  echo   "cleanUrls": true,
  echo   "headers": [
  echo     { "source": "/(.*)", "headers": [ { "key": "Cache-Control", "value": "no-cache" } ] }
  echo   ]
  echo }
)

echo.
echo == Deploying to Vercel (production) ==
cd /d "%OUT%"
call vercel deploy --prod --yes --name securecampus --scope maryams-projects-791bda4b || (echo Deploy failed. & exit /b 1)

echo.
echo Done. Open https://securecampus-seven.vercel.app and press Ctrl+F5.
endlocal
