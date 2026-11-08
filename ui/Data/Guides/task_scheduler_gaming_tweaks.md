# Programador de tareas (Task Scheduler) — Ajustes para gaming (BF6)

Todo esto en `taskschd.msc`, dentro de **Biblioteca del Programador de
tareas > Microsoft > Windows**. Deshabilitar (no eliminar) es reversible con
un clic — clic derecho sobre la tarea → **Deshabilitar**.

Ninguna de estas tareas se ejecuta constantemente en segundo plano mientras
juegas — corren en momentos puntuales (inicio de sesión, horarios
programados, eventos específicos). El beneficio real es **evitar que una de
ellas dispare justo mientras estás en partida** y te robe CPU/disco/red por
unos segundos, causando un micro-stutter puntual. No esperes ganancia de FPS
sostenida, sino menos probabilidad de esos cortes aleatorios.

## Ya identificada en tu captura ✅

| Tarea | Ruta | Acción |
| --- | --- | --- |
| Microsoft Compatibility Appraiser (Exp) | `Application Experience` | **Ya está deshabilitada** — correcto, déjala así. Es telemetría de compatibilidad de programas, sin uso en gaming. |

## Seguras de deshabilitar — Application Experience

| Tarea | Qué hace | Impacto |
| --- | --- | --- |
| `ProgramDataUpdater` | Escanea programas instalados para el programa de compatibilidad de Microsoft | Bajo — I/O de disco puntual |
| `StartupAppTask` | Analiza el impacto de apps en el arranque del sistema | Bajo — solo corre en boot, pero puedes desactivarla sin perder nada útil para ti |

## Customer Experience Improvement Program (CEIP) — telemetría pura

| Tarea | Qué hace | Impacto |
| --- | --- | --- |
| `Consolidator` | Envía datos de uso agregados a Microsoft | Bajo-Medio — puede generar tráfico de red saliente puntual |
| `KernelCeipTask` | Telemetría a nivel de kernel | Bajo |
| `UsbCeip` | Telemetría de dispositivos USB | Bajo |

Toda esta carpeta (`Microsoft\Windows\Customer Experience Improvement Program`)
es 100% telemetría, cero funcionalidad para ti. Deshabilitar las tres es
seguro y sin ninguna contraparte negativa.

## Power Efficiency Diagnostics — telemetría de eficiencia energética

| Tarea | Ruta | Qué hace | Impacto |
| --- | --- | --- | --- |
| AnalyzeSystem | --- | --- | --- |

## Diagnóstico y reportes de errores

| Tarea | Ruta | Qué hace | Impacto |
| --- | --- | --- | --- |
| `Microsoft-Windows-DiskDiagnosticDataCollector` | `DiskDiagnostic` | Recolecta datos de salud del disco para enviar a Microsoft | Bajo — I/O de disco puntual |
| `QueueReporting` | `Windows Error Reporting` | Envía reportes de errores/crashes a Microsoft | Bajo-Medio — si BF6 crashea, esta tarea es la que sube el reporte; si prefieres no reportar nada, deshabilítala. Si te interesa que Microsoft/EA reciban el crash dump para investigar bugs, déjala activa. |

## Feedback / encuestas

| Tarea | Ruta | Qué hace | Impacto |
| --- | --- | --- | --- |
| `DmClient` | `Feedback\Siuf` | Programa notificaciones de "Hub de sugerencias" | Bajo |
| `DmClientOnScenarioDownload` | `Feedback\Siuf` | Igual, disparado por descargas de contenido | Bajo |

## Mapas y ubicación (si no las usas)

| Tarea | Ruta | Qué hace | Impacto |
| --- | --- | --- | --- |
| `MapsToastTask` | `Maps` | Notificaciones de actualización de mapas offline | Bajo |
| `MapsUpdateTask` | `Maps` | Descarga actualizaciones de mapas en segundo plano | Bajo-Medio — si nunca usas la app Mapas de Windows, sin razón para tenerla activa |

## Bluetooth (tu adaptador está "No conectado")

| Tarea | Ruta | Qué hace | Impacto |
| --- | --- | --- | --- |
| Tareas bajo `Bluetooth` | `Bluetooth` | Mantenimiento y sincronización de dispositivos BT | Bajo — ya viste en tu captura de red que Bluetooth dice "No conectado", así que estas tareas no tienen nada que hacer en tu caso |

## Rendimiento — NetTrace (rara, pero pesada si dispara)

| Tarea | Ruta | Qué hace | Impacto |
| --- | --- | --- | --- |
| `NetTrace` | `NetTrace` | Captura de tráfico de red para diagnóstico avanzado | Medio — normalmente inactiva, pero si algo la dispara puede generar carga de CPU notable mientras registra paquetes. Segura de deshabilitar salvo que estés depurando un problema de red activamente (como ahora) — en ese caso déjala hasta que terminemos, luego desactívala. |

## NO deshabilitar — necesarias o de bajo/nulo impacto real

| Tarea | Ruta | Por qué dejarla |
| --- | --- | --- |
| `Microsoft-Windows-DiskCleanup\SilentCleanup` | `DiskCleanup` | Mantiene espacio libre en disco automáticamente, útil en general |
| Tareas bajo `Windows Defender` | `Windows Defender` | Seguridad activa — no las toques |
| `WinSAT` | `Maintenance` | Evaluación de rendimiento que usa el propio Windows para ajustar comportamiento del sistema; corre muy poco y no vale la pena el riesgo |
| `Chkdsk\Proxy` / `Autochk\Proxy` | — | Relacionadas con integridad del disco en el arranque, no consumen nada en uso normal |
| `PcaPatchDbTask`, `SdbinstMergeDbTask` (las que ya viste "Listo") | `Application Experience` | Corren en horario programado de madrugada (mirá la columna "Hora próxima ej." en tu captura), no interfieren con tus sesiones de juego |

## Resumen de impacto esperado

Ninguna de estas tareas mueve el ping ni el FPS de forma medible y sostenida
— el beneficio real es **reducir la probabilidad de un micro-stutter puntual**
si alguna de ellas decide ejecutarse justo en medio de una partida. Es la
misma filosofía que SysMain/Prefetcher: contribuye a la limpieza general del
sistema, no es la causa raíz de lag de red (eso ya está cubierto con el
`.reg` de TCP/IP y los ajustes del NIC).
