@echo off
cd /d "%~dp0"
python scripts\run_survival_demo.py --cow-event
if errorlevel 1 pause
