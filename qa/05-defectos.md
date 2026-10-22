# 05 · Reporte de defectos

## Entorno común

| Dato | Valor |
|---|---|
| Build | commit `15765d9` (rama `main` del repositorio `biaenergy/prueba-qa`) |
| Despliegue | Docker Compose local (`docker compose up -d --build`) |
| Sistema operativo | Windows 11 [completar versión] |
| Navegador | Google Chrome [completar versión] |
| Zona horaria del equipo | America/Bogota (UTC−5) · "SA Pacific Standard Time" |
| Usuario | `admin@energia.local` |
| Fecha de las pruebas | 21 de octubre de 2026 |

## Resumen

| ID | Título | Capa | Severidad | Prioridad | Casos |
|---|---|---|---|---|---|
| DEF-01 | Un falso positivo (M-106) aparece en estado "Alerta" en lugar de "Normal" | API → UI | Alta | Alta | CN-06, CN-09, CN-10, CN-13 |
| DEF-02 | Las horas de planta se convierten a la zona del navegador (−5 h en Colombia) | UI | Alta | Alta | CN-14, CN-15, CN-16 |
| DEF-05 | La paginación del Libro no permite llegar a la página 2: M-111 y M-112 (crítico) quedan ocultos | UI | Alta | Alta | SMK-09, CN-19 |
| DEF-03 | La búsqueda por medidor distingue mayúsculas, contra lo documentado | API → UI | Media | Media | CN-07 |
| DEF-04 | `page` negativo en `POST /meter/getAll` responde 500 en lugar de 400 | API | Media | Baja | CN-05 |
| OBS-01 | Tras cerrar sesión, "Atrás" puede mostrar una copia en caché de una pantalla protegida | UI | Baja | Baja | CN-03 |

**Criterio de severidad:** impacto sobre la decisión del operador (qué escalar, cuándo y dónde investigar) y sobre la integridad de los datos mostrados.
**Criterio de prioridad:** urgencia de corrección para liberar, considerando la frecuencia con que el usuario lo encuentra.

---

## DEF-01 · Un falso positivo (M-106) aparece en estado "Alerta" en lugar de "Normal"

- **Severidad:** Alta. El operador ve como alerta un medidor que el propio motor dice "No escalar". Contamina los KPI de la planta (8 normales en vez de 9) y los filtros del Libro, lo que puede llevar a despachar una revisión innecesaria.
- **Prioridad:** Alta. Es visible en la pantalla principal (Despacho) y en todos los filtros por estado.
- **Capa:** API (el backend calcula mal el estado) → se refleja en toda la UI.

**Pasos para reproducir**
1. Iniciar sesión con `admin@energia.local` / `admin123`.
2. Abrir el Despacho y mirar "Estado de la planta" y la fila de M-106 en el Libro.
3. Ir a Medidores y elegir la pestaña "Normales" y luego "Alertas".
4. Por API: `GET /api/v1/meter/getById/M-106` y `GET /api/v1/dashboard/getSummary`.

**Datos:** medidor M-106 (tipo `FALSE_POSITIVE`, severidad `LOW`).

**Resultado esperado:** M-106 en estado `NORMAL`. Conteo de la planta: 9 normales · 1 alerta · 2 críticas.
Fuente: `backend/README.md`, tabla "Estado de alerta de un medidor": *"Sin anomalía, o `FALSE_POSITIVE` → `NORMAL`"*. El ejemplo de `GET /dashboard/getSummary` en Swagger también muestra `normal: 9, alert: 1`.

**Resultado obtenido:**
- API: `M-106 status=ALERT`, y la misma respuesta de `/anomaly/getAll` dice `anomaly: false` para M-106.
- `status_counts`: `normal=8 alert=2 critical=2`.
- UI: sello "Alerta" en el Libro; KPI "8 normales · 2 alerta · 2 críticas"; filtro Normales muestra 8 y Alertas muestra M-104 y M-106. La misma pantalla del Despacho se contradice: la tarjeta de M-106 dice "No escalar".
- Filtro combinado `status: NORMAL` + `meter_id: M-106` devuelve 0 resultados.

