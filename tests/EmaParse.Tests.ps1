. "$PSScriptRoot\..\src\EmaParse.ps1"

$html = Get-Content "$PSScriptRoot\..\fixtures\ema_330020.html" -Raw

Describe "Get-EmaInfo (fixture real 330020)" {
    $info = Get-EmaInfo -Html $html
    It "extrae el nombre" { $info.Nombre | Should Be "Quinta Normal, Santiago" }
    It "extrae la altitud" { $info.Altitud | Should Be 520.0 }
    It "extrae la latitud" { $info.Lat | Should Be -33.445 }
    It "extrae la longitud" { $info.Lon | Should Be -70.68278 }
    It "extrae la hora del ultimo dato (string)" { $info.UltimoDato | Should Match '\d{1,2}:\d{2}' }
}

Describe "Get-EmaTempActual" {
    It "toma el ultimo valor no nulo de la serie (snippet sintetico)" {
        $snip = "Highcharts.chart('temperatura', { xAxis: { categories: [`"00:00`",`"00:01`"] }, series: [{ name: '15-06-2026', data: [7.5,8.1,9.0,null,null] }, { name: '14-06-2026', data: [1,2,3] }] });"
        Get-EmaTempActual -Html $snip | Should Be 9.0
    }
    It "devuelve un numero (no null) sobre el fixture real" {
        $real = Get-EmaTempActual -Html $html
        $real | Should Not BeNullOrEmpty
        ($real -is [double]) | Should Be $true
    }
    It "devuelve null si no hay datos" {
        Get-EmaTempActual -Html "sin grafico" | Should Be $null
    }
}

Describe "Get-EmaPrecipHoy" {
    It "interpreta s/p como 0.0 (fixture real)" {
        Get-EmaPrecipHoy -Html $html | Should Be 0.0
    }
    It "extrae un valor numerico en mm (snippet sintetico)" {
        $snip = "<h4> Hoy </h4></td><td class='text-center'><h4> 12.4</h4></td>"
        Get-EmaPrecipHoy -Html $snip | Should Be 12.4
    }
    It "devuelve null si no encuentra la fila Hoy" {
        Get-EmaPrecipHoy -Html "<table></table>" | Should Be $null
    }
}
