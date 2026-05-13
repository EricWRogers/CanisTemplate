@echo off
setlocal

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0create-game-script.ps1" %*
exit /b %ERRORLEVEL%