**Evidencia:** `evidencias/casos-api-resultado.txt` (CN-06, CN-09, CN-10, CN-13), `evidencias/cn-10-estado-m106.png`, `evidencias/cn-13-kpi-estados.png`.

```bash
curl -s http://localhost:8080/api/v1/meter/getById/M-106 -H "Authorization: Bearer $TOKEN"
# → {"meter_id":"M-106","status":"ALERT","severity":"LOW","anomaly_type":"FALSE_POSITIVE",...}
```

**Causa raíz probable:** `backend/internal/meter/enums.go`, función `StatusOf` (líneas 29–38). El comentario de la función dice que un falso positivo es `NORMAL`, pero el `switch` no tiene ese caso: un `FALSE_POSITIVE` con severidad `LOW` cae en `default` y devuelve `StatusAlert`.

**Cómo detectarlo automáticamente:**
- Unitario: agregar a `TestStatusOf` el caso `{"falso positivo", &model.Anomaly{Anomaly: false, Type: model.TypeFalsePositive, Severity: model.SeverityLow}, StatusNormal}`. Hoy no existe.
- El test `TestDashboardSummary` (`backend/internal/server/server_test.go`, línea 131) **valida el valor incorrecto** (`normal == 8`, `alert == 2`): hay que corregirlo a 9 / 1.
- E2E: test de Playwright que verifica el sello "Normal" de M-106 (`e2e/tests`, marcado con `test.fail()`).

---

## DEF-02 · Las horas de planta se convierten a la zona del navegador (−5 h en Colombia)

- **Severidad:** Alta. El operador investiga en sitio una ventana de tiempo equivocada: en Colombia ve 09:00 cuando el cambio empezó a las 14:00. En M-112, M-104 y M-106 hasta cambia el día. Además, la pantalla se contradice con el texto de la IA, lo que resta confianza en el producto.
- **Prioridad:** Alta. Afecta a todos los usuarios en Colombia (el 100 % de los operadores según el enunciado) y a todas las pantallas con horas.
- **Capa:** UI (la API entrega la hora correcta).

**Pasos para reproducir**
1. Equipo en zona horaria America/Bogota.
2. Abrir `/anomalias/M-109`.
3. Comparar la cabecera "Detectada … · hora de planta", el dato "Duración · Desde …" y el evento relacionado con el texto "Qué encontró la IA".
4. Abrir `/anomalias` y revisar la columna "Detectada" de los 4 medidores.
5. Repetir el paso 2 con Chrome DevTools → Sensors → Location "Other…" → Timezone ID `UTC`.

**Resultado esperado:** la hora de planta se muestra tal como viene, sin conversión: M-109 → 12/09 14:00, M-112 → 13/09 00:00, M-104 → 11/09 00:00, M-106 → 08/09 00:00; última lectura → 14/09 23:00. Igual en cualquier zona del navegador.
Fuente: `frontend/README.md`: *"Las fechas del dataset son hora de planta: se muestran tal como vienen, sin convertirlas a la zona del navegador"*. El texto de la IA y el README principal dicen "desde 12/09 14:00".

**Resultado obtenido:**

| Dato | API | UI en Bogotá | UI en UTC |
|---|---|---|---|
| M-109 detectada | `2026-09-12T14:00:00Z` | **12/09 09:00** | 12/09 14:00 |
| M-112 detectada | `2026-09-13T00:00:00Z` | **12/09 19:00** | — |
| M-104 detectada | `2026-09-11T00:00:00Z` | **10/09 19:00** | — |
| M-106 detectada | `2026-09-08T00:00:00Z` | **07/09 19:00** | — |
| Última lectura | `2026-09-14T23:00:00Z` | **14/09 18:00** | — |

En la misma pantalla de M-109: cabecera "Detectada 12/09 09:00 · hora de planta" y, dos bloques abajo, el texto "desde 12/09 14:00".

