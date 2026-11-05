@echo off
cd /d "%~dp0"
python scripts\run_gameshift.py --configure
if errorlevel 1 pause
