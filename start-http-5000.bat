@echo off
cd /d "%~dp0"
set EMUK_HTTPS=0
set EMUK_HTTP_FALLBACK=0
set EMUK_PORT=5000
py -3 companion.py
if errorlevel 1 python companion.py
