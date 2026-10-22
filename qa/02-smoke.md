# 02 · Pruebas de humo (Smoke)

## Objetivo

Verificar con el **mínimo** de casos que el build está sano para empezar las pruebas funcionales: la aplicación levanta, los datos cargaron, el frontend se comunica con el backend, la autenticación funciona y cada pantalla y servicio crítico responde.

El smoke **no** valida reglas de negocio en detalle (estados, cálculos, horas). Eso se cubre en la Parte C. Aquí la pregunta es una sola: **¿se puede probar este build?**

## Entorno de ejecución

| Dato | Valor |
|---|---|
| Fecha de ejecución | [completar] |
| Ejecutado por | Leidy Lorena Prado Feria |
| Commit | [completar con `git log -1 --oneline`] |
| Modo de despliegue | Docker Compose (`docker compose up -d --build`) |
| Sistema operativo | Windows [completar versión] |
| Navegador | Google Chrome [completar versión] |
| Zona horaria del equipo | [completar con `Get-TimeZone`] |
| URLs | Front `http://localhost:3000` · API `http://localhost:8080` · Swagger `http://localhost:8080/docs` |
| Usuario | `admin@energia.local` / `admin123` |

## Criterio de salida del smoke

- **Build bloqueado:** falla cualquier caso marcado como **Bloqueante = Sí**. Se detienen las pruebas y se reporta.
- **Apto con observaciones:** fallan solo casos **Bloqueante = No**. Se registran como defectos y se continúa.
- **Build apto para pruebas:** todos los casos pasan.

**Criterio usado para marcar un caso como bloqueante:** si su fallo impide ejecutar el resto de las pruebas (sin backend, sin datos, sin login, sin la pantalla principal) o expone los datos sin autenticación.

## Resumen de ejecución

| ID | Caso | Capa | Bloqueante | Tiempo aprox. | Estado |
|---|---|---|---|---|---|
| SMK-01 | El backend responde en `/health` | API | Sí | 30 s | ⬜ |
| SMK-02 | La documentación de la API (Swagger) está disponible | API | No | 30 s | ⬜ |
| SMK-03 | Login por API con credenciales válidas devuelve token | API | Sí | 1 min | ⬜ |
| SMK-04 | Un endpoint protegido sin token responde 401 | API | Sí | 1 min | ⬜ |
| SMK-05 | El frontend llega al backend a través de su proxy (`/api`) | Integración | Sí | 1 min | ⬜ |
| SMK-06 | Login por UI lleva al Despacho | UI | Sí | 1 min | ⬜ |
| SMK-07 | Una ruta interna sin sesión redirige al login | UI | No | 30 s | ⬜ |
| SMK-08 | El Despacho muestra las órdenes y los KPI | UI | Sí | 1 min | ⬜ |
| SMK-09 | El Libro de medidores lista los 12 medidores con paginación | UI | No | 1 min | ❌ |
| SMK-10 | El detalle de un medidor carga con el histórico completo | UI | Sí | 1 min | ⬜ |
| SMK-11 | La investigación de una anomalía carga con evidencia | UI | No | 1 min | ⬜ |
| SMK-12 | Run AI Analysis termina en estado completado | UI + API | No | 1 min | ⬜ |
| | **Tiempo total estimado** | | | **≈ 10 min** | |

Leyenda: ✅ Pasó · ❌ Falló · ⚠️ Pasó con observación · ⬜ Pendiente

**Verificación transversal (SMK-08 a SMK-11):** con Chrome DevTools abierto (F12 → Console), ninguna de estas pantallas debe mostrar errores en rojo. Si aparece alguno, el caso queda ⚠️ y se adjunta la captura de la consola.

---

## Detalle de los casos

### SMK-01 · El backend responde en `/health`

- **Por qué está en el smoke:** si el backend no está arriba, nada más funciona. Es la primera verificación de cualquier despliegue.
- **Riesgo cubierto (Parte A):** [completar]
- **Precondición:** contenedores levantados (`docker compose ps` muestra backend y frontend en estado *running*).
- **Pasos:**
  ```powershell
  docker compose ps
  Invoke-RestMethod http://localhost:8080/health
  ```
- **Resultado esperado:** ambos servicios *running*; `/health` responde HTTP 200 con `{"status":"ok"}`.
- **Resultado obtenido:** [completar]
- **Estado:** ⬜
- **Evidencia:** `evidencias/smk-01-health.png`

### SMK-02 · Swagger disponible

- **Por qué está en el smoke:** la documentación de la API es el oráculo para todas las pruebas de API. No es bloqueante porque el producto funciona sin ella, pero sin ella no hay contra qué comparar.
- **Riesgo cubierto (Parte A):** [completar]
- **Pasos:**
  1. Abrir `http://localhost:8080/docs`.
  2. Abrir `http://localhost:8080/docs/openapi.json`.
