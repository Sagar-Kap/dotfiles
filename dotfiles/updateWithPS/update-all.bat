@echo off
:: ==============================================================================
:: update-all.bat
::
:: A simple launcher for update-all.ps1.
:: Double-click this file to run the full update script.
::
:: Why this exists:
::   Windows blocks double-clicking .ps1 files directly due to execution
::   policy restrictions. This .bat acts as a workaround — .bat files are
::   always double-clickable from Explorer with no restrictions.
::
:: Usage:
::   Just double-click this file.
::   Keep it in the same folder as update-all.ps1.
:: ==============================================================================

:: %~dp0 resolves to the folder this .bat file lives in,
:: so both files just need to be in the same directory.
powershell -ExecutionPolicy Bypass -File "%~dp0update-all.ps1"

:: Keeps the window open after PowerShell finishes so you can read the output.
:: Press any key to close.
pause
