@echo off
cd /d "%~dp0"
if not exist ".tools\release-python\Scripts\python.exe" python -m venv .tools\release-python
if errorlevel 1 goto failed
.tools\release-python\Scripts\python.exe -m pip install -r requirements-build.txt
if errorlevel 1 goto failed
.tools\release-python\Scripts\python.exe scripts\build_windows_release.py %*
if errorlevel 1 goto failed
echo Release build completed in build_release.
pause
exit /b 0
:failed
echo Release build failed. See the output above.
pause
exit /b 1
