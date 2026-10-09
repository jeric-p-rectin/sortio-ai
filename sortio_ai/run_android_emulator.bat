@echo off
REM ===========================================================================
REM Sortio AI - Android emulator runner (double-click friendly wrapper)
REM Forwards to run_android_emulator.ps1 (same folder).
REM   run_android_emulator.bat              -> launch first available AVD
REM   run_android_emulator.bat -ListOnly    -> list emulators only
REM   run_android_emulator.bat -EmulatorId  -> launch a specific AVD
REM ===========================================================================
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0run_android_emulator.ps1" %*
pause
