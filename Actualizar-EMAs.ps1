[CmdletBinding()]
param(
    [string]$ConfigPath,
    [int]$MaxEstaciones = 0   # 0 = todas
)

# $PSScriptRoot puede venir vacio en el param() bajo -File; resolver en el cuerpo
$here = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Path }
if (-not $ConfigPath) { $ConfigPath = Join-Path $here "config.json" }

. (Join-Path $here "src\EmaParse.ps1")
. (Join-Path $here "src\EmaFunctions.ps1")

$cfg = Get-Content $ConfigPath -Raw | ConvertFrom-Json
$logPath    = Join-Path $here $cfg.rutas.log
$kmlPath    = Join-Path $here $cfg.rutas.kmlSalida
$estadoPath = Join-Path $here $cfg.rutas.estado
$estPath    = Join-Path $here $cfg.rutas.estaciones

function Write-Log { param($m) Add-Content -Path $logPath -Value ("{0}  {1}" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss"), $m) -Encoding UTF8 }

try {
    $codigos = Get-Content $estPath -Raw | ConvertFrom-Json
    if ($MaxEstaciones -gt 0) { $codigos = $codigos | Select-Object -First $MaxEstaciones }

    # estado previo (acumulados + timestamp por codigo)
    $prev = @{}
    if (Test-Path $estadoPath) {
        $pj = Get-Content $estadoPath -Raw | ConvertFrom-Json
        foreach ($p in $pj.PSObject.Properties) { $prev[$p.Name] = $p.Value }
    }

    $ahora = Get-Date
    $placemarks = New-Object System.Collections.Generic.List[string]
    $nuevoEstado = @{}
    $ok = 0; $fallidas = 0

    foreach ($cod in $codigos) {
        $codStr = [string]$cod
        try {
            $url = "https://climatologia.meteochile.gob.cl/application/diariob/visorDeDatosEma/$codStr"
            $resp = Invoke-WebRequest -UseBasicParsing -Uri $url -TimeoutSec $cfg.scraping.timeoutSeg -UserAgent $cfg.scraping.userAgent
            $html = $resp.Content

            $info  = Get-EmaInfo -Html $html
            $temp  = Get-EmaTempActual -Html $html
            $precH = Get-EmaPrecipHoy -Html $html

            if ($null -eq $info.Lat -or $null -eq $info.Lon) { $fallidas++; continue }

            $iso = if ($null -ne $temp -and $null -ne $info.Altitud) {
                Get-FreezingLevel -AltitudM $info.Altitud -TempC $temp -GradienteCkm $cfg.umbrales.gradienteCkm
            } else { $null }

            # tasa de precipitacion contra corrida previa
            $precRate = $null
            if ($prev.ContainsKey($codStr) -and $null -ne $precH) {
                $precRate = Get-PrecipRate -PrecipActual $precH -TiempoActual $ahora `
                    -PrecipPrev $prev[$codStr].precip -TiempoPrev ([datetime]$prev[$codStr].tiempo)
            }

            $nivel = Get-AlertLevel -PrecipRate $precRate -FreezingLevel $iso -Umbrales $cfg.umbrales
            $motivo = switch ($nivel) {
                'rojo'     { "ALUVION: $precRate mm/h e isoterma 0C $iso m" }
                'amarillo' { "Atencion: $precRate mm/h / isoterma 0C $iso m" }
                'gris'     { "Sin datos recientes" }
                default    { "Normal" }
            }

            $placemarks.Add((New-Placemark -Estacion ([pscustomobject]@{
                Nombre=$info.Nombre; Codigo=$codStr; Lat=$info.Lat; Lon=$info.Lon
                Nivel=$nivel; PrecipRate=$precRate; TempC=$temp; FreezingLevel=$iso
                Momento=$info.UltimoDato; Motivo=$motivo
            })))

            if ($null -ne $precH) {
                $nuevoEstado[$codStr] = @{ precip = $precH; tiempo = $ahora.ToString('o') }
            }
            $ok++
        }
        catch { $fallidas++; Write-Log "WARN estacion $codStr : $($_.Exception.Message)" }

        Start-Sleep -Milliseconds $cfg.scraping.throttleMs
    }

    if ($placemarks.Count -eq 0) { throw "0 estaciones procesadas; se conserva el KML anterior" }

    # escritura atomica del KML
    $kml = ConvertTo-Kml -Placemarks $placemarks -GeneradoUtc $ahora.ToUniversalTime().ToString("yyyy-MM-dd HH:mm:ss")
    $tmp = "$kmlPath.tmp"
    Set-Content -Path $tmp -Value $kml -Encoding UTF8
    Move-Item -Path $tmp -Destination $kmlPath -Force

    # guardar estado para la proxima tasa
    ($nuevoEstado | ConvertTo-Json -Depth 4) | Set-Content -Path $estadoPath -Encoding UTF8

    Write-Log "OK: $ok estaciones, $fallidas fallidas, $($placemarks.Count) placemarks"
    Write-Host "OK: $ok estaciones ($fallidas fallidas) -> $kmlPath"
}
catch {
    Write-Log "ERROR: $($_.Exception.Message)"
    Write-Error $_.Exception.Message
    exit 1
}
