[CmdletBinding()]
param(
    [string]$Grupo = "EMAPublicadas",
    [string]$Salida = (Join-Path $PSScriptRoot "estaciones.json")
)
$url = "https://climatologia.meteochile.gob.cl/application/informacion/estacionesEnGrupo/$Grupo"
$r = Invoke-WebRequest -UseBasicParsing -Uri $url -TimeoutSec 60
$codigos = [regex]::Matches($r.Content, '(?:visorDeDatosEma|fichaDeEstacion)/(\d+)') |
    ForEach-Object { $_.Groups[1].Value } | Select-Object -Unique | Sort-Object { [int]$_ }
if ($codigos.Count -lt 1) { throw "No se encontraron codigos en el grupo $Grupo" }
$codigos | ConvertTo-Json | Set-Content -Path $Salida -Encoding UTF8
Write-Host "Guardadas $($codigos.Count) estaciones en $Salida"
