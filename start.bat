@echo off
setlocal EnableExtensions EnableDelayedExpansion

cd /d "%~dp0"

set "ROOT=%~dp0"
set "BIN=%ROOT%bin"
set "PORT=7000"

rem Stremio ucun sabit Cloudflare Worker
set "WORKER_URL=https://stremio-tr-source.ustaqalib-8b4.workers.dev"

rem Addon ucun sabit ngrok
set "NGROK_HOST=coveting-pureness-squatter.ngrok-free.dev"

set "MEDIAFLOW_EXE=%BIN%\mediaflow-proxy-light.exe"
set "CLOUDFLARED_EXE=%BIN%\cloudflared-windows-amd64.exe"
set "NGROK_EXE=%BIN%\ngrok.exe"

set "CONFIG_PATH=%ROOT%config.toml"
set "MEDIAFLOW_PASSWORD="

for /f "tokens=2 delims==" %%P in ('
    findstr /r /c:"api_password[ ]*=" "%CONFIG_PATH%"
') do (
    set "MEDIAFLOW_PASSWORD=%%~P"
)

set "MEDIAFLOW_PASSWORD=!MEDIAFLOW_PASSWORD: =!"
set "MEDIAFLOW_PASSWORD=!MEDIAFLOW_PASSWORD:"=!"

set "PROXY_TUNNEL_LOG=%ROOT%proxy-tunnel.log"

if not exist "%CONFIG_PATH%" (
    if exist "%ROOT%config.toml.example" (
        copy "%ROOT%config.toml.example" "%CONFIG_PATH%" >nul
        echo.
        echo config.toml yaradildi.
        echo Fayli acin ve auth.api_password deyerini yazin.
        echo Sonra start.bat faylini yeniden başladın.
        echo.
        pause
        exit /b 0
    )

    echo [XETA] config.toml.example tapilmadi:
    echo %ROOT%config.toml.example
    pause
    exit /b 1
)


if not exist "%CONFIG_PATH%" (
    echo [XETA] config.toml tapilmadi:
    echo %CONFIG_PATH%
    pause
    exit /b 1
)

if not exist "%MEDIAFLOW_EXE%" (
    echo [XETA] MediaFlow tapilmadi:
    echo %MEDIAFLOW_EXE%
    pause
    exit /b 1
)

if not exist "%CLOUDFLARED_EXE%" (
    echo [XETA] cloudflared tapilmadi:
    echo %CLOUDFLARED_EXE%
    pause
    exit /b 1
)

if not exist "%NGROK_EXE%" (
    echo [XETA] ngrok tapilmadi:
    echo %NGROK_EXE%
    pause
    exit /b 1
)

rem Kohne prosesleri bagla
echo [INFO] Kohne prosesler baglanir...
taskkill /IM mediaflow-proxy-light.exe /F >nul 2>&1
taskkill /IM cloudflared-windows-amd64.exe /F >nul 2>&1
taskkill /IM ngrok.exe /F >nul 2>&1
taskkill /IM node.exe /F >nul 2>&1

del /q "%PROXY_TUNNEL_LOG%" >nul 2>&1

rem ------------------------------------------------------------
rem 1. MediaFlow
rem ------------------------------------------------------------

echo [INFO] MediaFlow basladilir...

start "MediaFlow" /D "%ROOT%" cmd /k call "%ROOT%start-mediaflow.bat"

timeout /t 4 /nobreak >nul

rem ------------------------------------------------------------
rem 2. MediaFlow Cloudflare tunnel
rem ------------------------------------------------------------

echo [INFO] MediaFlow ucun Cloudflare tunnel basladilir...

start "Tunnel-Proxy" "%CLOUDFLARED_EXE%" ^
    tunnel --url http://localhost:8888 ^
    --logfile "%PROXY_TUNNEL_LOG%"

set "MEDIAFLOW_URL="

for /L %%I in (1,1,60) do (
    if exist "%PROXY_TUNNEL_LOG%" (
        for /f "tokens=*" %%U in ('
            powershell -NoProfile -Command ^
            "$m=Select-String -Path '%PROXY_TUNNEL_LOG%' -Pattern 'https://[a-zA-Z0-9-]+\.trycloudflare\.com' | Select-Object -First 1; if($m){$m.Matches[0].Value}"
        ') do (
            set "MEDIAFLOW_URL=%%U"
        )
    )

    if defined MEDIAFLOW_URL goto MEDIAFLOW_READY

    timeout /t 1 /nobreak >nul
)

echo [XETA] MediaFlow Cloudflare URL tapilmadi.
echo Log fayli:
echo %PROXY_TUNNEL_LOG%
pause
exit /b 1

:MEDIAFLOW_READY

echo [OK] MediaFlow URL:
echo !MEDIAFLOW_URL!

rem ------------------------------------------------------------
rem 3. npm addon
rem ------------------------------------------------------------

echo [INFO] npm addon build edilir...

call npm run build

if errorlevel 1 (
    echo [XETA] npm run build ugursuz oldu.
    pause
    exit /b 1
)

echo [INFO] npm addon basladilir...

start "Npm Addon" /D "%ROOT%" cmd /k ^
    "set NODE_ENV=production&&set PUBLIC_DEPLOYMENT=true&&set USE_BUILTIN_TUNNEL=false&&set PUBLIC_HOST=%NGROK_HOST%&&set PUBLIC_BASE_URL=%WORKER_URL%&&set MEDIAFLOW_URL=!MEDIAFLOW_URL!&&set PORT=%PORT%&&npm start"

timeout /t 5 /nobreak >nul

rem ------------------------------------------------------------
rem 4. Addon ngrok tunnel
rem ------------------------------------------------------------

echo [INFO] Addon ucun ngrok basladilir...

start "Tunnel-Addon" "%NGROK_EXE%" ^
    http --url=https://%NGROK_HOST% %PORT%

echo.
echo ============================================================
echo              SISTEM HAZIRDIR
echo ============================================================
echo.
echo Stremio manifest:
echo %WORKER_URL%/manifest.json
echo.
echo MediaFlow URL:
echo !MEDIAFLOW_URL!
echo.
echo Ngrok origin:
echo https://%NGROK_HOST%
echo.
echo Portlar:
echo MediaFlow: 8888
echo Npm addon: 7000
echo.
echo Bu pencereyi, MediaFlow, Cloudflare, npm ve ngrok pencerelerini baglamayin.
echo.

pause >nul

endlocal
