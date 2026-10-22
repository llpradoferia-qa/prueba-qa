# 03 · Casos de prueba funcionales de caja negra

Diseñados **sin mirar el código**, a partir de la documentación (oráculo) y de la exploración de la UI y de Swagger.

- **Entorno:** el mismo de `02-smoke.md`.
- **Casos de API:** se ejecutan con el script `evidencias/casos-api.ps1`, que deja el resultado de cada llamada en `evidencias/casos-api-resultado.txt`.
- **Leyenda:** ✅ Pasó · ❌ Falló (defecto) · ⚠️ Observación · ⬜ Pendiente

## Resumen

| ID | Título | Técnica | Capa | Riesgo | Estado |
|---|---|---|---|---|---|
| CN-01 | Login por API con credenciales válidas e inválidas | Partición de equivalencia, negativa | API | R4 | ✅ |
| CN-02 | Login por UI con credenciales inválidas o vacías | Negativa | UI | R4 | ✅ |
| CN-03 | Acceso con token ausente, alterado y tras cerrar sesión | Negativa | API + UI | R4 | ⚠️ |
| CN-04 | Tamaño de página (`size`) en sus límites | Valores límite | API | R6 | ✅ |
| CN-05 | Número de página (`page`) en sus límites | Valores límite | API | R6 | ❌ |
| CN-06 | Filtro por estado | Partición de equivalencia | API + UI | R1, R6 | ❌ |
| CN-07 | Búsqueda por medidor | Partición de equivalencia, valores límite | API + UI | R6 | ❌ |
| CN-08 | Ordenamiento por campo y dirección | Partición de equivalencia, negativa | API | R6 | ✅ |
| CN-09 | Combinación de filtros | Combinatoria | API | R6 | ❌ |
| CN-10 | Resultado del motor → estado del medidor | Tabla de decisión | API + UI | R1 | ❌ |
| CN-11 | Tipo → severidad → prioridad de las órdenes | Tabla de decisión | API + UI | R3 | ✅ |
| CN-12 | Evento → tipo de anomalía | Tabla de decisión | UI | R1 | ✅ |
| CN-13 | Conteo de medidores por estado en todas las capas | Consistencia entre capas | API + UI + doc | R1, R5 | ❌ |
| CN-14 | Hora de detección de las anomalías | Consistencia entre capas | API + UI + doc | R2 | ❌ |
| CN-15 | Hora de la última lectura | Consistencia entre capas | API + UI | R2 | ❌ |
| CN-16 | Las horas no dependen de la zona horaria del navegador | Partición de equivalencia (zona) | UI | R2 | ❌ |
| CN-17 | Cálculo de variación y consumo | Consistencia entre capas | API + UI + doc | R5 | ✅ |
| CN-18 | Detalle por ID de medidor | Partición de equivalencia, negativa | API + UI | R5 | ✅ |
| CN-19 | Los filtros del Libro viven en la URL | Funcional UI, negativa | UI | R6 | ❌ |
| CN-20 | Run AI Analysis | Funcional, negativa | UI + API | R7 | ✅ |
| CN-21 | Accesibilidad básica: estado sin depender del color y teclado | Verificación WCAG | UI | — | ✅ |

---

## Módulo 1 · Autenticación

### CN-01 · Login por API con credenciales válidas e inválidas

- **Técnica:** partición de equivalencia. Clases válidas (V) e inválidas (I) para email y password.
- **Precondición:** backend arriba.
- **Pasos:** `POST /api/v1/auth/login` con cada combinación de la tabla.
- **Fuente:** `backend/README.md` (login), formato de error estándar. V2 y V3: decisión por sentido común (ver plan, sección 5).

