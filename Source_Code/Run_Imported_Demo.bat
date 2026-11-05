@echo off
cd /d "%~dp0"
python scripts\run_imported_demo.py %*
if errorlevel 1 pause
