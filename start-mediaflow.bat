@echo off
cd /d "%~dp0"

set "APP__SERVER__HOST=0.0.0.0"
set "APP__SERVER__PORT=8888"
set "CONFIG_PATH=%~dp0config.toml"

echo MediaFlow 8888 portunda basladilir...
echo.

bin\mediaflow-proxy-light.exe

pause
