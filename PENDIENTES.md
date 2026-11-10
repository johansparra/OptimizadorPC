# Pendientes — para retomar

Lista de trabajo para la próxima sesión. El detalle técnico de cada punto vive en
`README.md` §Pendiente y en `SECURITY.md` §11; aquí está qué falta y qué pregunta hay
que contestar.

Última actualización: **2026-11-09** (segunda pasada), tras la versión `1.0.0`
(`39806e4`). Todo lo de §5 está **sin confirmar** en el árbol de trabajo.

## 1. Decisiones rápidas (una respuesta y se hace)

- [ ] **Cinco servicios de *Regedit* siguen yendo por el valor `Start` del registro**
  (`lfsvc`, `MapsBroker`, `CscService`, `StorSvc`, `SharedAccess`), mientras que
  DiagTrack, dmwappushservice y SysMain ya van por `core/Services` (sección *Servicios y
  tareas*). Dos caminos para lo mismo.
  **Decidir:** ¿se pasan los cinco a *Servicios y tareas* (y se quitan sus `Start` de la
  lista blanca de `Writer.ps1`)? Recomendado: sí, por coherencia y porque `Set-Service`
  valida lo que el registro no.
- [ ] **Tarea `Microsoft Compatibility Appraiser Exp`.** En este equipo (build 26300) no
  existen `Microsoft Compatibility Appraiser` ni `ProgramDataUpdater`: salen como "no
  existe en este equipo". La variante `... Exp` sí existe, pero no está en la lista
  blanca.
  **Decidir:** ¿se añade como un ajuste más?

## 2. Depende del propietario

- [ ] **Certificado de firma de código.** `build.ps1` ya firma (SHA-256 + sello RFC 3161):
  `.\build.ps1 -CertificateThumbprint <huella>`. Falta el certificado: OV/EV comercial o
  Azure Trusted Signing (`SECURITY.md` §11 nº 3). Sin él el `.exe` sale sin firmar y
  SmartScreen avisa a terceros.

## 3. Comprobar

- [ ] **Primera ejecución del job `humo` en GitHub** (compila el `.exe` y lo arranca
  elevado en `windows-latest`) tras el próximo push. En local ya pasa.
- [ ] Abrir el `.exe` recién compilado y mirar en pantalla: la sección *Servicios y
  tareas* (9 ajustes), el ajuste *Feedback Frequency* en *Regedit* y que el texto se ve
  nítido al entrar en *Optimizar* y al pasar el ratón por las tarjetas.
- [ ] Apagar uno de los ajustes con `DefaultAbsent` (p. ej. *Activity History*) y
  comprobar en `regedit` que el valor desaparece.
- [ ] `Set-Service` de pwsh 7 podría quitar el "inicio retrasado" de un servicio al cambiar
  su tipo. No afecta al `.exe` (5.1), solo a `main.ps1`; sin comprobar.

## 4. Hecho el 2026-11-09

Primera pasada:

- [x] Delivery Optimization duplicado: se queda en *Actualizaciones*.
- [x] Directivas de *Regedit* a `DefaultAbsent` (5 ajustes).
- [x] Badge "NEW 1" de *Actualizaciones* fuera; "Quick Actions" eliminado.
- [x] Rollback persistente / deshacer / punto de restauración: **descartado** por decisión
  del propietario (riesgo aceptado en `SECURITY.md` §4 y §11 nº 2).

Segunda pasada:

- [x] **Texto borroso al moverse** (entrada en cascada, hover de tarjetas): la ventana
  pintaba en `TextFormattingMode="Ideal"`; ahora `Display` (regla 29 de `CLAUDE.md`,
  medido al píxel). La sombra de las tarjetas va en una placa detrás.
- [x] **Diagnostic Data Level**: `Default` pasa de 3 a 1; apagarlo ya nunca sube la
  telemetría.
- [x] **Feedback Frequency** (`NumberOfSIUFInPeriod`) portado a *Regedit* con
  `DefaultAbsent`.
- [x] **Servicios y tareas programadas** como mecanismos propios: `core/Services/` y
  `core/ScheduledTasks/`, con lista blanca, lista de protegidos, `-WhatIf`, copia en
  memoria y relectura; sección *Servicios y tareas* con 3 servicios y 6 tareas de
  telemetría. SysMain y DiagTrack salen de *Regedit* (y su `Start`, de la lista blanca
  del registro).
- [x] **Firma Authenticode lista en `build.ps1`** (`tools/CodeSigning.ps1`; certificado
  de prueba con `tools/New-DevSigningCert.ps1`). Probada con uno autofirmado y borrado.
- [x] **Prueba de humo del `.exe` elevado** sin intervención (`Invoke-Smoke.ps1 -Exe`),
  en verde en local; job `humo` añadido a la CI.
- [x] `.exe` recompilado; pruebas 681 bien, 0 mal, en 5.1 y en 7.
- [x] Grafo de graphify actualizado.

## 5. Sin confirmar

Nada de lo de §4 tiene commit. Al confirmar, revisar con `git status` que no entra
`build/` salvo el `.exe` que se versiona a propósito.