| # | Clase | email | password | Esperado | Obtenido | Estado |
|---|---|---|---|---|---|---|
| 1 | V1 válido | `admin@energia.local` | `admin123` | 200 + `access_token` | 200 + token Bearer, expira en 28800 s | ✅ |
| 2 | V2 email en mayúsculas | `ADMIN@energia.local` | `admin123` | 200 | 200 + token | ✅ |
| 3 | V3 email con espacios | ` admin@energia.local ` | `admin123` | 200 | 200 + token | ✅ |
| 4 | I1 password incorrecta | `admin@energia.local` | `wrong` | 401, mensaje genérico | 401 "Email o contraseña incorrectos" | ✅ |
| 5 | I2 password en mayúsculas | `admin@energia.local` | `ADMIN123` | 401 (la contraseña sí distingue mayúsculas) | 401 | ✅ |
| 6 | I3 password con un carácter menos (límite) | `admin@energia.local` | `admin12` | 401 | 401 | ✅ |
| 7 | I4 password con espacio al final | `admin@energia.local` | `admin123 ` | 401 | 401 | ✅ |
| 8 | I5 email inexistente | `noexiste@x.com` | `admin123` | 401 con el **mismo** mensaje que I1 (no revela si el usuario existe) | 401 "Email o contraseña incorrectos" (mismo mensaje) | ✅ |
| 9 | I6 campos vacíos | `""` | `""` | 400 con un error por campo | 400 "email es obligatorio; password es obligatorio" | ✅ |
| 10 | I7 body mal formado | `{bad json` | | 400 | 400 "body inválido" | ✅ |

- **Resultado:** 10 de 10 como se esperaba.
- **Estado:** ✅
- **Evidencia:** `evidencias/casos-api-resultado.txt`

### CN-02 · Login por UI con credenciales inválidas o vacías

- **Técnica:** prueba negativa.
- **Precondición:** ventana de incógnito.
- **Pasos:**
  1. Abrir `http://localhost:3000/login`.
  2. Intentar entrar con `admin@energia.local` / `wrong`.
  3. Intentar entrar con ambos campos vacíos.
- **Resultado esperado:** se muestra un mensaje de error comprensible, se permanece en `/login` y no se crea sesión (al abrir `/` redirige a login). Con campos vacíos, el formulario no se envía o muestra qué campo falta.
- **Resultado obtenido:** con `admin@energia.local` / contraseña incorrecta se muestra "Email o contraseña incorrectos. Revisa los datos e inténtalo de nuevo." y se permanece en `/login`. [completar: campos vacíos]
- **Estado:** ✅
- **Evidencia:** `evidencias/cn-02-login-invalido.png`

### CN-03 · Acceso con token ausente, alterado y tras cerrar sesión

- **Técnica:** prueba negativa.
- **Pasos y esperados:**

| # | Acción | Esperado | Obtenido | Estado |
|---|---|---|---|---|
| 1 | `GET /auth/me` sin header `Authorization` | 401 | 401 "Falta el token de autenticación" | ✅ |
| 2 | `GET /auth/me` con `Bearer abc` | 401 "Token inválido o expirado" | 401 "Token inválido o expirado" | ✅ |
| 3 | `GET /auth/me` con token válido | 200 con el usuario | 200 `{email, name: Operador}` | ✅ |
| 4 | UI: cerrar sesión (icono junto a "Operador") y luego abrir `/medidores` | Redirige a `/login` | Al cerrar sesión lleva a `/login` con el formulario vacío; al navegar o recargar (F5) vuelve a `/login` | ✅ |
| 5 | UI: tras cerrar sesión, presionar "Atrás" en el navegador | No muestra datos; redirige a `/login` | **Se muestra de nuevo el Libro de medidores con "Operador" en la barra**: es una copia de la página guardada por el navegador (*back-forward cache*); al hacer clic o recargar redirige a `/login`. La sesión sí está cerrada, pero los datos quedan visibles en un equipo compartido → OBS-01 | ⚠️ |

- **Evidencia:** `evidencias/casos-api-resultado.txt`, `evidencias/cn-03-atras-tras-logout.png`, `evidencias/cn-03-redirige-login.png`, `evidencias/cn-03-prueba-limpia-login.png`

---

## Módulo 2 · Libro de medidores

