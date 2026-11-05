@echo off
cd /d "%~dp0"
python scripts\run_survival_demo.py --arena tristram --treasure-demo
if errorlevel 1 pause
