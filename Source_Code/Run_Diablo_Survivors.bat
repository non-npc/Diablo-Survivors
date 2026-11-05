@echo off
cd /d "%~dp0"
python scripts\run_diablo_survivors.py
if errorlevel 1 pause
