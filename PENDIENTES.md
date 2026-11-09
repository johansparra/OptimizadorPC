# Pendientes — para retomar

Lista de trabajo para la próxima sesión, ordenada por lo que hay que **decidir** antes de
programar. El detalle técnico de cada punto vive en `README.md` §Pendiente y en
`SECURITY.md` §11; aquí está qué falta y qué pregunta hay que contestar.

Última actualización: **2026-11-08**, tras los commits `1a2e725` y `09049df` (borrado
al revertir, *Actualizaciones* con registro, paso `dns-dhcp`, CI de Windows).

## 1. Decisiones rápidas (una respuesta y se hace)

- [ ] **"Delivery Optimization" duplicado.** *Regedit* ("Delivery Optimization (Policy)")
  y *Actualizaciones* ("Delivery Optimization (P2P)") escriben el mismo valor
  `HKLM\SOFTWARE\Policies\Microsoft\Windows\DeliveryOptimization\DODownloadMode`. Si
  se cambia en una sección, la otra no se entera hasta refrescarla, y apagarlos no
  deja lo mismo (uno escribe `Default`, el otro borra).
  **Decidir:** ¿se queda en *Actualizaciones* y se quita de *Regedit*, o al revés?
- [ ] **Los 7 ajustes de *Regedit* en ramas `Policies`** (Psched, System, CloudContent,
  DeliveryOptimization...) declaran `Default`: al apagarlos dejan la directiva puesta
  con un número en vez de "sin configurar".
  **Decidir:** ¿pasarlos a `DefaultAbsent` como los de *Actualizaciones*? (Recomendado:
  sí; es lo que Windows trae de fábrica.)
- [ ] **Badge "NEW 1" fijo en *Actualizaciones*** (`ui/Data/Categories/Update.ps1`): está
  escrito a mano y ninguno de sus dos ajustes lleva `-Badge`.
  **Decidir:** ¿quitarlo (pasa al recuento automático, sin badge) o marcar los ajustes?

## 2. Decisiones de diseño (hay que pensarlas)

- [ ] **Rollback persistente → botón "deshacer" → aviso de punto de restauración**, en
  ese orden (`SECURITY.md` §4 y §11 nº 2). Ojo de seguridad: un snapshot guardado en
  `%APPDATA%` lo puede escribir cualquier programa del usuario y el `.exe` lo leería
  elevado — el mismo vector que se cerró en `settings.json`. Restaurar desde ahí debe
  pasar por la lista blanca de `Writer.ps1` y no confiar en el archivo.
  **Decidir:** dónde se guarda, qué se valida al leerlo, y si "deshacer" es el último
  cambio o una lista.
- [ ] **"Quick Actions"** de la pantalla principal: hoy es un chip decorativo.
  **Decidir:** qué hace (¿aplicar todo lo recomendado? ¿restaurar todo de fábrica?).
  Cualquiera de las dos son muchas escrituras elevadas de golpe: necesita confirmación.

## 3. Trabajo largo (cuando toque)

- [ ] Servicios y tareas programadas como mecanismos propios en `core/` (con su lista
  blanca, como `CommandRunner.ps1`).
- [ ] Firma Authenticode del `.exe`: bloquea distribuirlo a terceros (`SECURITY.md` §11 nº 3).
- [ ] Prueba de humo del `.exe` **elevado** sin intervención (hoy hay que aceptar el UAC
  a mano).

## 4. Comprobar

- [ ] **Ver la CI en verde** en GitHub (Actions → *CI* y *Semgrep*) tras el push a
  `master`. Es la primera vez que corre `.github/workflows/ci.yml`: si falla, mirar
  primero la instalación de PSScriptAnalyzer y las pruebas que dependen del equipo.
- [ ] Recompilar el `.exe` (`build.ps1`) y abrir *Actualizaciones* e *Internet* para ver
  los cambios en pantalla.
