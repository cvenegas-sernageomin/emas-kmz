[CmdletBinding()]
param(
    [string]$KmlObjetivo,
    [string]$KmzSalida,
    [int]$IntervaloSeg   = 900,
    [switch]$Snapshot,   # KMZ autocontenido (portatil), foto del momento
    [switch]$Online,     # KMZ con NetworkLink a la URL publica de GitHub (compartible + dinamico)
    [string]$RawUrl      # opcional: forzar la URL; si no, se deriva del remoto git
)
$here = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Path }
if (-not $KmlObjetivo) { $KmlObjetivo = Join-Path $here "red_ema.kml" }
if (-not $KmzSalida) {
    $nombreKmz = if ($Snapshot) { "EMAs_Chile_snapshot.kmz" } elseif ($Online) { "EMAs_Chile_online.kmz" } else { "EMAs_Chile.kmz" }
    $KmzSalida = Join-Path $here $nombreKmz
}
Add-Type -AssemblyName System.IO.Compression.FileSystem

if ($Snapshot) {
    # Portatil: incrusta el KML actual como doc.kml (foto del momento, sin rutas ni red)
    if (-not (Test-Path $KmlObjetivo)) { throw "No existe $KmlObjetivo. Corre Actualizar-EMAs.ps1 primero." }
    $docKml = Get-Content -LiteralPath $KmlObjetivo -Raw
}
elseif ($Online) {
    # Compartible + dinamico: NetworkLink a la URL publica (rama live de GitHub)
    if (-not $RawUrl) {
        $remote = (git -C $here config --get remote.origin.url) 2>$null
        if (-not $remote) { throw "No hay remoto git. Corre Configurar-Online.ps1 primero, o pasa -RawUrl." }
        if ($remote -match 'github\.com[:/]+([^/]+)/([^/.]+)') {
            $RawUrl = "https://raw.githubusercontent.com/$($Matches[1])/$($Matches[2])/live/red_ema.kml"
        } else { throw "No pude derivar la URL desde el remoto: $remote. Pasa -RawUrl manualmente." }
    }
    $docKml = @"
<?xml version="1.0" encoding="UTF-8"?>
<kml xmlns="http://www.opengis.net/kml/2.2">
 <Document>
  <name>EMAs Chile (en linea)</name>
  <NetworkLink>
    <name>Estaciones DMC</name>
    <Link>
      <href>$RawUrl</href>
      <refreshMode>onInterval</refreshMode>
      <refreshInterval>$IntervaloSeg</refreshInterval>
    </Link>
  </NetworkLink>
 </Document>
</kml>
"@
}
else {
    # Local: NetworkLink que recarga el red_ema.kml de ESTA carpeta (solo esta PC)
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

if ($Snapshot)    { Write-Host "KMZ portatil (snapshot) creado: $KmzSalida  -- comparte ESTE archivo." }
elseif ($Online)  { Write-Host "KMZ online creado: $KmzSalida -> $RawUrl  -- compartible y dinamico." }
else              { Write-Host "KMZ local creado: $KmzSalida (NetworkLink local, solo esta PC)." }
