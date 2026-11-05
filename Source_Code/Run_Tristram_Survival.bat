@echo off
cd /d "%~dp0"
python scripts\run_survival_demo.py --arena tristram
if errorlevel 1 pause
