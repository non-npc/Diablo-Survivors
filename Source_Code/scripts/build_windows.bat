@echo off
setlocal
cd /d "%~dp0.."
python -m pip install -r requirements-dev.txt
if errorlevel 1 exit /b 1
python scripts\check.py
if errorlevel 1 exit /b 1
python scripts\package_release.py
exit /b %errorlevel%