**Evidencia:** `evidencias/cn-14-hora-m109.png`, `evidencias/cn-14-anomalias-horas.png`, `evidencias/cn-16-zona-bogota.png`, `evidencias/cn-16-zona-utc.png`, `evidencias/casos-api-resultado.txt` (sección CN-11/CN-14).

**Causa raíz probable:** `frontend/src/lib/format.ts`, función `formatPlantTime` (línea 57). Usa `getDate()`, `getMonth()`, `getHours()` y `getMinutes()`, que convierten a la zona del navegador, en lugar de `getUTCDate()`, `getUTCMonth()`, `getUTCHours()` y `getUTCMinutes()`. El comentario justo encima dice "Se leen las partes UTC para NO convertirla". `formatPlantDay` sí usa las partes UTC, por eso los días del eje de las gráficas salen bien.

**Por qué los tests existentes no lo detectan:** `frontend/vite.config.ts` (línea 33) fija `TZ: 'UTC'` para Vitest. En UTC las funciones locales y las UTC dan el mismo resultado, así que el test `format.test.ts` ("muestra la hora de planta sin convertirla a la zona del navegador") pasa aunque la función esté mal.

**Cómo detectarlo automáticamente:**
- Unitario: ejecutar el test de `formatPlantTime` con `TZ=America/Bogota` (o con varias zonas).
- E2E: Playwright con `timezoneId: 'America/Bogota'` verificando "Detectada 12/09 14:00" en `/anomalias/M-109`.

---

## DEF-05 · La paginación del Libro no permite llegar a la página 2: M-111 y M-112 quedan ocultos

- **Severidad:** Alta. Con el orden por defecto, M-112 (crítico, prioridad 2) y M-111 no se pueden ver en el Libro de medidores. El operador que revisa el inventario completo no ve un medidor crítico.
- **Prioridad:** Alta. Ocurre siempre que hay más de 10 resultados y la cantidad no es múltiplo exacto de 10, que es el caso por defecto con 12 medidores.
- **Capa:** UI (la API sí devuelve la página 2).

**Pasos para reproducir**
1. Abrir Medidores (`/medidores`) con el filtro "Todos" y el orden por defecto.
2. Ver el contador "1–10 de 12 medidores".
3. Hacer clic en "Siguiente".

**Resultado esperado:** "Siguiente" habilitado; la página 2 muestra M-111 y M-112 ("11–12 de 12").
Fuente: comportamiento estándar de paginación; la API devuelve la página 2 correctamente (CN-05 fila 3: `page 2 → M-111, M-112`).

**Resultado obtenido:** "Siguiente" aparece deshabilitado (cursor de "no permitido") estando en la página 1 de 2. Solo se llega a la página 2 escribiendo `?pagina=2` en la URL.

**Evidencia:** `evidencias/cn-19-siguiente-deshabilitado.png`, `evidencias/def-05-pagina2-por-url.png`.

**Causa raíz probable:** `frontend/src/features/meters/components/Pagination.tsx`, línea 13: `const pages = Math.max(1, Math.floor(count / size))`. Con 12 / 10 = 1,2, `Math.floor` da 1 página. Debe ser `Math.ceil` (2 páginas).

**Cómo detectarlo automáticamente:**
- Unitario: test del componente `Pagination` con `count: 12, size: 10, page: 1` que espere el botón "Siguiente" habilitado. Valores límite útiles: `count` 10, 11, 20 y 21.
- E2E: en Playwright, verificar `getByRole('button', { name: 'Siguiente' })` habilitado y que tras el clic aparezca M-112.

---

## DEF-03 · La búsqueda por medidor distingue mayúsculas, contra lo documentado

- **Severidad:** Media. El operador que escribe `m-109` recibe "Ningún medidor coincide con los filtros" y puede concluir que el medidor no existe. Tiene solución fácil (escribir en mayúsculas), pero no es evidente.
- **Prioridad:** Media. Es un caso frecuente al escribir rápido, y es inconsistente con el resto del sistema: el filtro de estado acepta `alert` y `GET /meter/getById/m-109` funciona.
- **Capa:** API → UI.

