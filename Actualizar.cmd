@echo off
REM Doble clic para actualizar los datos de las EMAs (genera red_ema.kml)
cd /d "%~dp0"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Actualizar-EMAs.ps1"
echo.
echo Listo. En Google Earth Pro: clic derecho sobre "EMAs Chile" - Actualizar/Refresh
echo (o espera, se recarga solo cada 15 min).
pause