Fuente para todo el módulo: `backend/README.md`, sección "Body de `POST /meter/getAll`" y tabla de campos. Swagger: `size` mínimo 1 y máximo 100. Dataset: 12 medidores.

### CN-04 · Tamaño de página (`size`) en sus límites

- **Técnica:** análisis de valores límite sobre el rango válido [1, 100]. El 0 se documenta como "no enviado" (usa el valor por defecto).

| # | `size` | Esperado | Obtenido | Estado |
|---|---|---|---|---|
| 1 | 0 (no enviado) | 200, size 10 por defecto | 200, 10 filas, count 12 | ✅ |
| 2 | 1 (límite inferior) | 200, 1 fila | 200, 1 fila (M-101) | ✅ |
| 3 | 100 (límite superior) | 200, 12 filas | 200, 12 filas | ✅ |
| 4 | 101 (fuera, arriba) | 400 "pagination.size debe estar entre 1 y 100" | 400 "pagination.size debe estar entre 1 y 100" | ✅ |
| 5 | -1 (fuera, abajo) | 400 con el mismo mensaje | 400, mismo mensaje | ✅ |

### CN-05 · Número de página (`page`) en sus límites

- **Técnica:** análisis de valores límite. Con `size` 10 y 12 medidores hay 2 páginas. Swagger define `page` con mínimo 1.

| # | `page` | Esperado | Obtenido | Estado |
|---|---|---|---|---|
| 1 | 0 (no enviado) | 200, página 1 | 200, página 1 (M-101 a M-110) | ✅ |
| 2 | 1 (primera) | 200, 10 filas (M-101 a M-110) | 200, M-101 a M-110 | ✅ |
| 3 | 2 (última) | 200, 2 filas (M-111, M-112), `count` 12 | 200, M-111 y M-112, count 12 | ✅ |
| 4 | 3 (después de la última) | 200, `rows` vacío, `count` 12 | 200, rows vacío, count 12 | ✅ |
| 5 | -1 (inválido) | **400** con mensaje de validación, como ocurre con `size` inválido | **500** "Error interno del servidor" → DEF-04 | ❌ |

### CN-06 · Filtro por estado

- **Técnica:** partición de equivalencia. Clases válidas: los tres estados documentados. Inválidas: valor fuera del dominio.
- **Esperado por estado:** se deriva de la tabla "Estado de alerta de un medidor" y del resultado esperado del motor (ver CN-10).

| # | `status` | Esperado | Obtenido | Estado |
|---|---|---|---|---|
| 1 | `NORMAL` | 9 medidores: los 8 sin anomalía + M-106 (falso positivo) | **8**: falta M-106 → DEF-01 | ❌ |
| 2 | `ALERT` | 1 medidor: M-104 | **2**: M-104 y M-106 → DEF-01 | ❌ |
| 3 | `CRITICAL` | 2 medidores: M-109, M-112 | 2: M-109, M-112 | ✅ |
| 4 | `alert` (minúsculas) | Mismo resultado que `ALERT` | Igual que `ALERT` (2, por DEF-01) | ✅ |
| 5 | `ROJO` (inválido) | 400 "filter.status debe ser NORMAL, ALERT o CRITICAL" | 400 con el mensaje esperado | ✅ |
| 6 | sin `status` | 12 medidores | 12 | ✅ |
| 7 | UI: pestañas Normales / Alertas / Críticas | Mismos conteos que en la API (9 / 1 / 2) y la URL cambia a `?estado=...` | **8 / 2 / 2** ("1–8 de 8", "1–2 de 2": M-104 y M-106, "1–2 de 2"); la URL sí cambia → DEF-01 | ❌ |

### CN-07 · Búsqueda por medidor

- **Técnica:** partición de equivalencia (ID completo, parcial, minúsculas, inexistente) y valores límite sobre la longitud (máximo 50 caracteres, según el error de la API).
- **Fuente:** "`meter_id`: búsqueda parcial, **sin importar mayúsculas** (`109` encuentra `M-109`)".

