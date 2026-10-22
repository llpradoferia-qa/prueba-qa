# Ejecuta los casos de API de 03-casos-caja-negra.md y guarda el resultado como evidencia.
# Uso (desde la raíz del repo):
#   powershell -ExecutionPolicy Bypass -File qa\evidencias\casos-api.ps1

$base = "http://localhost:8080/api/v1"
$salida = Join-Path $PSScriptRoot "casos-api-resultado.txt"
Start-Transcript -Path $salida -Force | Out-Null

# Hace una llamada HTTP y devuelve el código de estado y el cuerpo, aunque sea un error.
function Llamar($metodo, $ruta, $body, $token) {
  $headers = @{}
  if ($token) { $headers.Authorization = "Bearer $token" }
  $p = @{ Method = $metodo; Uri = "$base$ruta"; Headers = $headers; ContentType = "application/json"; UseBasicParsing = $true }
  if ($body) { $p.Body = [System.Text.Encoding]::UTF8.GetBytes($body) }
  try {
    $r = Invoke-WebRequest @p
    return [pscustomobject]@{ Status = [int]$r.StatusCode; Body = $r.Content }
  } catch {
    return [pscustomobject]@{ Status = [int]$_.Exception.Response.StatusCode; Body = $_.ErrorDetails.Message }
  }
}

# Imprime una línea por caso: ID, dato usado, HTTP y un resumen de la respuesta.
function Mostrar($id, $dato, $r) {
  $resumen = $r.Body
  try {
    $j = $r.Body | ConvertFrom-Json
    if ($null -ne $j.rows) { $resumen = "count=$($j.count) filas=[" + (($j.rows | ForEach-Object { "$($_.meter_id):$($_.status)" }) -join ", ") + "]" }
    elseif ($j.access_token) { $resumen = "access_token recibido, token_type=$($j.token_type), expires_in=$($j.expires_in)" }
    elseif ($j.message) { $resumen = "$($j.message) $($j.errors -join '; ')" }
    elseif ($j.meter_id) { $resumen = "meter_id=$($j.meter_id) status=$($j.status) consumo=$($j.consumption_kwh) baseline=$($j.baseline_kwh) variacion=$($j.variation_pct)" }
  } catch {}
  if ($resumen.Length -gt 220) { $resumen = $resumen.Substring(0, 220) + "..." }
  Write-Output ("{0,-9} | {1,-48} | HTTP {2} | {3}" -f $id, $dato, $r.Status, $resumen)
}

function Lista($id, $dato, $body) { Mostrar $id $dato (Llamar "POST" "/meter/getAll" $body $script:token) }

Write-Output "Ejecución: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') · Zona: $((Get-TimeZone).Id)"
Write-Output ""

Write-Output "=== CN-01 Login (partición de equivalencia) ==="
$casosLogin = @(
  @("CN-01.1", "V1 válido",                '{"email":"admin@energia.local","password":"admin123"}'),
  @("CN-01.2", "V2 email mayúsculas",      '{"email":"ADMIN@energia.local","password":"admin123"}'),
  @("CN-01.3", "V3 email con espacios",    '{"email":" admin@energia.local ","password":"admin123"}'),
  @("CN-01.4", "I1 password incorrecta",   '{"email":"admin@energia.local","password":"wrong"}'),
  @("CN-01.5", "I2 password mayúsculas",   '{"email":"admin@energia.local","password":"ADMIN123"}'),
  @("CN-01.6", "I3 password un char menos",'{"email":"admin@energia.local","password":"admin12"}'),
  @("CN-01.7", "I4 password espacio final",'{"email":"admin@energia.local","password":"admin123 "}'),
  @("CN-01.8", "I5 email inexistente",     '{"email":"noexiste@x.com","password":"admin123"}'),
  @("CN-01.9", "I6 campos vacíos",         '{"email":"","password":""}'),
  @("CN-01.10","I7 body mal formado",      '{bad json')
)
foreach ($c in $casosLogin) { Mostrar $c[0] $c[1] (Llamar "POST" "/auth/login" $c[2] $null) }

$login = (Llamar "POST" "/auth/login" '{"email":"admin@energia.local","password":"admin123"}' $null).Body | ConvertFrom-Json
$script:token = $login.access_token

Write-Output ""
Write-Output "=== CN-03 Token ==="
Mostrar "CN-03.1" "sin token"      (Llamar "GET" "/auth/me" $null $null)
Mostrar "CN-03.2" "token alterado" (Llamar "GET" "/auth/me" $null "abc")
Mostrar "CN-03.3" "token válido"   (Llamar "GET" "/auth/me" $null $script:token)

Write-Output ""
Write-Output "=== CN-04 size (valores límite) ==="
Lista "CN-04.1" "size 0 (no enviado)" '{"pagination":{"page":1,"size":0}}'
Lista "CN-04.2" "size 1"              '{"pagination":{"page":1,"size":1}}'
Lista "CN-04.3" "size 100"            '{"pagination":{"page":1,"size":100}}'
Lista "CN-04.4" "size 101"            '{"pagination":{"page":1,"size":101}}'
Lista "CN-04.5" "size -1"             '{"pagination":{"page":1,"size":-1}}'

Write-Output ""
Write-Output "=== CN-05 page (valores límite) ==="
Lista "CN-05.1" "page 0 (no enviado)" '{"pagination":{"page":0,"size":10}}'
Lista "CN-05.2" "page 1"              '{"pagination":{"page":1,"size":10}}'
Lista "CN-05.3" "page 2 (última)"     '{"pagination":{"page":2,"size":10}}'
Lista "CN-05.4" "page 3 (después)"    '{"pagination":{"page":3,"size":10}}'
Lista "CN-05.5" "page -1"             '{"pagination":{"page":-1,"size":10}}'

