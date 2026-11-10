# Seguridad — Optimizador PC

Documento de referencia para auditoría técnica y de seguridad. Describe el modelo de
amenaza, el contrato de escritura al registro, la superficie de ataque, las invariantes
que las pruebas vigilan y los riesgos aceptados o pendientes.

Última revisión completa: **2026-09-06** (commit base `464ea1c`). Complementa a
`README.md` (arquitectura), `CLAUDE.md` (reglas de trabajo) y
`.claude/skills/security-reviewer/SKILL.md` (guía de revisión de cambios).

**Repaso 2026-09-07** (commit base `bd2f12a`). Se auditaron las funcionalidades
añadidas desde la revisión completa —menús Expandir/Contraer del panel Regedit
(`ui/Components/Shell/ChipMenu.ps1`, `ui/Views/CategoryDetailView.ps1`) y la
preferencia "Formato de hora" (`ui/Engine/TimeFormat.ps1`,
`ui/Data/Preferences/40-TimeFormat.ps1`)— y **no introducen superficie nueva**: cero
escrituras al sistema, cero ejecución dinámica, cero red, y el único dato en disco es
la cadena `'24'`/`'12'` de la preferencia, por `Set-AppSetting` como el resto. PSSA y
Semgrep, ya instalables en la máquina de desarrollo, se ejecutaron (resultados en §9).
Se corrigió la CI de Semgrep (§8, §11 riesgo 4).

**Repaso 2026-11-08** (commit `f750d5f`, rama `visual/fluent-cards`; repasado otra vez
con la skill `security-reviewer` el mismo día). Superficie nueva desde el repaso
anterior, toda con su lista blanca y sus invariantes en §10:

- **Más comandos.** Secciones *Limpieza* (`Dism`, `cleanmgr`, `fsutil`, `defrag`) y
  *Energía* (`powercfg`), por el mismo `core/Commands/CommandRunner.ps1` (antes
  `core/Network/`). `-SkipIf` solo **lee** el registro para saltar un paso ya hecho.
- **Borrado de archivos.** `core/Commands/FolderCleanup.ps1`, el único sitio que borra:
  carpetas de una lista blanca, dentro del perfil salvo dos excepciones contadas, sin
  seguir enlaces (§12).
- **Datos del usuario en el log.** El detalle de una limpieza lleva rutas de archivos
  del perfil y nombres de lo que había en la papelera; solo sale a disco si el usuario
  guarda el log "con detalle" (§7).
- **Pasos recordados.** Qué pasos dejó marcados el usuario va a `settings.json` (§7).
- **Guías.** Los `.md` de `ui/Data/Guides/` se enseñan como texto. Van dentro del `.exe`
  en Base64 y nunca se ejecutan; sus enlaces pasan por `Invoke-ExternalLink` (§6).

Revisión formal de esa superficie: [`auditoria/2026-11-08-seguridad-calidad.html`](auditoria/2026-11-08-seguridad-calidad.html).
Cuatro cambios de endurecimiento: `-WhatIf` real en ejecutar y borrar (§9), volver a
mirar el atributo de enlace antes de entrar en una carpeta (§11 nº 10), la regla de
carpetas fuera del perfil (§12) y que un paso con aviso nunca se restaure marcado desde
`settings.json` (§7, §11 nº 11). Ningún ajuste de *Regedit* baja la seguridad del equipo
(§3.4).

**Tercera pasada 2026-11-08** (sobre `f750d5f` + cambios sin commitear del día). Superficie
nueva y su revisión:

- **Borrar valores del registro.** `Remove-RegistryValue` (`core/Registry/Writer.ps1`):
  `OFF` devuelve a "no existe" lo que de fábrica no existe (`DefaultAbsent`) o lo que la
  primera copia de la sesión vio ausente. Mismas garantías que la escritura —desarmado,
  lista blanca de ruta **y** nombre, copia previa, tipo, `-WhatIf`, relectura— y nunca
  borra claves (§3.2, §3.3; invariante en §10; riesgo aceptado §11 nº 13).
- ***Actualizaciones* con `-Registry`.** Dos ajustes en `HKLM\SOFTWARE\Policies\Microsoft`
  (rama ya permitida, sin ampliar la lista blanca). `NoAutoRebootWithLoggedOnUsers` está
  en la denylist: lleva `-AllowsSecurityTradeoff`, dice qué se pierde y no viene activo
  (§3.4).
- **Paso `dns-dhcp`** en *Internet* (deshace el DNS de Google): `netsh.exe` ya permitido,
  desmarcado y con aviso (§11 nº 8, invariante en §10).
- **CI** de PSScriptAnalyzer y de la suite en Windows, e imagen de Semgrep fijada por
  digest (§8, §9, §11 nº 4 y 5).

Resultado: Semgrep (`p/security-audit` + `p/secrets`, `--oss-only`) **0 hallazgos en 112
archivos**; PSScriptAnalyzer sin avisos nuevos (1 de línea base; 12 falsos positivos por
verbo en el pase estricto de `core/`). Informe:
[`auditoria/2026-11-08-seguridad-calidad.html`](auditoria/2026-11-08-seguridad-calidad.html).

**Cuarta pasada 2026-11-09.** Superficie nueva: **servicios y tareas programadas** como
mecanismos propios (`core/Services/`, `core/ScheduledTasks/`), cada uno con su lista
blanca, su lista de protegidos (Defender, firewall, Windows Update, cifrado, núcleo),
desarmado en pruebas, `-WhatIf`, copia previa y relectura, y la sección *Servicios y
tareas* que los usa (3 servicios y 6 tareas de telemetría). SysMain y DiagTrack dejan de
escribirse por su valor `Start` del registro. Contrato en §14; invariantes en §10;
riesgos en §11 nº 14 a 16.

---

## 1. Qué es esto y por qué importa

Optimizador PC es un **`.exe` portable de un solo archivo**, compilado con ps2exe, que:

| Propiedad del build | Consecuencia de seguridad |
| --- | --- |
| `-requireAdmin` | **Todo el código corre con privilegios de administrador.** |
| `-noConsole` | El usuario **no ve mensajes**: un fallo o un cambio es silencioso. |
| Portable | Puede acabar en un USB, una descarga o una carpeta escribible por todos. |
| Sin firma Authenticode (el build **ya sabe** firmar; falta el certificado, §11 nº 3) | SmartScreen lo marca como no confiable al abrirlo. |

Los tres riesgos reales, por gravedad:

1. **Dejar el equipo menos seguro que antes.** El riesgo principal: un "tweak
   recomendado" que apaga UAC, Defender, SmartScreen, el firewall, Windows Update o el
   cifrado. El usuario acepta un optimizador, no una rebaja de seguridad.
2. **Dejar el equipo roto y sin vuelta atrás.** Un cambio elevado sin valor de
   restauración es irreversible para quien no sabe editar el registro.
3. **Ejecutar código ajeno con privilegios de administrador.** Cualquier entrada
   externa (una ruta, un valor, un archivo, una descarga) que acabe ejecutándose.

---

## 2. Superficie de ataque

La aplicación **no habla con la red** (no descarga ni envía nada; la sección Internet
**configura** la red local con `netsh` e `ipconfig`, la de Limpieza **borra**
temporales y la de Energía cambia el plan de energía con `powercfg`; ver §12), no abre
puertos, no
carga plugins y no lee archivos que le pase un tercero. Las únicas entradas externas
son:

| Entrada | Origen | Cómo se trata |
| --- | --- | --- |
| `%APPDATA%\OptimizadorPC\settings.json` | Disco, escrito por la propia app | Parseo defensivo: un JSON corrupto o ausente se **ignora** y se arranca con valores por defecto (`ui/Engine/AppSettings.ps1`). Guarda preferencias de interfaz (tema, idioma, material, opciones de vista, formato de hora, carpeta y casilla "con detalle" del log) y qué pasos dejó marcados el usuario en las secciones de comandos. **Lo puede escribir cualquier programa del usuario sin privilegios**: por eso un paso con aviso nunca se restaura marcado desde aquí (§7). Un valor desconocido en `TimeFormat` cae al de partida (`Get-AppTimeFormat`); el patrón `.ToString(...)` es un literal de `ui/Engine/TimeFormat.ps1`, nunca la cadena guardada. |
| El **registro de Windows** que se lee | El equipo | Se abre siempre `RegistryView::Registry64`. Un `DWord` llega como `Int32` con signo y se reinterpreta sin signo (`Format-RegistryValue`). `core/` **nunca lanza**: devuelve un estado (`read`/`missing`/`denied`/`badpath`). |
| URLs de referencia (`-Link` de cada ajuste) | **Escritas en el propio repositorio** (`ui/Data/Categories/*.ps1`) | Antes de llegar al shell se validan: tiene que ser una URI absoluta con esquema `http` o `https` (`core/Shell/ExternalLink.ps1`). Cualquier otra cosa se rechaza sin tocar el shell. |
| `-Recommended` / `-Default` de cada clave de registro | **Escritas en el propio repositorio** | Es el contrato de aplicación y de reversión. No proviene de entrada del usuario. |
| `-Service` / `-ScheduledTask` de cada ajuste (nombre del servicio, ruta y nombre de la tarea, `Recommended` / `Default`) | **Escritos en el propio repositorio** (`ui/Data/Categories/Services.ps1`) | Solo los de la lista blanca de su mecanismo, nunca uno protegido; solo el tipo de inicio o habilitar/deshabilitar. Ver §14. |
| Pasos de las secciones de comandos (`-Exe`, `-Arguments`, `-Service`, `-Clean` de cada `New-CommandStep`) | **Escritos en el propio repositorio** (`ui/Data/Categories/Internet.ps1`, `Cleanup.ps1`, `Power.ps1`) | Se ejecutan **sin shell**, solo ejecutables, servicios y carpetas de una lista blanca; los ejecutables por ruta completa de la carpeta de sistema, las carpetas dentro de la del usuario (con las dos excepciones de §12). Ver §12. El usuario solo elige **cuáles** correr, no **qué** se ejecuta. |
| Salida de esos comandos | El equipo | Solo se **muestra** y se apunta en el log. Nunca se ejecuta ni se usa para construir otro comando. |
| Guías (`ui/Data/Guides/*.md`) | **Escritas en el propio repositorio**, dentro del `.exe` en Base64 | Se **leen** como texto (`ui/Engine/Markdown.ps1`) y se pintan en un `RichTextBox` de solo lectura. Nunca se ejecutan; sus enlaces pasan por `Invoke-ExternalLink` (solo `http`/`https`, §6). |

