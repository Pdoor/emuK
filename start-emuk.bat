@echo off
cd /d "%~dp0"
if not exist "certs\emuk-cert.pem" powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0make-cert.ps1"
set EMUK_HTTPS=1
py -3 companion.py
if errorlevel 1 python companion.py
