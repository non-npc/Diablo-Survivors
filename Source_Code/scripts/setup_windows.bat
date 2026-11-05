@echo off
setlocal
cd /d "%~dp0.."
python -m pip install -r requirements-dev.txt
if errorlevel 1 exit /b 1
python scripts\setup_stormlib.py
exit /b %errorlevel%