No hay ningún punto donde una cadena controlable por un tercero se convierta en código:
sin `Invoke-Expression`, sin `[scriptblock]::Create`, sin `Add-Type` con fuente
construida en tiempo de ejecución (los dos `Add-Type`, en
`core/Interop/SystemBackdrop.ps1` y `core/Interop/WorkArea.ps1`, usan una cadena
literal fija y revisada), sin
descargas. Lo vigila `tests/Source/Security.Tests.ps1`.

---

## 3. Escritura al registro — el contrato

La escritura vive en **`core/Registry/Writer.ps1`** (una clave por llamada) y se
dispara desde **`core/Registry/SettingApply.ps1`** (el toggle ON/OFF de un ajuste con
`-Registry`). Nada más escribe (ni borra) en el registro. Hoy son **47** ajustes con
`-Registry`, **uno por clave**: 45 en *Regedit* y 2 en *Actualizaciones* (dos
directivas de `HKLM\SOFTWARE\Policies\Microsoft\Windows`, dentro de la rama ya
permitida). Ningún valor lo escriben dos ajustes: la directiva de Delivery
Optimization (`DODownloadMode` en la rama `Policies`) vive solo en *Actualizaciones*.
Todas las directivas de la rama `Policies` —las 2 de *Actualizaciones* y 5 de
*Regedit*— declaran `DefaultAbsent`, y también *Feedback Frequency*
(`NumberOfSIUFInPeriod`, en `HKCU`): no es una directiva, pero de fábrica tampoco
existe. *Diagnostic Data Level* (`AllowTelemetry`) lleva `Default = 1` y no el `3` que
deja la instalación al aceptar los datos opcionales: el de fábrica depende de lo que se
eligió (1 o 3), y con 3 `OFF` **subía** la telemetría a quien había elegido "solo
obligatorios"; con 1 nunca la sube. El primero que se cableó fue `NetworkThrottlingIndex` —benigno,
reversible, en una rama permitida—.

### 3.1 Lista blanca de rutas

`$RegistryWriteAllowlist` en `Writer.ps1`. Una ruta candidata se acepta solo si **es**
uno de estos prefijos o **cuelga** de él (comparación normalizada, sin distinguir
mayúsculas, raíz sin abreviar):

```text
HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile
HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft
HKEY_CURRENT_USER\Software\Policies\Microsoft
HKEY_CURRENT_USER\Control Panel\Desktop
HKEY_CURRENT_USER\Control Panel\Mouse
HKEY_CURRENT_USER\Software\OptimizadorPC          (rama de las pruebas)
```

No hay denylist: **lo que no está en la lista, no se toca** (estado `blocked`). SAM,
SECURITY, BCD, `...\Services` y todo lo demás quedan fuera por omisión.

**Lista de valores (`$RegistryWriteAllowedValues`, 2026-10-03).** Lo que no se puede
abrir como rama entera entra **valor a valor**: la clave tiene que ser *exactamente*
la declarada —sus subclaves no heredan el permiso— y el nombre del valor, uno de su
lista. Así entran el `Start` de siete servicios concretos (SysMain, DiagTrack, lfsvc,
MapsBroker, CscService, StorSvc, SharedAccess; **los dos primeros ya no los escribe
ningún ajuste** desde 2026-11-09: sus tarjetas pasaron a *Servicios y tareas*, que cambia
el tipo de inicio por su propio mecanismo, §14 —quitarlos de esta lista está pendiente,
ver §11 nº 14—), cuatro valores de
`Tcpip\Parameters` (no `...\Interfaces`), seis de `LanmanServer\Parameters`,
`DisableWpbtExecution` de `Session Manager` (sin abrir `KnownDLLs`, `BootExecute`,
`Environment`), `EnablePrefetcher`, `HibernateEnabled` y los de privacidad del paquete
BF6 (el último, `NumberOfSIUFInPeriod` de `HKCU\Software\Microsoft\Siuf\Rules`, solo
ese valor: `PeriodInNanoSeconds`, al lado, no entra). `Test-RegistryWriteAllowed` sin `-Name` nunca acepta esta lista.

> **Riesgo conocido [Media].** `HKLM\SOFTWARE\Policies\Microsoft` es un prefijo
> **amplio**: por debajo cuelgan las claves GPO de Windows Defender
> (`...\Windows Defender`), Windows Update (`...\Windows\WindowsUpdate`) y SmartScreen.
> La lista blanca gatea **rutas, no semántica**: hoy el único ajuste que escribe bajo
> `...\Windows\WindowsUpdate` es *Auto-Restart With Active Sessions*, declarado como
> rebaja de seguridad (§3.4), pero el gate por sí solo no lo impediría. La mitigación es la denylist de
> nombres de valor del §3.4 + la revisión manual de cada ajuste nuevo.
> **Antes de estrechar este prefijo** hay que saber qué claves concretas se querrán
> escribir (política de energía, telemetría, etc.).

### 3.2 Las cinco condiciones de cada escritura

`Writer.ps1` ya las cumple. Al añadir un ajuste con `-Registry` o ampliar la lista
blanca, comprueba que se siguen cumpliendo:

1. **Valor de restauración documentado.** El `Default` de cada clave: `OFF` lo escribe.
   O, en su lugar, `DefaultAbsent = $true`: de fábrica el valor **no existe** (una
   directiva sin configurar) y `OFF` lo **borra**. Una clave declara uno de los dos,
   nunca ambos; sin ninguno no se puede revertir → no se aplica (lo vigila
   `Security.Tests.ps1`).