| # | `meter_id` | Esperado | Obtenido | Estado |
|---|---|---|---|---|
| 1 | `M-109` | 1 resultado: M-109 | 1: M-109 | ✅ |
| 2 | `109` (parcial) | 1 resultado: M-109 | 1: M-109 | ✅ |
| 3 | `m-109` (minúsculas) | 1 resultado: M-109 | **0 resultados** → DEF-03 | ❌ |
| 4 | `M-11` (prefijo) | 3 resultados: M-110, M-111, M-112 | 3: M-110, M-111, M-112 | ✅ |
| 5 | `M-999` (inexistente) | 200 con `count` 0 (no error) | 200, count 0. UI: "Ningún medidor coincide con los filtros" + botón "Quitar filtros" | ✅ |
| 6 | `"  M-109  "` (espacios) | 1 resultado: M-109 | 1: M-109 | ✅ |
| 7 | 50 caracteres (límite) | 200 con `count` 0 | 200, count 0 | ✅ |
| 8 | 51 caracteres (fuera) | 400 con mensaje de longitud máxima | 400 "filter.meter_id no puede superar 50 caracteres" | ✅ |
| 9 | UI: escribir `m-109` en el campo Medidor y clic en la lupa | La tabla muestra M-109 | **"Ningún medidor coincide con los filtros. No hay medidores que contengan \"m-109\""** (URL `?medidor=m-109`) → DEF-03 | ❌ |

> Nota de exploración: el texto gris "M-109" que aparece en el campo Medidor es el *placeholder* (ejemplo), no un filtro aplicado. Por eso la tabla muestra todos los medidores hasta que se escribe un valor.

### CN-08 · Ordenamiento

- **Técnica:** partición de equivalencia sobre `sort_by` (4 valores válidos + inválido) y `sort_order`.
- **Fuente:** tabla de campos de `POST /meter/getAll`; severidad: HIGH > MEDIUM > LOW > sin anomalía.

| # | Filtro | Esperado | Obtenido | Estado |
|---|---|---|---|---|
| 1 | `sort_by: severity`, `DESC` | M-109, M-112 (HIGH) → M-104 (MEDIUM) → M-106 (LOW) → los 8 sin anomalía | M-109, M-112, M-104, M-106, luego los 8 normales | ✅ |
| 2 | `sort_by: variation`, `ASC` | Primero el de menor variación (M-105, −1,1 %); último M-109 (+109,8 %) | Primero M-105, último M-109 | ✅ |
| 3 | `sort_by: consumption`, `DESC` | Primero M-109 (2.207,6 kWh) | Primero M-109 | ✅ |
| 4 | `sort_order: desc` (minúsculas) | Orden descendente aplicado | Descendente (M-112 primero) | ✅ |
| 5 | `sort_by: precio` (inválido) | 400 con los valores permitidos | 400 con los valores permitidos | ✅ |
| 6 | UI: "Ordenar por" Consumo, Variación y Severidad ("Menor a mayor") | Mismo orden que la API en ASC | Coincide con la API; la URL cambia a `?orden=consumption`, `variation`, `severity` | ✅ |

### CN-09 · Combinación de filtros

- **Técnica:** combinatoria de filtros (estado × búsqueda × orden).

| # | Filtro | Esperado | Obtenido | Estado |
|---|---|---|---|---|
| 1 | `status: CRITICAL` + `meter_id: M-104` | 0 resultados (M-104 no es crítico) | 0 | ✅ |
| 2 | `status: CRITICAL` + `sort_by: consumption` `DESC` | M-109 y luego M-112 | M-109, M-112 | ✅ |
| 3 | `status: NORMAL` + `meter_id: M-106` | 1 resultado: M-106 | **0** → otra manifestación de DEF-01 | ❌ |

---

## Módulo 3 · Reglas de negocio del motor (tablas de decisión)

### CN-10 · Resultado del motor → estado del medidor