Write-Output ""
Write-Output "=== CN-06 Filtro por estado ==="
Lista "CN-06.1" "NORMAL"          '{"pagination":{"size":100},"filter":{"status":"NORMAL"}}'
Lista "CN-06.2" "ALERT"           '{"pagination":{"size":100},"filter":{"status":"ALERT"}}'
Lista "CN-06.3" "CRITICAL"        '{"pagination":{"size":100},"filter":{"status":"CRITICAL"}}'
Lista "CN-06.4" "alert minúsculas" '{"pagination":{"size":100},"filter":{"status":"alert"}}'
Lista "CN-06.5" "ROJO"            '{"pagination":{"size":100},"filter":{"status":"ROJO"}}'
Lista "CN-06.6" "sin status"      '{"pagination":{"size":100}}'

Write-Output ""
Write-Output "=== CN-07 Búsqueda por medidor ==="
$id50 = "X" * 50
$id51 = "X" * 51
Lista "CN-07.1" "M-109"              '{"filter":{"meter_id":"M-109"}}'
Lista "CN-07.2" "109 (parcial)"      '{"filter":{"meter_id":"109"}}'
Lista "CN-07.3" "m-109 (minúsculas)" '{"filter":{"meter_id":"m-109"}}'
Lista "CN-07.4" "M-11 (prefijo)"     '{"filter":{"meter_id":"M-11"}}'
Lista "CN-07.5" "M-999 (inexistente)" '{"filter":{"meter_id":"M-999"}}'
Lista "CN-07.6" "con espacios"       '{"filter":{"meter_id":"  M-109  "}}'
Lista "CN-07.7" "50 caracteres"      ('{"filter":{"meter_id":"' + $id50 + '"}}')
Lista "CN-07.8" "51 caracteres"      ('{"filter":{"meter_id":"' + $id51 + '"}}')

Write-Output ""
Write-Output "=== CN-08 Ordenamiento ==="
Lista "CN-08.1" "severity DESC"     '{"pagination":{"size":100},"filter":{"sort_by":"severity","sort_order":"DESC"}}'
Lista "CN-08.2" "variation ASC"     '{"pagination":{"size":100},"filter":{"sort_by":"variation","sort_order":"ASC"}}'
Lista "CN-08.3" "consumption DESC"  '{"pagination":{"size":100},"filter":{"sort_by":"consumption","sort_order":"DESC"}}'
Lista "CN-08.4" "desc minúsculas"   '{"pagination":{"size":100},"filter":{"sort_order":"desc"}}'
Lista "CN-08.5" "sort_by precio"    '{"filter":{"sort_by":"precio"}}'

Write-Output ""
Write-Output "=== CN-09 Combinación de filtros ==="
Lista "CN-09.1" "CRITICAL + M-104"          '{"filter":{"status":"CRITICAL","meter_id":"M-104"}}'
Lista "CN-09.2" "CRITICAL + consumo DESC"   '{"filter":{"status":"CRITICAL","sort_by":"consumption","sort_order":"DESC"}}'
Lista "CN-09.3" "NORMAL + M-106"            '{"filter":{"status":"NORMAL","meter_id":"M-106"}}'

Write-Output ""
Write-Output "=== CN-10 Estado por medidor (tabla de decisión) ==="
foreach ($m in @("M-101", "M-106", "M-109", "M-112", "M-104")) {
  Mostrar "CN-10" $m (Llamar "GET" "/meter/getById/$m" $null $script:token)
}

Write-Output ""
Write-Output "=== CN-11 / CN-14 Anomalías: tipo, severidad, prioridad y hora de detección ==="
$anom = (Llamar "GET" "/anomaly/getAll" $null $script:token).Body | ConvertFrom-Json
Write-Output "prioridad | medidor | tipo                | severidad | confianza | anomalia | detected_at (API)"
foreach ($a in @($anom)) {
  Write-Output ("{0,-9} | {1,-7} | {2,-19} | {3,-9} | {4,-9} | {5,-8} | {6}" -f $a.priority, $a.meter_id, $a.type, $a.severity, $a.confidence, $a.anomaly, $a.detected_at)
}

Write-Output "=== CN-13 Resumen del dashboard ==="
$dash = (Llamar "GET" "/dashboard/getSummary" $null $script:token).Body | ConvertFrom-Json
Write-Output "status_counts: normal=$($dash.status_counts.normal) alert=$($dash.status_counts.alert) critical=$($dash.status_counts.critical)"
Write-Output "consumo: last_day_kwh=$($dash.consumption.last_day_kwh) baseline_daily_kwh=$($dash.consumption.baseline_daily_kwh) variation_pct=$($dash.consumption.variation_pct)"
Write-Output "data_range: $($dash.data_range.from) -> $($dash.data_range.to)"

Write-Output ""
Write-Output "=== CN-18 Detalle por ID ==="
Mostrar "CN-18.1" "M-109" (Llamar "GET" "/meter/getById/M-109" $null $script:token)
Mostrar "CN-18.2" "m-109" (Llamar "GET" "/meter/getById/m-109" $null $script:token)
Mostrar "CN-18.3" "M-999" (Llamar "GET" "/meter/getById/M-999" $null $script:token)

Write-Output ""
Write-Output "=== CN-20 Análisis inexistente ==="
Mostrar "CN-20.3" "AN-9999" (Llamar "GET" "/ai/analysis/AN-9999" $null $script:token)

Stop-Transcript | Out-Null
Write-Host ""
Write-Host "Resultado guardado en $salida"
