[CmdletBinding()]
param(
    [string]$KmlObjetivo = (Join-Path $PSScriptRoot "red_ema.kml"),
    [string]$KmzSalida   = (Join-Path $PSScriptRoot "EMAs_Chile.kmz"),
    [int]$IntervaloSeg   = 900
)
Add-Type -AssemblyName System.IO.Compression.FileSystem

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

$tmpDir = Join-Path $env:TEMP ("kmz_" + [guid]::NewGuid())
New-Item -ItemType Directory -Force $tmpDir | Out-Null
Set-Content -Path (Join-Path $tmpDir "doc.kml") -Value $docKml -Encoding UTF8
if (Test-Path $KmzSalida) { Remove-Item $KmzSalida -Force }
[System.IO.Compression.ZipFile]::CreateFromDirectory($tmpDir, $KmzSalida)
Remove-Item $tmpDir -Recurse -Force
Write-Host "KMZ creado: $KmzSalida -> $hrefUri (refresco ${IntervaloSeg}s)"