- **Técnica:** tabla de decisión. Condiciones: ¿hay anomalía?, tipo, severidad. Acción: estado.
- **Fuente:** `backend/README.md`, tabla "Estado de alerta de un medidor"; resultado esperado del README principal ("M-106 · Falso positivo · No escalar").

| Regla | ¿Anomalía? | Tipo | Severidad | Estado esperado | Medidor de prueba |
|---|---|---|---|---|---|
| R1 | No | — | — | `NORMAL` | M-101 |
| R2 | Sí | `FALSE_POSITIVE` | LOW | `NORMAL` | M-106 |
| R3 | Sí | `REAL_ANOMALY` | HIGH | `CRITICAL` | M-109 |
| R4 | Sí | `DATA_QUALITY` | HIGH | `CRITICAL` | M-112 |
| R5 | Sí | `EXPLAINABLE_ANOMALY` | MEDIUM | `ALERT` | M-104 |

- **Pasos:** consultar `GET /meter/getById/{id}` para cada medidor de prueba y verificar el campo `status`; en la UI, verificar el sello de estado en el Libro y en el detalle.

| Regla | Medidor | Estado API | Estado UI | Estado |
|---|---|---|---|---|
| R1 | M-101 | NORMAL | Normal | ✅ |
| R2 | M-106 | **ALERT** (la API devuelve `anomaly: false`) → DEF-01 | **Alerta** en el Libro; en la tarjeta del Despacho dice "No escalar" | ❌ |
| R3 | M-109 | CRITICAL | Crítica | ✅ |
| R4 | M-112 | CRITICAL | Crítica | ✅ |
| R5 | M-104 | ALERT | Alerta | ✅ |

- **Observación:** la propia pantalla Despacho se contradice: la tarjeta de M-106 dice "No escalar" y el subtítulo habla de "3 órdenes abiertas", pero en el Libro de la misma pantalla M-106 aparece con el sello "Alerta".
- **Evidencia:** `evidencias/cn-10-estado-m106.png`

### CN-11 · Tipo → severidad → prioridad de las órdenes

- **Técnica:** tabla de decisión.
- **Fuente:** `backend/README.md`, secciones "Resultado sobre el dataset" y "8. Severidad".

| Medidor | Tipo | Condición documentada | Severidad esperada | Prioridad esperada | Obtenido (API / UI) | Estado |
|---|---|---|---|---|---|---|
| M-109 | REAL_ANOMALY | Variación > 50 % y sigue activa | HIGH | 1 | API: HIGH, 1 · UI: Alta, orden 1 de 4 | ✅ |
| M-112 | DATA_QUALITY | 12 h sospechosas o más (son 16 h) | HIGH | 2 | API: HIGH, 2 · UI: Alta, orden 2 | ✅ |
| M-104 | EXPLAINABLE_ANOMALY | Siempre MEDIUM | MEDIUM | 3 | API: MEDIUM, 3 · UI: Media, orden 3 | ✅ |
| M-106 | FALSE_POSITIVE | Siempre LOW | LOW | 4 | API: LOW, 4 · UI: Baja, orden 4 | ✅ |

- **Pasos:** `GET /anomaly/getAll` y pantalla Despacho (orden de las tarjetas "Orden 1 de 4"…).

### CN-12 · Evento → tipo de anomalía

- **Técnica:** tabla de decisión.
- **Fuente:** `backend/README.md`, secciones "6. Eventos" y "7. Clasificación".

| Medidor | Evento relacionado | Dirección del cambio | ¿El evento lo explica? | Tipo esperado | Obtenido (Investigación) | Estado |
|---|---|---|---|---|---|---|
| M-104 | OPERATIONAL_CHANGE | Aumento | Sí (explica aumentos y caídas) | EXPLAINABLE_ANOMALY | Anomalía explicable; evento "Cambio operativo" (hora mostrada 10/09 19:00, ver DEF-02) | ✅ |
| M-106 | SCHEDULED_OUTAGE | Caída que ya terminó | Sí (solo caídas) | FALSE_POSITIVE | Falso positivo; evento "Parada programada", ventana 12 h "hasta 08/09 06:00" | ✅ |
| M-109 | UNKNOWN | Aumento | No (UNKNOWN no explica nada) | REAL_ANOMALY | Anomalía real; "Evento sin causa conocida" | ✅ |
| M-112 | DATA_QUALITY | Variables eléctricas incoherentes | Solo refuerza calidad de datos | DATA_QUALITY | Calidad de datos; "Reporte de calidad de datos", 16 h sospechosas | ✅ |