2. **Distinguir "no existía" de "valía otra cosa".** `Get-RegistryStoredValue`
   distingue `missing` de `read` y lo guarda en el snapshot (`Existed` y `State`).
   **Revertir lo que no existía lo borra** (2026-11-08): `OFF` llama a
   `Remove-RegistryValue` en vez de escribir el `Default` si la clave declara
   `DefaultAbsent`, o si la **primera** copia de la sesión de ese valor
   (`Get-RegistrySnapshotOrigin`) lo vio `missing`. Un `denied` no cuenta como ausente
   (no se sabe): ahí se escribe el `Default`. El borrado:
   - quita **solo el valor** (`DeleteValue`); nunca una clave ni subclave. Si `ON` creó
     la clave contenedora, se queda vacía (una clave de directiva vacía es "sin
     configurar"),
   - pasa por la **misma** lista blanca (ruta **y** nombre de valor) y rechaza un
     nombre vacío (sería el "(Predeterminado)" de la clave),
   - respeta el desarmado de las pruebas (`Set-RegistryWriteArmed`) y `-WhatIf`,
   - no toca un valor que exista con **otro tipo** del declarado (`typemismatch`),
   - guarda copia previa, verifica por relectura que ya no está y nunca lanza.
   Es el único borrado del registro del programa: `Security.Tests.ps1` falla si
   aparece un borrado de claves en `ui/`/`core/` o un borrado de valores fuera de
   `Writer.ps1`.
3. **Ruta validada** contra `$RegistryWriteAllowlist` (`Test-RegistryWriteAllowed`),
   nunca concatenada con entrada libre. `RegistryView::Registry64` explícito.
4. **Tipo declarado.** `ConvertTo-RegistryData` respeta el `Type` (`DWord`/`QWord`/
   `Binary`/`String`/`ExpandString`). Un tipo real distinto al pedido → `typemismatch`,
   no se pisa. `MultiString` → `unsupported`, no se escribe.
5. **Nada de ACLs ni propietarios.** Clave protegida → `denied`, se enseña, no se
   fuerza.

Además, `Writer.ps1` hace **copia del valor previo** (`$RegistrySnapshots`, en memoria),
**verificación por relectura** tras escribir (si no cuadra → `denied`, fallo visible en
el log), y soporta **`-WhatIf`** (`SupportsShouldProcess`).

### 3.3 Estados que devuelven `Write-RegistryValue` y `Remove-RegistryValue`

| Estado | Qué pasó |
| --- | --- |
| `written` | Escrito y confirmado por relectura. |
| `deleted` | **Solo `Remove-RegistryValue`.** Valor borrado y confirmado por relectura que ya no está. |
| `nochange` | Ya estaba en el valor destino (o, al borrar, ya no existía); no se toca. También con `-WhatIf`. |
| `blocked` | La ruta (o el nombre del valor) no está en la lista blanca. Al borrar, también un nombre vacío. |
| `badpath` | La raíz de la ruta no se reconoce. |
| `typefail` | El texto declarado no cuadra con el tipo (al borrar: el `Type` no es un tipo conocido). |
| `unsupported` | Tipo que aún no se sabe escribir (`MultiString`). |
| `typemismatch` | El valor ya existe con OTRO tipo; no se pisa ni se borra en silencio. |
| `denied` | Sin permisos, o la relectura posterior no cuadra (al borrar: el valor sigue ahí). |
| `disarmed` | La escritura (y el borrado) está desarmada (solo en las pruebas). |

Cada intento deja en el registro de actividad (`core/Diagnostics/Log.ps1`) tres bloques
auditables: `write attempt` (con validación previa: clave existe, valor existe, tipo
real, si el proceso está elevado), `post write` (esperado vs. leído) y el resultado
(`applied`/`restored`/`deleted`/`write failed` con motivo accionable, excepción, HResult
y traza). Un borrado usa los mismos bloques con `action=RestoreAbsent` (o
`DeleteValue`) y `newvalue=(absent)`, y antes deja su `snapshot` como una escritura.

### 3.4 Ajustes que degradan la seguridad del equipo

Un ajuste que baja la postura de seguridad **no está prohibido**, pero:

- no puede llamarse `Recommended` sin más,
- su descripción tiene que decir **qué protección se pierde**,
- no puede venir activo por defecto,
- y **debe llevar `AllowsSecurityTradeoff = $true`** en la declaración del ajuste.

`tests/Source/Security.Tests.ps1` recorre todos los `-Registry` de
`ui/Data/Categories/*` y **falla la suite** si alguno apunta a uno de estos nombres de
valor sin esa marca:

```text
ConsentPromptBehaviorAdmin  ConsentPromptBehaviorUser  PromptOnSecureDesktop
EnableLUA  FilterAdministratorToken  LocalAccountTokenFilterPolicy
DisableAntiSpyware  DisableAntiVirus  DisableRealtimeMonitoring
DisableBehaviorMonitoring  DisableOnAccessProtection
SmartScreenEnabled  EnableSmartScreen  ShellSmartScreenLevel
PreventDeviceEncryption  NoAutoUpdate  NoAutoRebootWithLoggedOnUsers
EnableFirewall  DoNotAllowExceptions
```

La lista es la de `tests/Source/Security.Tests.ps1` (`$peligrosos`); si crece, crece en
los dos sitios.

La marca se pone con el switch **`-AllowsSecurityTradeoff`** de `New-Setting`.

Estado actual (2026-11-08): **un ajuste** toca esta lista y lleva la marca:
*Auto-Restart With Active Sessions* de *Actualizaciones*
(`HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU\NoAutoRebootWithLoggedOnUsers`
= 1). Su descripción dice lo que se pierde (las correcciones de seguridad que piden
reiniciar esperan a que reinicie el usuario; Microsoft avisa de que en un equipo del
que nadie cierra sesión puede no reiniciar nunca), su nota de juego es `na`, no viene
activo (de fábrica el valor no existe → `factory` → interruptor apagado) y `OFF` borra
la directiva. Windows solo la respeta con *Configure Automatic Updates* en la opción 4;
el ajuste lo dice y no escribe `AUOptions`.

Los 45 ajustes de *Regedit* no tocan esta lista ni llevan la marca. Son de rendimiento
(MMCSS, TCP/IP, SMB, Prefetcher, QoS), privacidad (telemetría, actividad, publicidad,
escritura a mano, peticiones de comentarios) y servicios (`Start` de cinco servicios concretos); uno **sube** la
seguridad: *Block WPBT Executables* (`DisableWpbtExecution`). Los ajustes de UAC,
BitLocker y Automatic Maintenance que existieron en versiones anteriores fueron
retirados.

**Servicios y tareas programadas (§14).** La misma denylist, llevada a nombres de
servicio y a carpetas de tareas: Defender (`WinDefend`, `WdNisSvc`, `Sense`...),
`SecurityHealthService`, `wscsvc`, el firewall (`mpssvc`, `BFE`), Windows Update
(`wuauserv`, `UsoSvc`, `WaaSMedicSvc`, `BITS`, `DoSvc`, `TrustedInstaller`), cifrado y
credenciales (`BDESVC`, `CryptSvc`, `KeyIso`, `VaultSvc`, `SamSs`...) y el núcleo
(`EventLog`, `RpcSs`, `Schedule`, `Winmgmt`...); y las carpetas de tareas
`WindowsUpdate`, `UpdateOrchestrator`, `WaaSMedic`, `Windows Defender`, `ExploitGuard`,
`BitLocker`, `TPM`, `SystemRestore`... **No se pueden marcar con
`-AllowsSecurityTradeoff`**: están en las listas de protegidos de `core/` y se rechazan
en tiempo de ejecución aunque alguien los añadiera a la lista blanca. Los 9 ajustes de
*Servicios y tareas* —telemetría y SysMain— no tocan ninguno.

---

## 4. Reversibilidad y rollback

- **Contrato duro:** el `Default` de cada clave. `OFF` (o el botón de restaurar) lo
  escribe. Se compara por valor, no por escritura (`0x0000000A` = `10` = `-1` según el
  tipo). Si la clave declara `DefaultAbsent = $true`, el contrato es "valor ausente":
  `OFF` lo **borra** y ausente cuenta como `factory`.
- **Copia adicional:** `$RegistrySnapshots` en `Writer.ps1` guarda el valor y el tipo
  **anteriores** a cada escritura o borrado (aunque estuvieran personalizados), si el
  valor **existía** y el estado de la lectura (`State`: `read`/`missing`/`denied`). Es
  el "deshacer" real, y es lo que usa `OFF` para **borrar** un valor que no existía la
  primera vez que el programa lo tocó en la sesión, en vez de escribir el `Default`.
  Como la copia vive en memoria, eso solo vale dentro de la misma sesión: tras
  reiniciar el programa, `OFF` vuelve a escribir el `Default` declarado.

> **Riesgo aceptado [Media] — descartado por decisión del propietario (2026-11-09).**
> `$RegistrySnapshots` vive **solo en memoria** y se pierde al cerrar la aplicación, y
> así se queda: **no se va a persistir**, no habrá "deshacer" en la UI ni aviso de punto
> de restauración o de `reg export`. El propietario no usa copias, backups ni puntos de
> restauración. El contrato de vuelta es el `Default` (o `DefaultAbsent`) declarado de
> cada clave; la copia en memoria sigue existiendo y es la que decide, dentro de la
> sesión, si `OFF` borra en vez de escribir. Ver §11 nº 2.

---

## 5. Ejecución de código — prohibiciones duras

Corriendo como administrador, **nada de esto entra** en `ui/` ni en `core/`:

| Prohibido | Por qué |
| --- | --- |
| `Invoke-Expression`, `iex`, `& ([scriptblock]::Create($x))` | Ejecuta cadena como código. |
| `Add-Type` con fuente construida en tiempo de ejecución | Lo mismo, compilado. (Los dos `Add-Type` del proyecto usan una cadena literal fija.) |
| `Invoke-WebRequest`, `Invoke-RestMethod`, `DownloadString`, `DownloadFile`, `Start-BitsTransfer` | La aplicación no habla con la red. |
| `Start-Process` con la ruta sin comillas | *Unquoted path* → ejecutable equivocado. |
| Arrancar un proceso fuera de `core/Commands/CommandRunner.ps1` (o un enlace fuera de `core/Shell/ExternalLink.ps1`) | Cada sitio que arranca procesos es una puerta; hay dos, con su lista blanca. Ver §12. |
| Borrar archivos fuera de `core/Commands/FolderCleanup.ps1` | Borrar desde un proceso elevado no tiene vuelta atrás: un solo sitio, con su lista blanca de carpetas. Ver §12. |
| Arrancar `cmd.exe`, `powershell.exe` o cualquier intérprete | Un intérprete convierte texto en código: tuberías, `&&`, redirecciones. |
| Ejecutar algo desde una carpeta escribible por todos | `C:\ProgramData`, `%TEMP%`, la carpeta del `.exe` si está en Descargas. |
| `-ExecutionPolicy Bypass` dentro del producto | Vale para desarrollo y para el `README`; no como algo que la app haga a espaldas del usuario. |

`tests/Source/Security.Tests.ps1` falla la suite si aparece cualquiera de las
primeras tres familias en `ui/` o `core/`.

---

## 6. Enlaces externos

`core/Shell/ExternalLink.ps1` abre una URL en el navegador por defecto vía
`Start-Process` (ShellExecute). Desde un proceso elevado, ShellExecute abriría
cualquier cosa (otro `.exe`, un `.bat`, un archivo local), así que:

- `$ExternalLinkSchemes` es **exactamente** `http`, `https`.
- `Test-ExternalLinkAllowed` exige URI **absoluta** y esquema en esa lista. Es una
  función pura (no toca el shell) y se prueba entera.
- Un esquema no permitido **ni siquiera llega** a `Start-Process`.
- Nada de aquí lanza: si algo falla, devuelve `$false` y la interfaz sigue igual.

`tests/Source/Security.Tests.ps1` falla si esa lista deja de ser `{http, https}`.

---

## 7. Datos del usuario y registro de actividad

- `settings.json` en `%APPDATA%\OptimizadorPC\` (no junto al `.exe`, que puede estar en
  una carpeta sin permisos de escritura). Preferencias de interfaz y, desde el
  2026-11-08, los pasos que el usuario cambió en las secciones de comandos
  (`StepChoices.<sección>`: solo los `Id`). **Nada sensible**: ni credenciales, ni rutas
  de otros usuarios, ni identificadores de máquina.
- **`settings.json` no es de fiar**: lo escribe cualquier programa del usuario, sin
  privilegios, y el `.exe` corre elevado. Lo que se lee de ahí no puede elegir qué se
  ejecuta (los pasos siguen siendo los de la lista blanca), pero sí podría dejar
  marcado uno peligroso a la espera de que el usuario pulse "Ejecutar". Por eso
  `Restore-StepChoices` **nunca restaura un paso con aviso** (`-Warning`: el reset del
  firewall, la papelera, el DNS fijo...): esos empiezan siempre como vienen declarados.
  Lo vigila `Ui/StepsView.Tests.ps1`.
- El **registro de actividad** (`core/Diagnostics/Log.ps1`) guarda las rutas y valores
  del registro leídos y escritos (viejo → nuevo). Se puede **exportar a un archivo** que
  elige el usuario ("Save to file" del cajón del log). Es divulgación de configuración
  del sistema **por acción propia del usuario** — aceptable. No sale a la red por sí
  solo. Las claves del registro son de optimización, nada sensible.
- **El detalle de la limpieza sí lleva nombres de archivos del usuario**: las rutas que
  borró cada `-Clean` (dentro de su perfil) y los nombres de lo que había en la
  papelera. Vive en memoria con el resto del log (como mucho `$CleanupListMax` rutas
  por lista) y solo va a disco si el usuario guarda el log **con la casilla "Con
  detalle" puesta**, que está a la vista junto a "Guardar". Sin ella, el archivo solo
  dice cuántas entradas tenían detalle. Mismo criterio que el resto: divulgación por
  acción propia, nunca a la red.
- **Sin telemetría, sin red saliente.** Si algún día aparece cualquiera de las dos, es
  una decisión de producto con consentimiento explícito.

---

## 8. Cadena de suministro y build

`build.ps1` empaqueta todo el proyecto en `build/_combined.ps1` y lo compila con
ps2exe. Puntos de seguridad:

- **ps2exe fijado** (desde 2026-09): `-RequiredVersion 1.0.18` + `-Repository PSGallery`
  en el `Install-Module`, y `Import-Module -RequiredVersion`. Sin esto, cada
  compilación podría traer código distinto del compilador, o podría ganar otro
  repositorio de PowerShell registrado con prioridad. Subir de versión es un cambio
  consciente: se edita el número, se recompila y se pasan las pruebas.
- **El `.exe` no está firmado — pero el build ya firma** (2026-11-09). Un binario sin
  Authenticode que pide UAC es justo lo que Windows enseña a no ejecutar. *Bloquea
  distribuir a terceros.* `build.ps1 -CertificateThumbprint <huella>` (o la variable
  `OPTIMIZADORPC_SIGN_THUMBPRINT`) firma con **SHA-256**, sello de tiempo **RFC 3161**
  SHA-256 (`-TimestampServer`, por defecto `http://timestamp.digicert.com`) y verifica con
  `Get-AuthenticodeSignature`. Contrato:
  - Solo acepta un certificado de `Cert:\CurrentUser\My` o `Cert:\LocalMachine\My` con
    EKU *Firma de código* (`1.3.6.1.5.5.7.3.3`), **clave privada** y en vigor; si no,
    lo dice, enseña los que sí valdrían y **no compila**.
  - Firma como `signtool sign /fd sha256 /tr <url> /td sha256`: una llamada a
    `SignerSignEx2` de `mssign32.dll` (P/Invoke con un literal fijo en
    `tools/CodeSigning.ps1`, que no entra en el `.exe`). **No** con
    `Set-AuthenticodeSignature`: su `-TimestampServer` solo pone el sello **legado**
    (contrafirma PKCS #9, comprobado por OID en 5.1 y 7), y sellar después con
    `SignerTimeStampEx2` reescribía el `.exe` firmado y en la máquina de desarrollo el
    proceso murió y el `.exe` desapareció con el antivirus encima.
  - Firma y sello van juntos: si el servidor de sellado no contesta, **no se firma**
    (el `.exe` se queda sin firma, código 1 y lo dice). `-NoTimestamp` firma sin sello
    a propósito, con aviso (la firma caduca con el certificado).
  - Resultado `Valid` → bien. Autofirmado → firma puesta, aviso de que no sirve para
    distribuir, código 0. Cualquier otro estado con un certificado de CA → código 1.
  - Imprime el **SHA-256** del `.exe` final, para publicarlo junto a la descarga.
  - `tools/New-DevSigningCert.ps1` crea un certificado autofirmado de prueba (RSA 3072,
    clave no exportable, 7 días) en `CurrentUser\My` **sin** meterlo en la raíz de
    confianza: sirve para recorrer el flujo, no para distribuir.

  **Lo que sigue dependiendo del propietario:** comprar un certificado de firma de
  código **OV o EV** (EV da reputación inmediata en SmartScreen; hoy los dos vienen en
  token o HSM, y el build los usa igual si el certificado aparece en `My` con su clave),
  o usar **Azure Trusted Signing** (no deja el certificado en el almacén: se firma
  después con `signtool` + su *dlib*, y `build.ps1` solo compilaría). La CI no firma: no
  hay certificado que darle.
- **CI (`.github/workflows/semgrep.yml`)** — corregido el 2026-09-07:
  - `actions/checkout` **fijado por SHA** (`d23441a…` = v6.1.0). Una etiqueta la puede
    repuntar el dueño de la acción en silencio; era el único hallazgo de Semgrep
    (`github-actions-mutable-action-tag`).
  - **Quitado el filtro `paths`** del disparador `push`: ahora cada push a `main`/
    `master` ejecuta Semgrep, no solo los que tocan el propio workflow. Antes, como el
    repo commitea directo a `master`, la cobertura efectiva era el `schedule` nocturno
    más `workflow_dispatch`.
  - **Imagen de Semgrep fijada por digest** (2026-11-08):
    `semgrep/semgrep:1.183.0@sha256:2e45517a…` (índice multiarquitectura de 1.183.0, que
    era `latest` ese día según la API de Docker Hub). Antes era `semgrep/semgrep` a secas
    = `latest`, que cambia en cada versión y lo puede repuntar quien publica. Subir de
    versión es cambiar tag y digest a conciencia.
  - *Pendiente:* no se sube SARIF a *code scanning* (los hallazgos solo salen en los
    logs de Actions) y los `--config` no están versionados en el repo.
- **CI de Windows (`.github/workflows/ci.yml`)** — nuevo el 2026-11-08, mismos
  disparadores que Semgrep (push a `main`/`master`, `pull_request`, manual) y
  `permissions: contents: read`:
  - Job `pssa`: PSScriptAnalyzer **fijado a 1.25.0** (`Install-Module -RequiredVersion`
    desde PSGallery, igual criterio que ps2exe) con `PSScriptAnalyzerSettings.psd1`,
    sin `build/`. Falla con cualquier **Error** y con cualquier aviso que no esté en la
    línea base `.github/pssa-baseline.txt` (comparación por regla + archivo, no por
    línea). Detalle en §9.
  - Job `pruebas`: `tests/Run-Tests.ps1` en **los dos hosts** (matriz `powershell` /
    `pwsh`, cada uno en su runner, `-STA` explícito). El arnés desarma la escritura al
    registro de la app y la ejecución de comandos; solo toca su rama de pruebas en
    `HKCU`, que borra al terminar.
  - Job `humo` (2026-11-09): compila con `build.ps1` en Windows PowerShell 5.1 (ps2exe
    fijado, sin firmar; borra antes el `.exe` versionado para probar el recién
    compilado) y corre `tests/Smoke/Invoke-Smoke.ps1 -Exe`. El runner es administrador
    sin UAC, así que el `.exe` (`-requireAdmin`) arranca elevado sin diálogo; la prueba
    comprueba en su token que lo está. No pulsa nada: arrancar solo lee el registro.
    Instala el proveedor NuGet si falta (`Install-Module` de 5.1 lo pide).
  - `actions/checkout` con el mismo SHA que `semgrep.yml` y `persist-credentials: false`
    (ningún job hace push).
  - *Sin probar todavía en un runner* (se escribió sin poder hacer push). Riesgo
    conocido: `windows-latest` es **Windows Server**, no Windows 11; ver riesgo 5 del
    §11.

---

## 9. Análisis estático — estado y recomendaciones

### PSScriptAnalyzer

- **Configurado**: `PSScriptAnalyzerSettings.psd1` en la raíz (auto-descubierto por
  `Invoke-ScriptAnalyzer -Path . -Recurse`). Solo reglas por defecto; cinco exclusiones,
  cada una con su motivo escrito (verbos de constructores de WPF, parámetro `$e` de los
  handlers, posicionales de la casa, `Write-Host` solo en runner/build, plurales de
  nombres públicos).
- **Cómo correrlo**: `Invoke-ScriptAnalyzer -Path . -Recurse -ReportSummary`
- **Instalado en la máquina de desarrollo** (v1.25.0, 2026-09-07).
- **En CI desde el 2026-11-08** (job `pssa` de `.github/workflows/ci.yml`, Windows
  runner, PSScriptAnalyzer **fijado a 1.25.0**). Corre la misma orden con `-Settings
  ./PSScriptAnalyzerSettings.psd1` y descarta `build/`. **Falla** si hay cualquier
  hallazgo de severidad **Error** (esté o no en la base) o un aviso que no esté en
  `.github/pssa-baseline.txt`. La base se compara por **regla + archivo** —contando
  repeticiones—, no por número de línea: mover código no la rompe, pero un segundo aviso
  de la misma regla en el mismo archivo sí. Si un aviso de la base desaparece, la CI lo
  anuncia (`::notice`) sin fallar, para bajarla. **Línea base inicial: 1 aviso**,
  `PSUseDeclaredVarsMoreThanAssignments` en `ui/Index/CategoryIndex.ps1` (el falso
  positivo de `$CategoryIndex`). Comprobado en local con la base real (pasa) y con una
  base vacía (falla y marca el aviso).
- **Estado 2026-09-07**: **0 errores, 2 avisos**, los dos falsos positivos de la misma
  familia — `PSUseDeclaredVarsMoreThanAssignments` sobre `$CategoryIndex`
  (`ui/Index/CategoryIndex.ps1`) y `$ScriptRoot` (`build/_combined.ps1`, generado): la
  variable se consume vía dot-source al mismo ámbito, algo que PSSA no ve archivo por
  archivo. Mismo patrón en el resto de `ui/Index/` y en `$GradientTokens`.
- **Segundo pase estricto solo sobre `core/`** (sin la exclusión de
  `PSUseShouldProcessForStateChangingFunctions`), ejecutado el 2026-09-07:
  `Invoke-ScriptAnalyzer -Path ./core -Recurse -Severity Error,Warning -ExcludeRule PSReviewUnusedParameter,PSAvoidUsingPositionalParameters,PSUseSingularNouns,PSAvoidUsingWriteHost`
  → **6 avisos, los 6 por el verbo del nombre, ninguno real**: `Set-WindowBackdrop`
  (llama a DWM sobre un handle, sin estado persistente), `Update-CategoryRegistryState`
  y `Update-SettingStatus` (solo **leen** y calculan), `New-RegistryResult` /
  `New-RegistryWriteResult` (fábricas de `PSCustomObject`), `Set-RegistryWriteArmed`
  (booleano en memoria del arnés). **La única función de `core/` que muta el sistema —
  `Write-RegistryValue` — ya lleva `[CmdletBinding(SupportsShouldProcess)]` +
  `$PSCmdlet.ShouldProcess`**, igual que `Set-SettingOptimization`. El "hueco residual"
  que menciona `PSScriptAnalyzerSettings.psd1` (una función nueva de `core/` que mutara
  el sistema sin adoptar `ShouldProcess`) queda **verificado: hoy no existe**.
- **Estado 2026-11-08**: con la configuración del proyecto, **1 aviso** (el de
  `$CategoryIndex`). El pase estricto sobre `core/` da **12**, todos por el verbo del
  nombre (fábricas, interruptores del arnés, `Stop-CommandStep` que solo corta su propio
  proceso). Lo que sí mutaba el sistema sin `ShouldProcess` desde las secciones de
  comandos —`Start-CommandStep`, `Remove-CleanupFile`, `Remove-CleanupFolder`,
  `Clear-CleanupRecycleBin`— **ya lo adopta**: con `-WhatIf` no se arranca nada, y la
  limpieza se recorre en simulacro y dice lo que borraría.

### Semgrep

- **Configurado**: `.github/workflows/semgrep.yml` corre `semgrep ci` en un contenedor,
  con `SEMGREP_APP_TOKEN`. **No hay archivo de reglas en el repo**: depende de la
  config de la plataforma / registro de Semgrep.
- **Instalado en la máquina de desarrollo** (v1.176.1, 2026-09-07). Ejecutado el
  2026-09-07:
  `semgrep scan --config p/security-audit --config p/secrets --config p/github-actions --exclude build --exclude tests`
  (59 reglas, 180 archivos). `p/powershell` **ya no existe** en el registro (HTTP 404);
  la cobertura de PowerShell de Semgrep es de todos modos limitada —el guardarraíl real
  para `ui/`/`core/` es `tests/Source/Security.Tests.ps1` + PSScriptAnalyzer—.
- **Un hallazgo, ya corregido**: `actions/checkout@v6` era una etiqueta mutable
  (`github-actions-mutable-action-tag`). Fijado por SHA (§8). Repetido el escaneo:
  **0 hallazgos**.
- **Ejecutado de nuevo el 2026-11-08** (`--oss-only`, que en Windows no hay motor Pro;
  `p/security-audit` + `p/secrets`; 109 archivos, sin `build/`, `tests/` ni
  `graphify-out/`): **0 hallazgos, 0 errores**.
- **Mejora pendiente**: subir SARIF a *GitHub code scanning* para que los hallazgos
  aparezcan en la pestaña Security y no solo en los logs de Actions; versionar los
  `--config` en el propio workflow para que la config no dependa solo de la plataforma.

### Por qué Snyk no encaja aquí

Snyk brilla escaneando **manifiestos de dependencias** (`package.json`,
`requirements.txt`, `pom.xml`…) y contenedores. Este proyecto **no tiene ninguno**: es
PowerShell puro sobre .NET Framework del sistema, sin paquetes de terceros en `ui/` ni
`core/`, y el único módulo externo (ps2exe) es una herramienta de build, ya fijada por
versión. Snyk Code (SAST) sí funcionaría, pero solaparía con Semgrep + PSScriptAnalyzer
sin añadir cobertura de PowerShell mejor que la de esos dos. **Alternativas que sí
aportan**, por orden de valor:

| Herramienta | Aporta | Límite |
| --- | --- | --- |
| **PSScriptAnalyzer** en CI (Windows runner) | Reglas específicas de PowerShell, gratis, sin token | **Hecho (2026-11-08)**: job `pssa` de `ci.yml`, versión fijada, contra línea base |
| **Semgrep** con rulesets fijados + SARIF | Patrones de seguridad e inyección, dedupe entre ramas | Ya en CI, disparador corregido e imagen fijada por digest; faltan `--config` versionados y SARIF |
| **Gitleaks** / `trufflehog` en pre-commit y CI | Secretos filtrados en el historial | Complementa a `p/secrets` |
| **Firma Authenticode del `.exe`** + hash publicado | Integridad del entregable | **Build listo (2026-11-09)**: `build.ps1 -CertificateThumbprint` firma SHA-256 + RFC 3161, verifica e imprime el SHA-256 (§8). Falta el certificado |
| `System.Windows.Automation` (prueba de humo) | Que el programa empaquetado arranca y no rompe | **Hecho (2026-11-08)**: `tests/Smoke/Invoke-Smoke.ps1` arranca `build/_combined.ps1` sin elevar. **Y el `.exe` elevado sin intervención (2026-11-09)**: `-Exe` desde un proceso ya elevado (sin diálogo de UAC), comprueba título, elevación del token, menú y cierre limpio; job `humo` de `ci.yml`. Sin elevar sale con 2 (saltado), nunca lanza UAC |

---

## 10. Invariantes verificadas por pruebas

`tests/Source/Security.Tests.ps1` (desde la auditoría del 2026-09-06) fija en la suite lo que
antes solo vivía en prosa. **Falla la suite** si:

| Invariante | Riesgo que cubre |
| --- | --- |
| Toda ruta de `-Registry` en `ui/Data/Categories/*` pasa `Test-RegistryWriteAllowed` | Una ruta mal escrita o fuera de la lista blanca acabaría en `blocked` en runtime sin que nadie se entere. |
| Ningún `.ps1` de `ui/` o `core/` usa `Invoke-Expression`, `iex`, `[scriptblock]::Create`, `Invoke-WebRequest`, `Invoke-RestMethod`, `DownloadString`, `DownloadFile`, `Start-BitsTransfer` | Ejecución de código ajeno / llamada de red desde proceso elevado. |
| Ningún `-Registry` apunta a un nombre de valor de la denylist del §3.4 sin `AllowsSecurityTradeoff = $true` en el ajuste | Un "tweak recomendado" que apaga Defender/UAC/Update sin declararlo. |
| `core/Shell/ExternalLink.ps1` `$ExternalLinkSchemes` es exactamente `http`, `https` | Un proceso elevado abriendo `file:` / `ms-settings:` / un `.exe` local. |
| Solo `core/Commands/CommandRunner.ps1` usa `ProcessStartInfo` / `Process::Start`, y solo `ExternalLink.ps1` usa `Start-Process` | Una tercera puerta para arrancar procesos con privilegios. |
| Solo `core/Commands/FolderCleanup.ps1` borra archivos (`Remove-Item`, `.Delete(`, `Clear-RecycleBin`) | Una segunda puerta para borrar con privilegios, sin lista blanca. |
| Toda entrada de `$CleanupAllowedFolders` tiene forma válida, resuelve **dentro de la carpeta del usuario** (o es `C:\Windows\Temp` exacto) y, salvo `%TEMP%`, nombra una subcarpeta concreta | Vaciar `%LOCALAPPDATA%` entera, o algo del sistema, por una línea mal escrita. |
| Un paso que vacía la papelera nunca viene marcado de serie y lleva aviso | Borrar sin vuelta atrás lo que el usuario guardó ahí para poder recuperarlo. |
| `$CommandAllowedExecutables` no tiene rutas ni intérpretes; `$CommandAllowedServices` no tiene servicios de seguridad (Defender, firewall, Update...) | Ampliar la lista hasta convertirla en una shell. |
| Todo `New-CommandStep` de cualquier sección pasa `Test-CommandStepAllowed` | Un paso fuera de la lista acabaría en `blocked` al pulsar, en silencio. |
| Un paso que toca `advfirewall` nunca viene marcado de serie y lleva aviso | Borrar las reglas del firewall sin que el usuario lo decida. |
| Un paso que cambia el DNS de un adaptador (`dns` con `set`/`add`) nunca viene marcado de serie y lleva aviso | Sustituir el DNS del router, o devolverlo a DHCP, sin que el usuario lo decida. |
| Cada clave de `-Registry` declara a dónde vuelve `OFF`: un `Default` **o** `DefaultAbsent`, nunca los dos | Un ajuste que no sabe volver a fábrica, o que vuelve a dos sitios distintos. |
| Nada en `ui/`/`core/` borra **claves** del registro, y solo `core/Registry/Writer.ps1` borra **valores** | Una segunda puerta para borrar del registro con privilegios, sin lista blanca. |
| Todo `-Service` pasa `Test-ServiceWriteAllowed` y toda `-ScheduledTask` pasa `Test-ScheduledTaskWriteAllowed` (ruta **y** nombre exactos) | Un servicio o una tarea fuera de la lista acabaría en `blocked` al pulsar, en silencio. |
| `$ServiceWriteAllowlist` no tiene ningún servicio de la denylist (Defender, firewall, Update, cifrado, núcleo) y `$ServiceProtectedNames` los tiene **todos**; `$ScheduledTaskWriteAllowlist` no cuelga de ninguna carpeta protegida (Update, Defender, BitLocker...) | Una rebaja de seguridad colada como "telemetría". |
| Cada `-Service`/`-ScheduledTask` declara `Recommended` y `Default`, nunca `DefaultAbsent` | Un servicio o una tarea que no sabe volver a fábrica. |
| Un ajuste toca **una** cosa: una clave, un servicio o una tarea | Un interruptor que cambia más de lo que dice. |
| Solo `core/Services/ServiceStartup.ps1` llama a `Set-Service` y solo `core/ScheduledTasks/ScheduledTaskState.ps1` a `Enable-`/`Disable-ScheduledTask`; nadie usa `sc config/stop/delete/create`, `schtasks`, `Stop-Service`, `Remove-Service` ni `(Un)Register-ScheduledTask` | Una segunda puerta, sin lista blanca, para cambiar servicios o tareas con privilegios. |

Cobertura de la ejecución de comandos: `tests/Core/CommandRunner.Tests.ps1` (lista
blanca, rutas rechazadas, desarmado, `blocked`, un proceso real de solo lectura,
decodificación de la salida), `tests/Core/FolderCleanup.Tests.ps1` (lista blanca de
carpetas, `%TEMP%` fuera del perfil con rutas buenas y malas, `C:\Windows\Temp`, los
dos modos de borrado, que una unión no se sigue —tampoco si aparece entre dos latidos—,
el simulacro de `-WhatIf` que no borra nada, por trozos; sobre una carpeta de mentira en
`%TEMP%`) y `tests/Ui/StepsView.Tests.ps1` (solo lo marcado, siempre en el orden del
archivo, detener, sección bloqueada, Limpieza entera desarmada, y que un paso con aviso
no se restaura marcado desde `settings.json`). Fuera de la suite, la prueba de humo
`tests/Smoke/Invoke-Smoke.ps1` arranca el programa empaquetado de verdad, y con `-Exe`
el `.exe` compilado **elevado** (job `humo` de la CI).

Cobertura de `core/` relacionada (ya existente):
`tests/Core/RegistryWriter.Tests.ps1` (lista blanca, tipado, snapshot, relectura,
`type mismatch`, `-WhatIf`, nunca lanza; y el borrado: solo el valor, misma lista
blanca, nombre vacío, otro tipo, `-WhatIf`, desarmado, copia previa, log) y
`tests/Core/SettingApply.Tests.ps1` (ON/OFF, recálculo de estado, rastro en el log;
`OFF` borra con `DefaultAbsent` o si la primera copia lo vio ausente, y escribe el
`Default` si existía o si la copia fue `denied`).

---

## 11. Riesgos aceptados y pendientes

| # | Riesgo | Sev. | Estado |
| - | --- | --- | --- |
| 1 | Lista blanca de escritura amplia (`SOFTWARE\Policies\Microsoft` alcanza Defender/Update/SmartScreen) | Media | **Mitigado en parte** por la denylist de nombres de valor (§3.4) + revisión manual. Estrechar el prefijo requiere saber qué claves se querrán escribir. |
| 2 | Rollback solo en memoria; sin "deshacer" en UI; sin aviso de punto de restauración | Media | **Aceptado — descartado por decisión del propietario (2026-11-09).** No se persistirá el snapshot ni habrá "deshacer" ni aviso de restauración: el propietario no usa copias ni puntos de restauración. El contrato de vuelta es el `Default`/`DefaultAbsent` de cada clave (§4). La fila se conserva para no cambiar la numeración que citan otros documentos. |
| 3 | `.exe` sin firma Authenticode | Media | **Aceptado** mientras no se distribuya a terceros. Bloquea la distribución. **Resuelto en el build (2026-11-09):** `build.ps1 -CertificateThumbprint <huella>` (o `OPTIMIZADORPC_SIGN_THUMBPRINT`) firma SHA-256 con sello RFC 3161 y verifica con `Get-AuthenticodeSignature`; sin certificado compila sin firmar y lo dice (§8). Probado de punta a punta con un certificado autofirmado de `tools/New-DevSigningCert.ps1` (firma presente, sello RFC 3161 de DigiCert, estado "raíz no de confianza" como se espera), borrado después. **Sigue dependiendo del propietario:** comprar el certificado de firma de código OV/EV, o usar Azure Trusted Signing; hasta entonces el `.exe` que se entrega sigue sin firma. |
| 4 | CI de Semgrep incompleta | Baja | **Corregido en parte.** 2026-09-07: `actions/checkout` fijado por SHA y quitado el filtro `paths` del `push` (cada push a master pasa por Semgrep). 2026-11-08: imagen fijada por digest (`semgrep/semgrep:1.183.0@sha256:2e45517a…`, §8). **Queda:** `--config` no versionados en el repo (depende de la config de la plataforma) y sin subida de SARIF a *code scanning*. |
| 5 | Sin CI de PSScriptAnalyzer ni de la suite de pruebas (solo Semgrep) | Baja | **Corregido, pendiente de verlo en verde (2026-11-08).** `.github/workflows/ci.yml` en `windows-latest`: PSScriptAnalyzer 1.25.0 contra línea base (§9) y la suite en los dos hosts (§8). Escrito sin poder hacer push: **no se ha ejecutado aún en un runner**. `windows-latest` es **Windows Server** (build ≥ 26100): `tests/Core/SystemInfo.Tests.ps1` ya distingue cliente de servidor (`InstallationType` = `Client`) y solo exige `^Windows 11` en un cliente. Solo se dispara en `master`/`main` y en PR: la rama de trabajo no lo ejecuta hasta abrir el PR. No hay runner x64 de Windows 11 alojado por GitHub. |
| 6 | `Add-Type` en `SystemBackdrop.ps1` y `WorkArea.ps1` compila una cadena de C# | Info | **Aceptado.** Las cadenas son literales fijos y revisados; no se construyen en runtime. `WorkArea.ps1` (2026-10-03) subclasifica la ventana propia con `SetWindowLongPtr` solo para corregir `WM_GETMINMAXINFO`; no toca otras ventanas ni otros procesos. |
| 7 | Contadores de las píldoras de la lista son fijos, no calculados | Info | **Cerrado (2026-11-08).** Con *Actualizaciones* leyendo el registro ya ninguna sección de ajustes cuenta por etiquetas: todas las píldoras salen del estado real. |
| 8 | Los pasos de Internet **no se deshacen** desde la app (reset de Winsock, TCP/IP, firewall) | Media | **Aceptado (2026-10-03).** Son los comandos del `.cmd` que el usuario ya usaba. Mitigado: lo que borra configuración propia (firewall, DNS) viene desmarcado y con aviso, se ejecuta paso a paso con registro de cada uno, y los reset piden reiniciar. **El DNS fijo ya tiene vuelta (2026-11-08):** el paso `dns-dhcp` (`netsh interface ip set dns name=Ethernet source=dhcp`, mismo ejecutable y misma lista blanca) devuelve el adaptador "Ethernet" al DNS del router. Viene desmarcado y con aviso, y nunca se restaura marcado desde `settings.json`: va detrás de los de Google y, marcado con ellos, los anularía (no hay forma de excluirlo en la cola; `-SkipIf` solo mira el registro). Pruebas: `Ui/StepsView.Tests.ps1` y `Source/Security.Tests.ps1`. El reset del firewall sigue sin vuelta. |
| 9 | Lo que borra Limpieza **no pasa por la papelera** y no se recupera | Media | **Aceptado (2026-11-08).** Es lo que hacía `EliminarTemporales.v1.cmd` con `del /q`. Mitigado: solo carpetas de una lista blanca y dentro de la del usuario; lo que se puede echar de menos (papelera, recientes, cookies, registros de WebCache) viene desmarcado y con aviso; los archivos en uso se saltan; cada paso deja en el log cuánto borró. |
| 10 | **Carrera al vaciar una carpeta (TOCTOU).** Entre comprobar que una subcarpeta no es un enlace y entrar en ella, otro proceso del mismo usuario podría cambiarla por una unión; corriendo elevado, el borrado la seguiría | Media | **Mitigado y aceptado (2026-11-08).** `Open-CleanupFolder` vuelve a mirar el atributo justo antes de entrar (prueba: `FolderCleanup.Tests.ps1`), lo que reduce la ventana a un instante. Cerrarla del todo exigiría borrar por descriptor con la API nativa (`FILE_FLAG_OPEN_REPARSE_POINT`). |
| 11 | `settings.json` lo puede escribir cualquier programa del usuario sin privilegios, y el `.exe` lo lee corriendo elevado | Baja | **Mitigado (2026-11-08).** De ahí solo salen preferencias de interfaz y qué pasos marcó el usuario; ningún paso fuera de la lista blanca puede entrar por ese camino, y un paso con aviso (firewall, papelera, DNS) **nunca** se restaura marcado (§7). |
| 12 | Un `%TEMP%` movido fuera del perfil (`R:\Temp`) se vacía aunque lo compartan otros usuarios | Baja | **Aceptado (2026-11-08).** Solo si la carpeta se llama `Temp`/`Tmp` y no cuelga de Windows, Archivos de programa, ProgramData ni de otro perfil (§12); la variable la fija el propio usuario. |
| 13 | Con `DefaultAbsent`, `OFF` **borra** el valor aunque lo hubiera puesto otro (una GPO de la organización, otra herramienta) | Baja | **Aceptado (2026-11-08).** Antes `OFF` lo pisaba con el `Default`, así que no es superficie nueva; ahora deja la directiva "sin configurar", que es el estado de fábrica. Una GPO de dominio la vuelve a aplicar en el siguiente refresco. Solo afecta a valores de la lista blanca y por acción explícita del usuario. |
| 14 | Servicios y tareas programadas sin mecanismo propio: el tipo de inicio de un servicio se cambiaba escribiendo su valor `Start` en el registro (lista de valores de §3.1), y las tareas no se podían tocar | Media | **Resuelto (2026-11-09).** `core/Services/ServiceStartup.ps1` y `core/ScheduledTasks/ScheduledTaskState.ps1`, con su lista blanca, su lista de protegidos, desarmado, `-WhatIf`, copia previa y relectura (§14). SysMain y DiagTrack se mudaron de *Regedit* a *Servicios y tareas*. **Queda:** sus dos entradas `Start` siguen en `$RegistryWriteAllowedValues` de `Writer.ps1` sin ningún ajuste que las use; quitarlas exige cambiar también `tests/Core/RegistryWriter.Tests.ps1`, que usa `SysMain\Start` como ejemplo de la lista de valores. Los otros cinco servicios de *Regedit* (lfsvc, MapsBroker, CscService, StorSvc, SharedAccess) siguen por el registro; pasarlos al mecanismo nuevo es una decisión pendiente. |
| 15 | El tipo de inicio y el estado de las tareas solo se copian **en memoria** (`$ServiceSnapshots`, `$ScheduledTaskSnapshots`) | Baja | **Aceptado (2026-11-09)**, por la misma decisión que el nº 2: el contrato de vuelta es el `Default` declarado (el de fábrica de Windows 11). Un servicio que el usuario tuviera en `Manual` a propósito vuelve a `Automatic` con `OFF`, igual que un valor del registro personalizado vuelve a su `Default`. Además, `Set-Service` de **pwsh 7** puede quitar el "inicio retrasado" al cambiar el tipo (no comprobado: las pruebas nunca escriben); el de 5.1 (el del `.exe`) no lo toca. Ninguno de los tres servicios lo usa de fábrica. |
| 16 | Dos tareas de la lista pueden no existir (`Microsoft Compatibility Appraiser` y `ProgramDataUpdater` faltan en compilaciones recientes de Windows 11; en la 26300 existe `Microsoft Compatibility Appraiser Exp`) | Info | **Aceptado (2026-11-09).** Salen `missing` → de fábrica, y el interruptor no hace nada (`Set-ScheduledTaskEnabled` devuelve `missing` sin escribir). La variante `Exp` **no** está en la lista blanca: añadirla es decisión del propietario. |

---

## 12. Ejecución de comandos — el contrato

Las secciones de **comandos** (hoy Internet, Limpieza y Energía) no escriben claves:
ejecutan programas de Windows (`netsh`, `ipconfig`, `nbtstat`, `arp`; `Dism`,
`cleanmgr`, `fsutil`, `defrag`; `powercfg`), arrancan dos servicios y vacían carpetas
de temporales. Todo
pasa por **`core/Commands/CommandRunner.ps1`**, y estas son sus reglas:

1. **Sin intérprete.** `ProcessStartInfo` con `UseShellExecute = $false`: el
   ejecutable se arranca directamente. Sin `cmd /c`, no hay tuberías, `&&`,
   redirecciones ni comodines del shell. Un argumento es un argumento.
2. **Lista blanca de ejecutables** (`$CommandAllowedExecutables`), solo por
   **nombre**, y la ruta la pone siempre la app: la carpeta de sistema
   (`[Environment]::GetFolderPath('System')`). Nunca el `PATH`: un `netsh.exe`
   plantado en la carpeta de trabajo se ejecutaría como administrador. Una ruta en
   el nombre (`C:\...\netsh.exe`, `.\netsh.exe`) se rechaza.
3. **Argumentos literales** del repositorio. Se rechaza cualquiera con comillas,
   saltos de línea o NUL. El usuario elige **qué pasos** corren, nunca su contenido.
4. **Servicios**: solo los de `$CommandAllowedServices` (`Dhcp`, `Dnscache`), y solo
   para **arrancarlos** si están parados. Nunca pararlos ni cambiar su inicio.
5. **El orden lo decide el archivo**, no el clic: los pasos marcados corren de
   arriba abajo. Muchos dependen de los anteriores (limpiar la pila antes de
   ajustar TCP).
6. **Nada lanza**: un paso fuera de la lista es `blocked`, uno que no arranca es
   `error`, uno colgado se mata al pasar su tiempo (`timed out`, 60 s por defecto y
   600 s para vaciar una carpeta).
7. **Rastro**: cada paso deja en el log su inicio (`running`) y su resultado con
   código de salida, duración y la salida recortada.
8. **Desarmable y simulable**: las pruebas lo desarman (`Set-CommandRunArmed $false`)
   y cada paso acaba en `disarmed` sin arrancar nada ni borrar nada. Con
   `Start-CommandStep -WhatIf` tampoco se arranca nada (`disarmed`, "WhatIf: not run"),
   salvo que un `-Clean` se recorre en simulacro y la papelera cuenta lo que tiene.
9. **Borrar carpetas** (`-Clean`) no arranca `cmd /c del`: lo hace
   **`core/Commands/FolderCleanup.ps1`** con .NET, y es el único sitio del programa que
   borra archivos.
   - **Lista blanca de carpetas** (`$CleanupAllowedFolders`), escritas como en el
     `.cmd` (`%TEMP%`, `%LOCALAPPDATA%\...`). El paso tiene que nombrar una **tal
     cual**: ni una subcarpeta ni otro patrón.
   - Solo cuatro variables (`%TEMP%`, `%LOCALAPPDATA%`, `%APPDATA%`, `%WINDIR%`), y las
     resuelve la app: las tres últimas con `GetFolderPath`, no leyendo el entorno.
   - **Dentro de la carpeta del usuario, con dos excepciones contadas**
     (`Get-CleanupPathProblem`): `C:\Windows\Temp` exacto (su paso pide administrador), y
     un `%TEMP%` movido fuera del perfil si la carpeta se llama `Temp` o `Tmp`, no es la
     raíz de un disco y no cuelga de Windows, Archivos de programa, ProgramData ni de la
     carpeta de perfiles. Todo lo demás, `blocked`: un `TMP=C:\Windows` vaciaría el
     sistema corriendo elevado.
   - **Simulable.** `Start-CommandStep -WhatIf` recorre la carpeta sin borrar y apunta lo
     que borraría (`WhatIf, nothing deleted: ...`).
   - **Los enlaces no se siguen.** Una unión o un enlace simbólico de dentro se quita
     (el enlace) o se deja; nunca se entra. Si la carpeta misma es un enlace, `blocked`.
   - **Se vacía, no se borra**: la carpeta raíz se queda, y lo que está en uso se salta
     y se cuenta.
   - Dos modos, los del `:DelMode` del `.cmd`: la carpeta a secas lo borra todo
     (también ocultos y subcarpetas); con `\*.ext` al final, solo esos archivos, sin
     ocultos ni de sistema y sin quitar carpetas.
   - **Por trozos** de 80 ms en cada latido del temporizador: `%TEMP%` con decenas de
     miles de archivos no congela la ventana.
10. **La papelera** (`-EmptyRecycleBin`) se vacía con `Clear-RecycleBin`, solo la del
    usuario, y nunca viene marcada de serie. Antes de vaciarla apunta qué había.
11. **Lo marcado se recuerda** entre sesiones (`settings.json`, `StepChoices`), **salvo
    los pasos con aviso**, que empiezan siempre como vienen declarados (§7).

**Añadir un ejecutable, un servicio o una carpeta a la lista es una decisión de
seguridad**, igual que una rama de la lista blanca del registro: se revisa a mano, se
apunta aquí y las pruebas de §10 lo vigilan. Añadir un **paso** con un ejecutable o
una carpeta ya permitidos es solo añadir un `New-CommandStep` en el archivo de la
sección.

Ejecutables de Limpieza, y por qué no son una shell: `Dism.exe` (solo
`/StartComponentCleanup`, sin `/ResetBase`), `cleanmgr.exe` (`/sagerun:1`),
`fsutil.exe` (`behavior set DisableDeleteNotify 0`, es decir, TRIM **activado**) y
`defrag.exe` (`/C /O`). `fsutil` puede mucho más; lo que corre lo fijan los argumentos
literales del repositorio, igual que con `netsh`.

Ejecutable de Energía: `powercfg.exe`, solo `/duplicatescheme` de la plantilla oculta de
Máximo rendimiento a un GUID **fijo** del programa y `/setactive` de ese GUID. No borra
ni modifica ningún otro plan.

**Saltar lo ya hecho (`-SkipIf`)**: un paso puede declarar un valor del registro; si
existe, el paso no se ejecuta y termina `succeeded` ("already in place"). Solo se
**lee** (`Read-RegistryValueRaw`), después de la comprobación de desarme. Existe porque
`powercfg` devuelve el mismo código para "ya existe" que para cualquier otro fallo.

---

## 13. Cómo reportar una vulnerabilidad

Es un proyecto personal, repositorio público en GitHub
(`github.com/johansparra/OptimizadorPC`). Para reportar un problema de seguridad, abre
un *issue* marcándolo como sensible o usa el contacto del perfil del repositorio.
Describe la **clase** de problema y un escenario de fallo con valores reales; no hace
falta un exploit funcional.

---

## 14. Servicios y tareas programadas — el contrato

*(2026-11-09.)* Un ajuste puede declarar, en vez de una clave del registro, **el tipo
de inicio de un servicio** (`-Service`) o **si una tarea programada está habilitada**
(`-ScheduledTask`). Cada uno tiene su mecanismo en `core/`, con el mismo contrato que
`core/Registry/Writer.ps1`, y el toggle llega por el mismo camino que una clave
(`core/Registry/SettingApply.ps1`: `ON` → `Recommended`, `OFF` → `Default`). Hoy los usa
una sola sección, *Servicios y tareas* (`ui/Data/Categories/Services.ps1`).

| | Servicios | Tareas programadas |
| --- | --- | --- |
| Archivo | `core/Services/ServiceStartup.ps1` | `core/ScheduledTasks/ScheduledTaskState.ps1` |
| Qué cambia | **Solo** el tipo de inicio: `Automatic`, `Manual` o `Disabled` | **Solo** habilitada / deshabilitada |
| Qué NO hace nunca | Parar, arrancar, crear, borrar; tocar la cuenta, el ejecutable, las dependencias o los permisos | Crear, borrar, ejecutar, parar; tocar desencadenadores, acciones o la cuenta |
| Lee con | CIM (`Win32_Service`), el mismo `StartMode` en 5.1 y en 7 | `Get-ScheduledTask` (módulo `ScheduledTasks` de Windows) |
| Escribe con | `Set-Service -StartupType` | `Enable-ScheduledTask` / `Disable-ScheduledTask` |
| Lista blanca | `$ServiceWriteAllowlist`, por **nombre exacto** | `$ScheduledTaskWriteAllowlist`, por **ruta y nombre exactos** |
| Protegidos (se rechazan aunque estén en la blanca) | `$ServiceProtectedNames` | `$ScheduledTaskProtectedPaths` (prefijos de carpeta) |
| Desarmado (pruebas) | `Set-ServiceWriteArmed $false` | `Set-ScheduledTaskWriteArmed $false` |
| Copia previa (en memoria) | `$ServiceSnapshots` | `$ScheduledTaskSnapshots` |
| Origen en el log | `services` | `tasks` |

**Sin intérprete ni ejecutables**: nada de `cmd /c`, `powershell -c`, `sc.exe` ni
`schtasks.exe`. Lo vigila `Security.Tests.ps1` (§10).

**Lista blanca de hoy:**

```text
Servicios:  DiagTrack  dmwappushservice  SysMain

Tareas:     \Microsoft\Windows\Application Experience\Microsoft Compatibility Appraiser
            \Microsoft\Windows\Application Experience\ProgramDataUpdater
            \Microsoft\Windows\Customer Experience Improvement Program\Consolidator
            \Microsoft\Windows\Customer Experience Improvement Program\UsbCeip
            \Microsoft\Windows\Autochk\Proxy
            \Microsoft\Windows\DiskDiagnostic\Microsoft-Windows-DiskDiagnosticDataCollector
```

Todo es telemetría salvo SysMain (el precargador de memoria), cuya tarjeta dice que es
discutible y que en un disco duro suele empeorar. Ninguno baja la seguridad del equipo.

**Cada escritura, en este orden** (igual que el registro): armada → nombre con forma
válida (sin comillas ni comodines: el nombre de un servicio va dentro de un filtro de
CIM, y `Get-ScheduledTask` expande `*`, `?` y `[]`) → lista blanca y no protegido → valor
que se sepa escribir → lectura previa y **copia** → si no existe, `missing` sin escribir;
si no se pudo leer, `denied` sin escribir → si ya está así, `nochange` → `-WhatIf` →
escribir → **relectura**. Estados: `written`, `nochange`, `blocked`, `badname`,
`unsupported`, `missing`, `denied`, `disarmed`. **Nada lanza.**

**Reversibilidad.** El contrato de vuelta es el `Default` declarado de cada entrada, el
de fábrica de Windows 11: `DiagTrack` `Automatic`, `dmwappushservice` `Manual`, `SysMain`
`Automatic`, las seis tareas `Enabled`. No hay `DefaultAbsent`: un servicio o una tarea no
se borran (lo vigila `Security.Tests.ps1`). La copia previa vive en memoria, igual que la
del registro (§4, §11 nº 15). **Los valores de fábrica no se pudieron comprobar en el
equipo de desarrollo**, que ya los tenía todos deshabilitados; son los de una instalación
limpia de Windows 11.

**Lo que no existe en este equipo** (una tarea que una compilación nueva quitó) se lee
`missing`, cuenta como `factory` —igual que un valor del registro ausente— y su
interruptor no hace nada (§11 nº 16).

**El cambio de un servicio vale desde el siguiente reinicio**: el servicio que ya corre
no se para. La tarjeta lo dice.

**Añadir un servicio o una tarea a la lista blanca es una decisión de seguridad**, igual
que una rama del registro: se revisa a mano, se apunta aquí y las pruebas de §10 lo
vigilan (que no esté en la denylist y que cada `-Service`/`-ScheduledTask` declarado pase
la lista). Ampliar la denylist se hace en los dos sitios: `$ServiceProtectedNames` /
`$ScheduledTaskProtectedPaths` en `core/` y `$SecurityDeniedServices` /
`$SecurityDeniedTaskFolders` en `tests/Source/Security.Tests.ps1`.

Pruebas: `tests/Core/ServiceStartup.Tests.ps1`, `tests/Core/ScheduledTaskState.Tests.ps1`
(lista blanca, protegidos, comodines, lectura real de un servicio y una tarea que existen,
`missing`, desarmado, rechazos armados con `-WhatIf`, que `-WhatIf` no cambia nada,
copia previa) y `tests/Core/ServicesSection.Tests.ps1` (la sección entera leída de
verdad y aplicada desarmada). **Las pruebas nunca cambian un servicio ni una tarea.**
