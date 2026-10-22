# 01 · Estrategia y plan de pruebas · EnergIA

| Dato | Valor |
|---|---|
| Producto | EnergIA: monitoreo de medidores eléctricos con detección de anomalías por IA |
| Build | [commit `git log -1 --oneline`] |
| Responsable | Leidy Lorena Prado Feria · QA Funcional |
| Oráculo | `README.md`, `backend/README.md`, `frontend/README.md`, `frontend/PRODUCT.md`, Swagger (`/docs`) |
| Usuarios | Operadores de planta en Colombia (zona horaria `America/Bogota`) |

## 1. Alcance

**Dentro del alcance**

| Área | Qué se prueba | Por qué |
|---|---|---|
| Autenticación | Login (UI y API), token, rutas protegidas, cierre de sesión | Protege datos operativos de la planta |
| Reglas del motor | Resultado del motor → estado, severidad y prioridad de cada medidor | Es la decisión que toma el operador: qué escalar y qué no |
| Libro de medidores | Filtro por estado, búsqueda por medidor, orden, paginación (UI y API) | Es la herramienta de trabajo diaria del operador |
| Consistencia entre capas | API vs. UI vs. documentación: conteos, cálculos, fechas y horas | Un mismo dato no puede decir cosas distintas según la pantalla |
| Fechas y zona horaria | Hora de planta mostrada sin conversión | Los operadores investigan en sitio según la hora que ven |
| Run AI Analysis | Flujo asíncrono: inicio, 7 pasos, estado final | Acción principal disponible en todas las pantallas |
| Caja blanca | Módulos de mayor riesgo y tests existentes (Parte D) | Encontrar la causa raíz y los huecos de cobertura |

**Fuera del alcance (y por qué)**

- **Narrador con OpenAI:** requiere una API key externa y su texto no es determinístico. Se prueba con el narrador del motor, que es el modo por defecto.
- **Validez estadística del motor** (umbrales, MAD, z robusto): se toma la metodología documentada como oráculo; se verifica que el sistema la aplique y la muestre de forma coherente, no si la metodología es la mejor.
- **Rendimiento, carga y seguridad avanzada** (pentest, fuerza bruta, expiración real del token de 8 h): requieren más tiempo y otro entorno.
- **Responsive / móvil y navegadores distintos de Chrome** en las pruebas manuales. Se cubre Chromium y Firefox en la automatización.
- **Despliegue en servidor:** solo se prueba el despliegue local con Docker Compose.

## 2. Análisis de riesgos

Impacto × probabilidad en escala 1–3. Se prueba primero lo de mayor puntaje.

| ID | Riesgo | Impacto | Prob. | Puntaje | Prioridad |
|---|---|---|---|---|---|
| R1 | El estado de un medidor no corresponde al resultado del motor (se escala lo que no se debe, o se ignora lo que sí) | 3 | 3 | 9 | Alta |
| R2 | Las fechas y horas se muestran desplazadas por la zona horaria del navegador (se investiga una ventana equivocada) | 3 | 3 | 9 | Alta |
| R3 | La prioridad de las órdenes no sigue la regla (se atiende primero lo menos urgente) | 3 | 2 | 6 | Alta |
| R4 | Acceso a datos sin autenticación o sesión que no se cierra | 3 | 2 | 6 | Alta |
| R5 | Cálculos inconsistentes entre API y UI (consumo, baseline, variación, conteos) | 2 | 2 | 4 | Media |
| R6 | Filtros, búsqueda o paginación devuelven resultados incompletos o errores con entradas límite | 2 | 2 | 4 | Media |
| R7 | Run AI Analysis queda colgado o no refleja el estado real | 2 | 1 | 2 | Baja |

Justificación de la probabilidad: R1 y R2 se marcan con probabilidad alta porque involucran reglas que se aplican en varias capas (motor, API y UI) y lógica de fechas, que son fuentes clásicas de defectos.

## 3. Tipos de prueba y capa

| Tipo de prueba | Capa | Técnica | Casos |
|---|---|---|---|
| Humo (smoke) | API + UI | Verificación mínima de disponibilidad | `02-smoke.md` |
| Funcional caja negra | API | Partición de equivalencia, valores límite, pruebas negativas | CN-01, CN-03 a CN-09, CN-18 |
| Funcional caja negra | API + UI | Tablas de decisión (reglas del motor) | CN-10 a CN-12 |
| Consistencia entre capas | API + UI + documentación | Comparación del mismo dato en cada capa | CN-13 a CN-17 |
| Funcional UI | UI | Flujo de usuario, negativas, estado en la URL | CN-02, CN-19, CN-20 |
| Accesibilidad básica | UI | Verificación contra WCAG 2.1 AA (PRODUCT.md) | CN-21 |
| Caja blanca | Unitario (Go / TypeScript) | Revisión de ramas y condiciones, análisis de cobertura | `04-caja-blanca.md` |
| Automatización E2E y API | UI + API | Playwright (TypeScript) | `e2e/` |

**Trazabilidad del smoke con los riesgos:** SMK-01, 02, 05 (disponibilidad, prerrequisito de todo) · SMK-03, 04, 06, 07 → R4 · SMK-08, 11 → R1, R3 · SMK-09 → R6 · SMK-10 → R5 · SMK-12 → R7.

## 4. Criterios de entrada y salida

**Entrada**
- La aplicación levanta con `docker compose up -d --build` y el smoke (`02-smoke.md`) no tiene fallos bloqueantes.
- La documentación del repositorio está disponible como oráculo.
- Credenciales de prueba operativas (`admin@energia.local`).

**Salida**
- Ejecutados el 100 % de los casos de riesgo alto (R1–R4) y al menos el 80 % del total.
- Todo defecto encontrado está reportado con evidencia, severidad y prioridad (`05-defectos.md`).
- La suite de Playwright corre con un solo comando y documenta al menos un defecto con `test.fail()`.
- **Criterio de liberación:** cero defectos abiertos de severidad crítica o alta en R1–R4.

**Suspensión**
- Falla un caso bloqueante del smoke, o el backend no levanta. Se reporta y se detienen las pruebas funcionales.

## 5. Supuestos y decisiones

- La "hora de planta" es la hora que trae el dataset. La API la entrega marcada como UTC, y según `frontend/README.md` se debe mostrar **tal como viene, sin convertirla** a la zona del navegador.
- Cuando dos documentos no coinciden, manda la regla más específica: la tabla "Estado de alerta de un medidor" de `backend/README.md` prevalece sobre la frase general del README principal.
- Emails en el login: se espera que no distingan mayúsculas ni espacios al inicio o al final (sentido común; la documentación no lo define).

## 6. Uso de IA

[Completar con tus palabras. Sugerencia: "Usé Claude como asistente para revisar la documentación, proponer la estructura de los documentos, sugerir casos borde y explicarme el código de Playwright. Todos los casos los ejecuté y verifiqué yo; los defectos los reproduje manualmente en UI y API antes de reportarlos."]

## 7. Resumen ejecutivo

[Completar al final, después de ejecutar todo. Debe responder en media página: ¿liberarías este build a producción? ¿por qué? ¿qué riesgos quedan abiertos?]
