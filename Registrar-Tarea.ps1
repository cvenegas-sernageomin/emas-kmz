[CmdletBinding()]
param(
    [string]$NombreTarea = "EMAs-Chile-Actualizar",
    [int]$IntervaloMin = 15
)
$here = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Path }
$script = Join-Path $here "Actualizar-EMAs.ps1"
$accion = New-ScheduledTaskAction -Execute "powershell.exe" `
    -Argument "-NoProfile -NonInteractive -ExecutionPolicy Bypass -File `"$script`""
$disparador = New-ScheduledTaskTrigger -Once -At (Get-Date) `
    -RepetitionInterval (New-TimeSpan -Minutes $IntervaloMin)
$principal = New-ScheduledTaskPrincipal -UserId "$env:USERDOMAIN\$env:USERNAME" -LogonType Interactive
Register-ScheduledTask -TaskName $NombreTarea -Action $accion -Trigger $disparador `
    -Principal $principal -Description "Actualiza red_ema.kml con datos DMC cada $IntervaloMin min" -Force
Write-Host "Tarea '$NombreTarea' registrada (cada $IntervaloMin min, usuario actual)."
