@echo off
REM Doble clic: actualiza los datos y los publica en GitHub (rama live).
REM Quienes tengan EMAs_Chile_online.kmz lo veran actualizado al refrescar en Google Earth.
cd /d "%~dp0"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Publicar-Online.ps1"
echo.
pause
