# EMAs Chile → KMZ en tiempo casi-real (sin token)

Muestra las Estaciones Meteorológicas Automáticas (EMAs) de la DMC en Google Earth Pro,
actualizándose cada 15 min, con alertas por tasa de precipitación (mm/h) e isoterma
0°C estimada (riesgo de aluvión). Usa el **visor público** de la DMC; **no requiere cuenta ni token**.

## Puesta en marcha (una sola vez)

1. Genera la lista de estaciones: `.\Construir-ListaEstaciones.ps1` (crea `estaciones.json`, ~149 EMAs).
2. Primera corrida: `.\Actualizar-EMAs.ps1` (crea `red_ema.kml` y `estado.json`). Tarda ~2 min.
3. Genera el KMZ una vez: `.\Crear-KMZ.ps1`.
4. Abre `EMAs_Chile.kmz` en Google Earth Pro.

## Uso diario — refresco MANUAL

El refresco es manual (no hay tarea programada). Cuando quieras datos frescos:

- **Doble clic en `Actualizar.cmd`** (o corre `.\Actualizar-EMAs.ps1`). Esto vuelve a
  descargar las estaciones y reescribe `red_ema.kml`.
- En Google Earth Pro: **clic derecho sobre "EMAs Chile" → Actualizar/Refresh** para verlo
  al instante (o espera: el NetworkLink lo recarga solo cada 15 min).

Notas:
- La **tasa mm/h** aparece desde la 2ª actualización (compara dos lecturas del acumulado).
- Prueba rápida con pocas estaciones: `.\Actualizar-EMAs.ps1 -MaxEstaciones 5`.

### (Opcional) Refresco automático cada X min

Si más adelante quieres que se actualice solo, existe `Registrar-Tarea.ps1`:
`.\Registrar-Tarea.ps1 -IntervaloMin 30`.
Para quitarla: `Unregister-ScheduledTask -TaskName "EMAs-Chile-Actualizar" -Confirm:$false`

## Compartir el KMZ con otra persona

El `EMAs_Chile.kmz` normal **no es portátil**: por dentro apunta a un archivo de ESTA PC
(`file:///...`), así que en otro computador abre vacío.

Para compartir, genera un **KMZ snapshot autocontenido** (una foto del momento, un solo
archivo que funciona en cualquier PC, sin scripts):

```powershell
.\Actualizar-EMAs.ps1        # datos frescos
.\Crear-KMZ.ps1 -Snapshot    # crea EMAs_Chile_snapshot.kmz (portatil)
```

Envía **`EMAs_Chile_snapshot.kmz`**. No se actualiza solo: para mandar datos nuevos,
repites los dos comandos y reenvías el archivo.

## Configuración (`config.json`)

- `umbrales`: niveles de alerta y `gradienteCkm` (gradiente para la isoterma).
- `scraping.throttleMs`: pausa entre estaciones (cortesía con el servidor DMC).

## Niveles de alerta

La isoterma 0°C alta **solo** alerta cuando hay lluvia (una isoterma alta sin precipitación
no es peligro de aluvión).

- 🟢 **Normal**
- 🟡 **Atención**: precip ≥ 5 mm/h, **o** algo de lluvia con isoterma ≥ 2500 m
- 🔴 **Aluvión**: precip ≥ 10 mm/h **y** isoterma ≥ 3000 m
- ⚪ **Sin datos**: estación sin temperatura reciente / desactivada

## Archivos

| Archivo | Rol |
|---|---|
| `Construir-ListaEstaciones.ps1` | Arma `estaciones.json` desde el grupo público `EMAPublicadas` |
| `Actualizar-EMAs.ps1` | Descarga, parsea, calcula y regenera `red_ema.kml` |
| `Crear-KMZ.ps1` | Genera `EMAs_Chile.kmz` (NetworkLink que recarga el KML) |
| `Registrar-Tarea.ps1` | Crea la tarea programada de usuario cada 15 min |
| `src/EmaParse.ps1` | Parseo del HTML del visor |
| `src/EmaFunctions.ps1` | Cálculo (isoterma, tasa, alerta) y generación de KML |
| `tests/` | Tests Pester (30) |

## Limitaciones

- La isoterma 0°C es una **estimación por gradiente** (6.5 °C/km) desde temp+altitud; no
  es un sondeo real.
- La tasa mm/h se calcula diferenciando el acumulado diario entre corridas.
- Se descarga el HTML público de cada estación (~380 KB × ~149); el throttle mantiene la
  carga cortés. El "tiempo real" depende de que la tarea programada corra (sesión iniciada).
- Si la DMC cambia el HTML del visor, hay que ajustar los parsers en `src/EmaParse.ps1`
  (los tests con el fixture lo seguirán pasando, pero la descarga real fallaría; se detecta
  en `actualizar.log`).
