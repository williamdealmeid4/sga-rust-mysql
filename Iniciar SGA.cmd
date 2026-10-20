@echo off
cd /d "%~dp0"
powershell -NoProfile -Command "try { $r = Invoke-WebRequest -UseBasicParsing http://127.0.0.1:3030 -TimeoutSec 2; if ($r.StatusCode -eq 200) { exit 0 } } catch {}; exit 1"
if not errorlevel 1 goto browser
start "SGA" /min "%~dp0bin\sga-fbi.exe"
timeout /t 2 /nobreak >nul
:browser
start "" "http://127.0.0.1:3030"