- **Resultado esperado:** Swagger muestra los grupos de endpoints (auth, meter, anomaly, dashboard, ai) y el JSON de la especificación carga sin error.
- **Resultado obtenido:** [completar]
- **Estado:** ⬜
- **Evidencia:** `evidencias/smk-02-swagger.png`

### SMK-03 · Login por API devuelve token

- **Por qué está en el smoke:** todos los endpoints de negocio exigen token. Sin login por API no se puede probar ninguna capa de servicio.
- **Riesgo cubierto (Parte A):** [completar]
- **Datos:** `admin@energia.local` / `admin123`
- **Pasos:**
  ```powershell
  $body  = @{ email = "admin@energia.local"; password = "admin123" } | ConvertTo-Json
  $login = Invoke-RestMethod -Method Post -Uri http://localhost:8080/api/v1/auth/login -ContentType "application/json" -Body $body
  $login
  $token = $login.access_token
  ```
- **Resultado esperado:** HTTP 200 con `access_token` no vacío, `token_type` = `Bearer`, `expires_in` mayor que 0 y los datos del usuario.
- **Resultado obtenido:** [completar]
- **Estado:** ⬜
- **Evidencia:** `evidencias/smk-03-login-api.png`

### SMK-04 · Endpoint protegido sin token responde 401

- **Por qué está en el smoke:** confirma que la seguridad básica está activa. Es bloqueante porque un build que expone datos sin autenticación no debe seguir avanzando, aunque todo lo demás funcione.
- **Riesgo cubierto (Parte A):** [completar]
- **Pasos:**
  ```powershell
  try { Invoke-RestMethod http://localhost:8080/api/v1/auth/me }
  catch { $_.Exception.Response.StatusCode.value__ }

  Invoke-RestMethod http://localhost:8080/api/v1/auth/me -Headers @{ Authorization = "Bearer $token" }
  ```
- **Resultado esperado:** sin token → **401**. Con el token de SMK-03 → **200** con el usuario.
- **Resultado obtenido:** [completar]
- **Estado:** ⬜
- **Evidencia:** `evidencias/smk-04-sin-token.png`

### SMK-05 · El frontend llega al backend por su proxy

- **Por qué está en el smoke:** en Docker, nginx sirve el frontend y reenvía `/api` al backend (fuente: `README.md`, sección "Con Docker"). Ese puente es un punto de falla típico de despliegue: la API puede responder en el puerto 8080 y aun así la aplicación quedar sin datos.
- **Riesgo cubierto (Parte A):** [completar]
- **Pasos:**
  ```powershell
  Invoke-RestMethod -Method Post -Uri http://localhost:3000/api/v1/auth/login -ContentType "application/json" -Body $body
  ```
  (Mismo `$body` de SMK-03, pero ahora por el puerto **3000**, el del frontend.)
- **Resultado esperado:** HTTP 200 con `access_token`, igual que en SMK-03.
- **Resultado obtenido:** [completar]
- **Estado:** ⬜
- **Evidencia:** `evidencias/smk-05-proxy.png`

### SMK-06 · Login por UI lleva al Despacho

- **Por qué está en el smoke:** es la puerta de entrada del operador. Si falla, el usuario no puede usar el producto.
- **Riesgo cubierto (Parte A):** [completar]
- **Precondición:** ventana de incógnito (sin sesión previa).
- **Pasos:**
  1. Abrir `http://localhost:3000`.
  2. Ingresar `admin@energia.local` / `admin123` y entrar.
- **Resultado esperado:** redirige a `/` (Despacho) y en la barra superior aparece el usuario **Operador**.
- **Resultado obtenido:** [completar]
- **Estado:** ⬜
- **Evidencia:** `evidencias/smk-06-login-ui.png`

### SMK-07 · Ruta interna sin sesión redirige al login

- **Por qué está en el smoke:** valida que la UI protege sus pantallas. No es bloqueante porque los datos ya los protege la API (SMK-04): si esto fallara, el usuario vería una pantalla vacía o con error, no datos expuestos.
- **Riesgo cubierto (Parte A):** [completar]
- **Precondición:** ventana de incógnito nueva (sin sesión).
- **Pasos:**
  1. Abrir directamente `http://localhost:3000/medidores`.
- **Resultado esperado:** redirige a `/login` sin mostrar datos de medidores.
- **Resultado obtenido:** [completar]
- **Estado:** ⬜
- **Evidencia:** `evidencias/smk-07-ruta-protegida.png`

### SMK-08 · El Despacho muestra órdenes y KPI

- **Por qué está en el smoke:** es la pantalla principal; responde "¿qué reviso primero?". Si no muestra órdenes, el producto no cumple su propósito.
- **Riesgo cubierto (Parte A):** [completar]
- **Pasos:**
  1. Con la sesión iniciada y la consola abierta (F12 → Console), observar la pantalla Despacho.
- **Resultado esperado:**
  - Se muestran **4 órdenes** en orden de prioridad: M-109, M-112, M-104, M-106 (fuente: `README.md`, tabla de resultado esperado).
  - Los KPI muestran **12** medidores y **4** anomalías IA.
  - El bloque *Libro de medidores* aparece debajo con datos.
  - Sin errores en la consola.
