@echo off
cd /d "%~dp0"
python scripts\run_survival_demo.py --synthetic %*
if errorlevel 1 pause
