@echo off
cd /d "%~dp0"
python -m manager.app %*
if errorlevel 1 pause
