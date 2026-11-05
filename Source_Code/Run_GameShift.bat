@echo off
cd /d "%~dp0"
python scripts\run_gameshift.py
if errorlevel 1 pause