- **Resultado obtenido:** [completar]
- **Estado:** ⬜
- **Evidencia:** `evidencias/smk-08-despacho.png`

### SMK-09 · El Libro de medidores lista los 12 medidores

- **Por qué está en el smoke:** es el inventario completo de medidores y la puerta al detalle. Valida la paginación en lo básico.
- **Riesgo cubierto (Parte A):** [completar]
- **Pasos:**
  1. Ir a **Medidores** (`/medidores`) con el filtro **Todos**.
  2. Verificar el contador inferior.
  3. Hacer clic en **Siguiente**.
- **Resultado esperado:** la página 1 muestra **1–10 de 12**; la página 2 muestra los 2 medidores restantes (M-111 y M-112). Sin errores en la consola.
- **Resultado obtenido:** la página 1 muestra "1–10 de 12", pero el botón **Siguiente está deshabilitado**: no se puede llegar a M-111 ni a M-112. Fallo no bloqueante: el resto de pantallas se puede probar → DEF-05.
- **Estado:** ❌
- **Evidencia:** `evidencias/smk-09-libro.png`

### SMK-10 · El detalle de un medidor carga con el histórico completo

- **Por qué está en el smoke:** la aplicación no tiene base de datos; lee los CSV al arrancar (fuente: `backend/README.md`, sección API). Este caso confirma que el dataset cargó completo: si faltan lecturas, todos los cálculos posteriores darían resultados falsos. Se usa M-109 por ser la prioridad 1.
- **Riesgo cubierto (Parte A):** [completar]
- **Pasos:**
  1. En el Libro, hacer clic en **M-109** (o abrir `/medidores/M-109`).
- **Resultado esperado:**
  - Se ven consumo de 24 h, baseline, variación, severidad y variables eléctricas (voltaje, corriente, factor de potencia).
  - El histórico por hora indica **14 días · 336 lecturas** (14 días × 24 horas) y el consumo por día muestra del **01/09 al 14/09**.
  - Sin errores en la consola.
- **Resultado obtenido:** [completar]
- **Estado:** ⬜
- **Evidencia:** `evidencias/smk-10-detalle-m109.png`

### SMK-11 · La investigación de una anomalía carga

- **Por qué está en el smoke:** es el diferencial del producto (la explicación de la IA). Si no carga, el operador no sabe qué hacer.
- **Riesgo cubierto (Parte A):** [completar]
- **Pasos:**
  1. Desde el Despacho, en la orden de M-109, clic en **Abrir investigación** (o abrir `/anomalias/M-109`).
- **Resultado esperado:** se ven "Qué encontró la IA", "Acción recomendada", la gráfica contra baseline, la tabla de variables, la evidencia con su puntaje y los eventos relacionados. Sin errores en la consola.
- **Resultado obtenido:** [completar]
- **Estado:** ⬜
- **Evidencia:** `evidencias/smk-11-investigacion-m109.png`

### SMK-12 · Run AI Analysis termina en completado

- **Por qué está en el smoke:** es la acción principal que dispara el operador y está en todas las pantallas. Valida el flujo asíncrono (respuesta 202 + consulta del estado). No es bloqueante porque el resultado del análisis inicial ya está cargado al arrancar.
- **Riesgo cubierto (Parte A):** [completar]
- **Pasos:**
  1. Clic en **Run AI Analysis** en la barra superior.
  2. Observar la hoja con los pasos del motor.
- **Resultado esperado:** los **7 pasos** (Lecturas → Baseline → Detección → Correlación → Eventos → Explicación → Recomendación) se completan, el análisis termina en estado **Completado** y la barra superior muestra el nuevo análisis (`AN-000X`).
- **Resultado obtenido:** [completar]
- **Estado:** ⬜
- **Evidencia:** `evidencias/smk-12-run-analysis.png`

---

## Conclusión del smoke

[completar al terminar, por ejemplo: "12 de 12 casos pasaron en ≈ 10 minutos. El build es apto para pruebas funcionales. Las observaciones encontradas durante la exploración se detallan en 03-casos-caja-negra.md y 05-defectos.md."]

## Casos que se dejaron fuera del smoke, y por qué

- **Filtros, búsqueda y ordenamiento del Libro:** son reglas funcionales; van en la Parte C con partición de equivalencia y valores límite.
- **Estados de los medidores según el tipo de anomalía:** regla de negocio; va en la Parte C como tabla de decisión.
- **Horas y zona horaria de las fechas mostradas:** consistencia entre capas; va en la Parte C.
- **Login con credenciales inválidas:** prueba negativa; va en la Parte C.

## Siguiente paso: automatización

Los casos SMK-01, SMK-03, SMK-04 y SMK-05 son candidatos directos a automatizar como tests de API con `request` de Playwright, y SMK-06 a SMK-10 como tests de UI. Al ser estables y rápidos, son los primeros que correrían en cada build (ver `e2e/`).
