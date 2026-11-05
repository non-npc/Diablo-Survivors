@echo off
cd /d "%~dp0"
python -m inspector.app %*
if errorlevel 1 pause