- **Pasos:** abrir `/anomalias/{id}` de cada medidor y revisar "Eventos relacionados" y el tipo mostrado.

---

## Módulo 4 · Consistencia entre capas

### CN-13 · Conteo de medidores por estado en todas las capas

- **Técnica:** consistencia entre capas.
- **Fuente:** regla de CN-10 → 9 normales, 1 alerta, 2 críticas. El ejemplo de `GET /dashboard/getSummary` en Swagger también muestra `normal: 9, alert: 1, critical: 2`.

| Capa | Dónde se mira | Esperado | Obtenido | Estado |
|---|---|---|---|---|
| Documentación | Regla + ejemplo de Swagger | 9 / 1 / 2 | 9 / 1 / 2 | ✅ |
| API | `GET /dashboard/getSummary` → `status_counts` | 9 / 1 / 2 | **8 / 2 / 2** → DEF-01 | ❌ |
| API | `POST /meter/getAll` filtrando cada estado | 9 / 1 / 2 | **8 / 2 / 2** → DEF-01 | ❌ |
| UI | Despacho → "Estado de la planta" | "9 normales · 1 alerta · 2 críticas" | **"8 normales · 2 alerta · 2 críticas"** → DEF-01 | ❌ |
| UI | Libro → pestañas | 9 / 1 / 2 | **8 / 2 / 2** → DEF-01 | ❌ |

- **Evidencia:** `evidencias/cn-13-kpi-estados.png`

### CN-14 · Hora de detección de las anomalías

- **Técnica:** consistencia entre capas.
- **Fuente:** `frontend/README.md`: "Las fechas del dataset son **hora de planta**: se muestran tal como vienen, **sin convertirlas a la zona del navegador**". README principal: M-109 "desde 12/09 14:00".
- **Precondición:** equipo en zona horaria `America/Bogota` (UTC−5).

| Medidor | `detected_at` en la API | Esperado en UI | Obtenido en Despacho | Obtenido en Investigación (cabecera, "Desde", eventos) | Estado |
|---|---|---|---|---|---|
| M-109 | `2026-09-12T14:00:00Z` | 12/09 14:00 | **12/09 09:00** | Cabecera **12/09 09:00**, "Desde 12/09 09:00", evento **12/09 09:00**; el texto de la IA dice "desde 12/09 14:00" | ❌ |
| M-112 | `2026-09-13T00:00:00Z` | 13/09 00:00 | — | Tabla Anomalías IA: **12/09 19:00** (cambia el día) | ❌ |
| M-104 | `2026-09-11T00:00:00Z` | 11/09 00:00 | Texto de la tarjeta: "desde 11/09 00:00" | Tabla Anomalías IA: **10/09 19:00** (cambia el día) | ❌ |

- **Pasos:** `GET /anomaly/getAll` (o `/dashboard/getSummary`); luego comparar con la tarjeta del Despacho, la cabecera "Detectada … · hora de planta" de `/anomalias/{id}`, el dato "Duración · Desde …", la lista de eventos y el texto de la IA.
- **Evidencia:** `evidencias/cn-14-hora-m109.png`, `evidencias/cn-14-hora-m112.png`

### CN-15 · Hora de la última lectura

- **Técnica:** consistencia entre capas.
- **Fuente:** igual que CN-14.

