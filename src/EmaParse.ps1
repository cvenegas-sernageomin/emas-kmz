function Get-EmaInfo {
    param([string]$Html)

    $opt = [System.Text.RegularExpressions.RegexOptions]::Singleline

    $nombre = $null
    $mN = [regex]::Match($Html, '<h1>\s*([^<]+?)\s*</h1>\s*<h4>\s*<small>\s*Altura', $opt)
    if ($mN.Success) { $nombre = $mN.Groups[1].Value.Trim() }

    $alt = $null
    $mA = [regex]::Match($Html, 'Altura\s*:\s*([\d.]+)\s*mts')
    if ($mA.Success) { $alt = [double]$mA.Groups[1].Value }

    # Coordenadas: dos decimales con signo separados por coma; se ignora el simbolo de grado
    $lat = $null; $lon = $null
    $mC = [regex]::Match($Html, 'Coordenadas\s*:\s*(-?[\d.]+)[^,\d-]*,\s*(-?[\d.]+)')
    if ($mC.Success) { $lat = [double]$mC.Groups[1].Value; $lon = [double]$mC.Groups[2].Value }

    $ultimo = $null
    $mU = [regex]::Match($Html, '<h1>\s*(\d{1,2}:\d{2})\s*<small>\s*([^<]+?)\s*</small>\s*</h1>')
    if ($mU.Success) { $ultimo = ($mU.Groups[1].Value + ' ' + $mU.Groups[2].Value).Trim() }

    return [pscustomobject]@{
        Nombre = $nombre; Altitud = $alt; Lat = $lat; Lon = $lon; UltimoDato = $ultimo
    }
}

function Get-EmaTempActual {
    param([string]$Html)
    $opt = [System.Text.RegularExpressions.RegexOptions]::Singleline
    $m = [regex]::Match($Html, "chart\('temperatura'.*?series:\s*\[\{\s*name:\s*'[^']*',\s*data:\s*\[([^\]]*)\]", $opt)
    if (-not $m.Success) { return $null }
    $valores = $m.Groups[1].Value -split ','
    for ($i = $valores.Count - 1; $i -ge 0; $i--) {
        $v = $valores[$i].Trim()
        if ($v -and $v -ne 'null') { return [double]$v }
    }
    return $null
}

function Get-EmaPrecipHoy {
    param([string]$Html)
    $opt = [System.Text.RegularExpressions.RegexOptions]::Singleline
    $m = [regex]::Match($Html, '<h4>\s*Hoy\s*</h4>\s*</td>\s*<td[^>]*>\s*<h4>\s*([^<]+?)\s*</h4>', $opt)
    if (-not $m.Success) { return $null }
    $txt = $m.Groups[1].Value.Trim()
    if ($txt -match '(?i)^s/?p') { return 0.0 }
    $n = [regex]::Match($txt, '-?\d+([.,]\d+)?')
    if (-not $n.Success) { return $null }
    return [double]($n.Value -replace ',', '.')
}
