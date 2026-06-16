. "$PSScriptRoot\..\src\EmaFunctions.ps1"

Describe "Get-FreezingLevel" {
    It "estima la isoterma 0C por gradiente" {
        Get-FreezingLevel -AltitudM 520 -TempC 13 -GradienteCkm 6.5 | Should Be 2520
    }
    It "con 0C devuelve la altitud de la estacion" {
        Get-FreezingLevel -AltitudM 1500 -TempC 0 -GradienteCkm 6.5 | Should Be 1500
    }
    It "con temperatura negativa queda bajo la estacion" {
        Get-FreezingLevel -AltitudM 2000 -TempC -6.5 -GradienteCkm 6.5 | Should Be 1000
    }
}

Describe "Get-PrecipRate" {
    It "calcula mm/h entre dos corridas (2.5 mm en 15 min = 10 mm/h)" {
        $t0 = [datetime]"2026-06-15 10:00"; $t1 = [datetime]"2026-06-15 10:15"
        Get-PrecipRate -PrecipActual 2.5 -TiempoActual $t1 -PrecipPrev 0.0 -TiempoPrev $t0 | Should Be 10
    }
    It "trunca a 0 cuando el acumulado se resetea (delta negativo)" {
        $t0 = [datetime]"2026-06-15 23:55"; $t1 = [datetime]"2026-06-16 00:10"
        Get-PrecipRate -PrecipActual 0.0 -TiempoActual $t1 -PrecipPrev 8.0 -TiempoPrev $t0 | Should Be 0
    }
    It "devuelve null si no hay corrida previa" {
        Get-PrecipRate -PrecipActual 3.0 -TiempoActual ([datetime]"2026-06-15 10:15") -PrecipPrev $null -TiempoPrev $null | Should Be $null
    }
}

Describe "Get-AlertLevel" {
    $umbrales = [pscustomobject]@{ amarilloPrecip=5.0; amarilloIso=2500.0; rojoPrecip=10.0; rojoIso=3000.0 }
    It "rojo: precip alta Y isoterma alta (combo aluvion)" {
        Get-AlertLevel -PrecipRate 12 -FreezingLevel 3100 -Umbrales $umbrales | Should Be "rojo"
    }
    It "amarillo: solo precip sobre umbral" {
        Get-AlertLevel -PrecipRate 6 -FreezingLevel 1000 -Umbrales $umbrales | Should Be "amarillo"
    }
    It "amarillo: solo isoterma sobre umbral" {
        Get-AlertLevel -PrecipRate 1 -FreezingLevel 2600 -Umbrales $umbrales | Should Be "amarillo"
    }
    It "verde: todo bajo umbral" {
        Get-AlertLevel -PrecipRate 1 -FreezingLevel 1000 -Umbrales $umbrales | Should Be "verde"
    }
    It "verde: estacion viva sin tasa aun (precip null, isoterma presente)" {
        Get-AlertLevel -PrecipRate $null -FreezingLevel 1000 -Umbrales $umbrales | Should Be "verde"
    }
    It "gris: sin temperatura (isoterma null)" {
        Get-AlertLevel -PrecipRate $null -FreezingLevel $null -Umbrales $umbrales | Should Be "gris"
    }
}

Describe "New-Placemark" {
    $est = [pscustomobject]@{
        Nombre="Quinta Normal"; Codigo=330020; Lat=-33.445; Lon=-70.68278
        Nivel="rojo"; PrecipRate=12; TempC=14; FreezingLevel=3100
        Momento="18:10 15 Jun 2026"; Motivo="combo aluvion"
    }
    $pm = New-Placemark -Estacion $est
    It "usa el estilo del nivel" { $pm | Should Match "#nivel-rojo" }
    It "incluye coordenadas lon,lat" { $pm | Should Match "-70.68278,-33.445" }
    It "incluye el nombre" { $pm | Should Match "Quinta Normal" }
    It "muestra guion cuando PrecipRate es null" {
        $est2 = $est.PsObject.Copy(); $est2.PrecipRate = $null
        $dash = [char]0x2014
        (New-Placemark -Estacion $est2) | Should Match "Precipitacion: $dash"
    }
}

Describe "ConvertTo-Kml" {
    $pm = New-Placemark -Estacion ([pscustomobject]@{
        Nombre="X"; Codigo=1; Lat=-33; Lon=-70; Nivel="verde"
        PrecipRate=0; TempC=10; FreezingLevel=2000; Momento="18:10 15 Jun 2026"; Motivo="normal"
    })
    $kml = ConvertTo-Kml -Placemarks @($pm) -GeneradoUtc "2026-06-15 22:10:00"
    It "produce XML bien formado" { { [xml]$kml } | Should Not Throw }
    It "define los 4 estilos" {
        $kml | Should Match "nivel-verde"; $kml | Should Match "nivel-amarillo"
        $kml | Should Match "nivel-rojo";  $kml | Should Match "nivel-gris"
    }
}
