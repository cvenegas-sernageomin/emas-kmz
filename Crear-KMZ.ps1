[CmdletBinding()]
param(
    [string]$KmlObjetivo,
    [string]$KmzSalida,
    [int]$IntervaloSeg   = 900,
    [switch]$Snapshot    # KMZ autocontenido (portatil) en vez de NetworkLink local
)
$here = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Path }
if (-not $KmlObjetivo) { $KmlObjetivo = Join-Path $here "red_ema.kml" }
if (-not $KmzSalida) {
    $nombreKmz = if ($Snapshot) { "EMAs_Chile_snapshot.kmz" } else { "EMAs_Chile.kmz" }
    $KmzSalida = Join-Path $here $nombreKmz
}
Add-Type -AssemblyName System.IO.Compression.FileSystem

if ($Snapshot) {
    # KMZ portatil: incrusta el KML actual como doc.kml (foto del momento, sin rutas locales)
    if (-not (Test-Path $KmlObjetivo)) { throw "No existe $KmlObjetivo. Corre Actualizar-EMAs.ps1 primero." }
    $docKml = Get-Content -LiteralPath $KmlObjetivo -Raw
} else {
    # KMZ local: NetworkLink que recarga el red_ema.kml de ESTA carpeta
    $carpeta = (Resolve-Path -LiteralPath (Split-Path $KmlObjetivo -Parent)).Path
    $hrefUri = ([uri]$carpeta).AbsoluteUri.TrimEnd('/') + '/' + (Split-Path $KmlObjetivo -Leaf)
    $docKml = @"
<?xml version="1.0" encoding="UTF-8"?>
<kml xmlns="http://www.opengis.net/kml/2.2">
 <Document>
  <name>EMAs Chile (tiempo casi-real)</name>
  <NetworkLink>
    <name>Estaciones DMC</name>
    <Link>
      <href>$hrefUri</href>
      <refreshMode>onInterval</refreshMode>
      <refreshInterval>$IntervaloSeg</refreshInterval>
    </Link>
  </NetworkLink>
 </Document>
</kml>
"@
}

$tmpDir = Join-Path $env:TEMP ("kmz_" + [guid]::NewGuid())
New-Item -ItemType Directory -Force $tmpDir | Out-Null
Set-Content -Path (Join-Path $tmpDir "doc.kml") -Value $docKml -Encoding UTF8
if (Test-Path $KmzSalida) { Remove-Item $KmzSalida -Force }
[System.IO.Compression.ZipFile]::CreateFromDirectory($tmpDir, $KmzSalida)
Remove-Item $tmpDir -Recurse -Force

if ($Snapshot) {
    Write-Host "KMZ portatil (snapshot) creado: $KmzSalida  -- comparte ESTE archivo."
} else {
    Write-Host "KMZ local creado: $KmzSalida (NetworkLink, solo funciona en esta PC)."
}
