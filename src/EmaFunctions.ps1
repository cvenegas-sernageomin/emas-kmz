function Get-FreezingLevel {
    param([double]$AltitudM, [double]$TempC, [double]$GradienteCkm = 6.5)
    return [math]::Round($AltitudM + ($TempC / $GradienteCkm) * 1000, 0)
}

function Get-PrecipRate {
    param($PrecipActual, [datetime]$TiempoActual, $PrecipPrev, $TiempoPrev)
    if ($null -eq $PrecipActual -or $null -eq $PrecipPrev -or $null -eq $TiempoPrev) { return $null }
    $horas = ($TiempoActual - [datetime]$TiempoPrev).TotalHours
    if ($horas -le 0) { return $null }
    $delta = [double]$PrecipActual - [double]$PrecipPrev
    if ($delta -lt 0) { $delta = 0 }   # reset de medianoche
    return [math]::Round($delta / $horas, 2)
}

function Get-AlertLevel {
    param($PrecipRate, $FreezingLevel, $Umbrales)
    if ($null -eq $FreezingLevel) { return 'gris' }   # sin temperatura = sin dato reciente
    $p = if ($null -ne $PrecipRate) { [double]$PrecipRate } else { 0.0 }
    $iso = [double]$FreezingLevel
    if ($p -ge $Umbrales.rojoPrecip -and $iso -ge $Umbrales.rojoIso) { return 'rojo' }
    if ($p -ge $Umbrales.amarilloPrecip -or $iso -ge $Umbrales.amarilloIso) { return 'amarillo' }
    return 'verde'
}

function New-Placemark {
    param($Estacion)
    $nombreEsc = [System.Security.SecurityElement]::Escape([string]$Estacion.Nombre)
    $precipTxt = if ($null -ne $Estacion.PrecipRate) { "$($Estacion.PrecipRate) mm/h" } else { [char]0x2014 }
    $desc = @"
<![CDATA[
<b>$($Estacion.Nombre)</b> (codigo $($Estacion.Codigo))<br/>
Precipitacion: $precipTxt<br/>
Temperatura: $($Estacion.TempC) C<br/>
Isoterma 0C (estimada por gradiente): $($Estacion.FreezingLevel) m<br/>
Ultimo dato: $($Estacion.Momento)<br/>
Alerta: $($Estacion.Motivo)
]]>
"@
    return @"
  <Placemark>
    <name>$nombreEsc</name>
    <styleUrl>#nivel-$($Estacion.Nivel)</styleUrl>
    <description>$desc</description>
    <Point><coordinates>$($Estacion.Lon),$($Estacion.Lat),0</coordinates></Point>
  </Placemark>
"@
}

function ConvertTo-Kml {
    param($Placemarks, [string]$GeneradoUtc)
    # Colores KML en formato aabbggrr
    $estilos = @'
  <Style id="nivel-verde"><IconStyle><color>ff00ff00</color><scale>1.1</scale><Icon><href>http://maps.google.com/mapfiles/kml/shapes/placemark_circle.png</href></Icon></IconStyle></Style>
  <Style id="nivel-amarillo"><IconStyle><color>ff00ffff</color><scale>1.2</scale><Icon><href>http://maps.google.com/mapfiles/kml/shapes/placemark_circle.png</href></Icon></IconStyle></Style>
  <Style id="nivel-rojo"><IconStyle><color>ff0000ff</color><scale>1.4</scale><Icon><href>http://maps.google.com/mapfiles/kml/shapes/placemark_circle.png</href></Icon></IconStyle></Style>
  <Style id="nivel-gris"><IconStyle><color>ff888888</color><scale>0.9</scale><Icon><href>http://maps.google.com/mapfiles/kml/shapes/placemark_circle.png</href></Icon></IconStyle></Style>
'@
    $body = ($Placemarks -join "`n")
    return @"
<?xml version="1.0" encoding="UTF-8"?>
<kml xmlns="http://www.opengis.net/kml/2.2">
 <Document>
  <name>EMAs Chile - generado $GeneradoUtc UTC</name>
$estilos
$body
 </Document>
</kml>
"@
}
