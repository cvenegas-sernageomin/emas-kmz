[CmdletBinding()]
param(
    [int]$MaxEstaciones = 0   # 0 = todas; util para pruebas rapidas
)
$here = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Path }

# 1. Actualizar datos locales (proceso aislado para que su 'exit' no corte este script)
Write-Host "Descargando estaciones y generando red_ema.kml ..."
& powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $here "Actualizar-EMAs.ps1") -MaxEstaciones $MaxEstaciones
if ($LASTEXITCODE -ne 0) { Write-Error "Actualizar-EMAs.ps1 fallo (exit $LASTEXITCODE). No se publica."; exit 1 }

# 2. Publicar red_ema.kml + estado.json a la rama 'live' (worktree temporal; force = ultimo gana)
$wt = Join-Path $env:TEMP "emas-live-pub"
if (Test-Path $wt) { git -C $here worktree remove $wt --force 2>$null; Remove-Item $wt -Recurse -Force -ErrorAction SilentlyContinue }
git -C $here fetch origin live --quiet
git -C $here worktree add $wt origin/live --quiet
if ($LASTEXITCODE -ne 0) { Write-Error "No pude preparar el worktree de 'live'. Configuraste el remoto?"; exit 1 }

Copy-Item (Join-Path $here "red_ema.kml") (Join-Path $wt "red_ema.kml") -Force
if (Test-Path (Join-Path $here "estado.json")) { Copy-Item (Join-Path $here "estado.json") (Join-Path $wt "estado.json") -Force }

git -C $wt add -f red_ema.kml estado.json
git -C $wt commit -m ("data: publicacion local {0}" -f (Get-Date -Format "yyyy-MM-dd HH:mm")) 2>&1 | Select-Object -Last 1
git -C $wt push -f origin HEAD:live 2>&1 | Select-Object -Last 2
$pushOk = ($LASTEXITCODE -eq 0)
git -C $here worktree remove $wt --force 2>$null

if ($pushOk) {
    Write-Host "Publicado en GitHub (rama live). Quienes tengan EMAs_Chile_online.kmz lo veran al refrescar."
} else {
    Write-Error "Fallo el push a 'live'."; exit 1
}