**Pasos para reproducir**
1. En Medidores, escribir `m-109` en el campo Medidor y hacer clic en la lupa.
2. Por API: `POST /api/v1/meter/getAll` con `{"filter":{"meter_id":"m-109"}}`.

**Resultado esperado:** 1 resultado, M-109.
Fuente: `backend/README.md`, tabla de campos: *"`meter_id`: búsqueda parcial, sin importar mayúsculas (`109` encuentra `M-109`)"*.

**Resultado obtenido:** API `count=0 filas=[]`; UI "Ningún medidor coincide con los filtros. No hay medidores que contengan "m-109"" (URL `?medidor=m-109`).

**Evidencia:** `evidencias/casos-api-resultado.txt` (CN-07.3), `evidencias/cn-07-busqueda-minusculas.png`.

**Causa raíz probable:** `backend/internal/meter/service.go`, línea 59: `strings.Contains(sm.MeterID, search)` compara sin normalizar mayúsculas. `Normalize` (en `dto.go`) hace `TrimSpace` del `meter_id` pero no lo pasa a mayúsculas.

**Cómo detectarlo automáticamente:** agregar a `TestGetAllFilters` el caso `{"búsqueda en minúsculas", Filter{MeterID: "m-109"}, []string{"M-109"}}`. Hoy solo prueba `"109"` y `"M-11"`.

---

## DEF-04 · `page` negativo en `POST /meter/getAll` responde 500 en lugar de 400

- **Severidad:** Media. Un error interno del servidor por una entrada del cliente indica falta de validación; además el mensaje no ayuda a quien consume la API.
- **Prioridad:** Baja. La UI no envía páginas negativas (normaliza `?pagina=-1` a 1), así que solo afecta a consumidores directos de la API.
- **Capa:** API.

**Pasos para reproducir:** `POST /api/v1/meter/getAll` con body `{"pagination":{"page":-1,"size":10}}`.

**Resultado esperado:** 400 con un mensaje de validación, igual que con `size` inválido ("pagination.size debe estar entre 1 y 100").
Fuente: Swagger define `page` con mínimo 1; formato de error estándar de `backend/README.md`; consistencia con la validación de `size`.

**Resultado obtenido:** `HTTP 500 {"status_code":500,"message":"Error interno del servidor",...}`.

**Evidencia:** `evidencias/casos-api-resultado.txt` (CN-05.5).

```bash
curl -s -X POST http://localhost:8080/api/v1/meter/getAll \
  -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" \
  -d '{"pagination":{"page":-1,"size":10}}'
# → {"status_code":500,"message":"Error interno del servidor",...}
```

**Causa raíz probable:** `backend/internal/httpx/paging.go`. `Pagination.Normalize` (líneas 23–36) solo reemplaza `page == 0` y valida `size`, pero no valida `page < 1`. Luego `Paginate` (línea 48) calcula `start = (page−1)·size = −20` y el recorte `items[start:end]` entra en pánico; el servidor lo atrapa y responde 500.

**Cómo detectarlo automáticamente:** test unitario de `Pagination.Normalize` con `Page: -1` que espere un error de validación, y test de API (Playwright `request` o Go) que espere 400.

---

## OBS-01 · Tras cerrar sesión, "Atrás" puede mostrar una copia en caché de una pantalla protegida

- **Severidad:** Baja. No es una falla de autenticación: la API sigue exigiendo token y cualquier interacción redirige al login. Pero en un equipo compartido de planta, otra persona puede ver el último estado de los medidores.
- **Prioridad:** Baja.

**Cómo se reproduce:** abrir una pantalla protegida escribiendo la URL (carga completa de la página), navegar a otra, cerrar sesión y presionar "Atrás". Chrome restaura la página desde su *back-forward cache* con los datos visibles. En el flujo normal (navegando con el menú) no ocurre.

**Recomendación:** al restaurar la página desde caché (evento `pageshow` con `persisted = true`), verificar la sesión y redirigir al login si no existe.

**Evidencia:** `evidencias/cn-03-atras-tras-logout.png`, `evidencias/cn-03-redirige-login.png`, `evidencias/cn-03-prueba-limpia-login.png`.