| Dónde | Esperado | Obtenido | Estado |
|---|---|---|---|
| API `last_reading_at` (cualquier medidor) | `2026-09-14T23:00:00Z` | `2026-09-14T23:00:00Z` | ✅ |
| UI Libro → columna "Última lectura" | 14/09 23:00 | **14/09 18:00** → DEF-02 | ❌ |
| UI Detalle → "Última lectura … (hora de planta)" | 14/09 23:00 | **14/09 18:00 (hora de planta)** → DEF-02 | ❌ |

### CN-16 · Las horas no dependen de la zona horaria del navegador

- **Técnica:** partición de equivalencia sobre la zona horaria del cliente (Bogotá UTC−5, UTC, Madrid UTC+2).
- **Pasos:**
  1. Abrir `/anomalias/M-109` y anotar la hora "Detectada".
  2. Chrome DevTools (F12) → menú ⋮ → *More tools* → **Sensors** → *Location*: elegir "Other…" y en **Timezone ID** escribir `UTC`. Recargar.
  3. Repetir con `Europe/Madrid`.
- **Resultado esperado:** la hora es **la misma (12/09 14:00) en las tres zonas**, porque es hora de planta.
- **Resultado obtenido:**

| Zona del navegador | "Detectada" | "Duración · Desde" | Evento relacionado |
|---|---|---|---|
| America/Bogota (equipo) | 12/09 09:00 | 12/09 09:00 | 12/09 09:00 |
| UTC (DevTools → Sensors) | **12/09 14:00** | **12/09 14:00** | **12/09 14:00** |

  La hora de planta cambia según la zona horaria del navegador: solo coincide con la API y con el texto de la IA cuando el navegador está en UTC → DEF-02. [completar: Europe/Madrid]
- **Estado:** ❌
- **Evidencia:** `evidencias/cn-16-zona-bogota.png`, `evidencias/cn-16-zona-utc.png`, `evidencias/cn-16-zona-utc-completa.png`

### CN-17 · Cálculo de variación y consumo

- **Técnica:** consistencia entre capas (cálculo independiente).
- **Fuente:** `backend/README.md`: variación = diferencia porcentual entre consumo de 24 h y baseline. Ejemplo documentado: M-109, 2.207,6 contra 1.052,15 → +109,8 %.

| Medidor | Consumo 24 h | Baseline | Variación calculada a mano | API `variation_pct` | UI | Estado |
|---|---|---|---|---|---|---|
| M-109 | 2.207,6 | 1.052,15 | (2207,6 − 1052,15) / 1052,15 = +109,8 % | 109,82 | +109,8 % | ✅ |
| M-104 | 1.725,63 | 1.171,71 | +47,3 % | 47,27 | +47,3 % | ✅ |
| M-105 | 861,31 | 871,18 | −1,1 % | −1,13 | −1,1 % | ✅ |
| Planta (Despacho) | 12.502,36 | 10.776,73 | +16,0 % | 16,01 | +16,0 % | ✅ |

### CN-18 · Detalle por ID de medidor

- **Técnica:** partición de equivalencia (ID válido, en minúsculas, inexistente) y prueba negativa.

| # | Acción | Esperado | Obtenido | Estado |
|---|---|---|---|---|
| 1 | `GET /meter/getById/M-109` | 200; consumo, baseline, variación y estado iguales a la fila de M-109 en `getAll` | 200, mismos valores que en `getAll` | ✅ |
| 2 | `GET /meter/getById/m-109` | 200 (mismo medidor) | 200, M-109 | ✅ |
| 3 | `GET /meter/getById/M-999` | 404 con el formato de error estándar | 404 "Medidor no encontrado" | ✅ |
| 4 | UI: abrir `/medidores/M-999` | Mensaje claro de "no encontrado", sin pantalla en blanco | "No existe el medidor M-999. Revisa el código o búscalo en el libro de medidores." + botón "Ir al libro de medidores" | ✅ |

---

## Módulo 5 · Funcionalidad de UI

### CN-19 · Los filtros del Libro viven en la URL

- **Técnica:** funcional UI y prueba negativa sobre parámetros de la URL.
- **Fuente:** `frontend/README.md`: "Los filtros viven en la URL"; el código de la pantalla promete que "cambiar cualquier filtro vuelve a la página 1".

