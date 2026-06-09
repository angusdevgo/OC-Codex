@echo off
setlocal

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0Source_Codes\build\Build-O-C-Release.ps1"

pause