| # | Acción | Esperado | Obtenido | Estado |
|---|---|---|---|---|
| 1 | Elegir "Alertas", ordenar por Consumo "Mayor a menor" y recargar (F5) | Se mantienen los filtros y el resultado | URL `?estado=ALERT&orden=consumption&dir=DESC`; se mantienen "Alertas", "Consumo" y "Mayor a menor" (M-104 antes que M-106) | ✅ |
| 2 | Ir a la página 2 y luego cambiar el filtro de estado | Vuelve a la página 1 | Desde `?pagina=2` ("11–12 de 12", M-111 y M-112; solo alcanzable por URL por DEF-05) al elegir "Normales" la URL pasa a `?estado=NORMAL` y muestra "1–8 de 8" desde la página 1 | ✅ |
| 3 | Abrir manualmente `/medidores?pagina=-1` | Muestra la página 1 sin error | Muestra "1–10 de 12" (página 1) sin error: la UI normaliza el valor y no envía `page: -1` a la API, por eso DEF-04 no se ve desde la interfaz | ✅ |
| 4 | Abrir manualmente `/medidores?estado=ROJO` | Ignora el valor inválido y muestra "Todos" | Pestaña "Todos" activa y "1–10 de 12", sin error | ✅ |
| 5 | En página 1, el botón "Anterior"; en la última página, "Siguiente" | "Anterior" deshabilitado en la página 1; "Siguiente" **habilitado** en la página 1 de 2 ("1–10 de 12") | "Anterior" deshabilitado ✅. **"Siguiente" también deshabilitado** con 12 medidores: M-111 y M-112 (crítico, prioridad 2) no se pueden ver en el Libro → DEF-05 | ❌ |

### CN-20 · Run AI Analysis

- **Técnica:** funcional y prueba negativa.
- **Fuente:** `backend/README.md`: pipeline de 7 pasos, polling hasta `COMPLETED`.

| # | Acción | Esperado | Obtenido | Estado |
|---|---|---|---|---|
| 1 | Clic en Run AI Analysis | Hoja con 7 pasos; termina en Completado; la barra muestra el nuevo ID (`AN-000X`) | Panel "Análisis de IA AN-0002" con los 7 pasos marcados, "terminado en 10 ms", resumen "4 anomalías · 2 prioritarias"; barra y tarjeta "Último análisis" en AN-0002 · Completado | ✅ |
| 2 | La hora del análisis en la barra | Hora real de Colombia (coincide con el reloj del equipo) | "21 oct 21:40:08", igual al reloj del equipo (9:40 p. m.) | ✅ |
| 3 | `GET /ai/analysis/AN-9999` | 404 "Análisis no encontrado" | 404 "Análisis no encontrado" | ✅ |
| 4 | Ejecutar el análisis y luego revisar el Despacho | Resultados idénticos (motor determinístico) | Mismas 4 órdenes, severidades y confianzas; el defecto DEF-01 persiste ("8 normales · 2 alerta") | ✅ |

### CN-21 · Accesibilidad básica

- **Técnica:** verificación contra criterios de WCAG 2.1 AA declarados en `frontend/PRODUCT.md`.

| # | Verificación | Esperado | Obtenido | Estado |
|---|---|---|---|---|
| 1 | Sellos de estado y severidad | Siempre con texto o icono, no solo color | Sellos con texto ("Crítica", "Alerta", "Normal") y severidad con icono + texto ("Alta", "Media", "Baja") | ✅ |
| 2 | Navegar con Tab por las pestañas de estado, el buscador y el orden | Foco visible y operable con teclado | Foco visible (contorno verde) en el menú (Despacho, Medidores, Anomalías IA); existe el enlace "Saltar al contenido" al primer Tab | ✅ |
| 3 | Abrir el detalle de un medidor desde la tabla solo con teclado | Es posible (Tab + Enter) | Foco visible sobre "M-103" en la tabla; con Enter abre `/medidores/M-103` | ✅ |
