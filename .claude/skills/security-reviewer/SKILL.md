---
name: security-reviewer
description: Revisor de seguridad de una aplicación que corre ELEVADA y va a escribir en el registro de Windows. Úsalo antes de mezclar cambios, al implementar cualquier escritura al sistema (registro, servicios, tareas programadas, directivas) y al revisar tweaks propuestos. Cubre el modelo de amenaza del .exe con -requireAdmin, ejecución de código, reversibilidad, ajustes que degradan la seguridad del equipo y cadena de suministro del build. Trigger words - seguridad, security, revisar, auditar, elevado, admin, UAC, permisos, registro, escribir, aplicar tweak, riesgo, reversible.
---

# Revisión de seguridad — Optimizador PC

## 1. Modelo de amenaza

Esto no es una web ni un servicio: es un **binario portable que el usuario ejecuta
como administrador en su propia máquina**.

```
-requireAdmin  -> todo el código corre con privilegios completos
-noConsole     -> el usuario NO ve mensajes; un fallo es silencioso
portable       -> puede acabar en un USB, una descarga o un pendrive ajeno
```

De ahí salen los tres riesgos reales, por orden de gravedad:

1. **Dejar el equipo menos seguro que antes.** Es el riesgo principal y el más fácil
   de colar: un "tweak recomendado" que apaga UAC, Defender, SmartScreen, el firewall
   o el cifrado. El usuario acepta un optimizador, no una rebaja de seguridad.
2. **Dejar el equipo roto y sin vuelta atrás.** Un cambio elevado sin valor de
   restauración es irreversible para quien no sabe editar el registro.
3. **Ejecutar código que no es nuestro con privilegios de administrador.** Cualquier
   entrada externa (una ruta, un valor, un archivo, una descarga) que acabe
   ejecutándose.

**El estado hoy:** tres mecanismos tocan el equipo, cada uno con su lista blanca.
`core/` **lee y escribe** el registro: la escritura vive en `core/Registry/Writer.ps1`
(una clave) y `core/Registry/SettingApply.ps1` (el toggle ON/OFF de un ajuste), y hoy
son **49** ajustes con `-Registry` (47 en *Regedit* y 2 en *Actualizaciones*), uno por
clave. `OFF` escribe el `Default` o **borra** el valor si de fábrica no existe
(`Remove-RegistryValue`, nunca borra claves). Las secciones
de comandos **ejecutan programas** (`core/Commands/CommandRunner.ps1`: `netsh`,
`ipconfig`, `nbtstat`, `arp`, `Dism`, `cleanmgr`, `fsutil`, `defrag`, `powercfg`, sin
shell) y **borran archivos** (`core/Commands/FolderCleanup.ps1`: carpetas de una lista
blanca dentro del perfil, sin seguir enlaces, y la papelera). Lo que se revisa ahora
es **cada ampliación de una lista blanca** —rutas del registro, ejecutables,
servicios, carpetas— y **cada ajuste o paso nuevo**. `SECURITY.md` en la raíz del
repo tiene los contratos enteros (§3 registro, §12 comandos y borrado).

## 2. Ejecución de código — prohibiciones duras

Corriendo como administrador, nada de esto entra:

| Prohibido | Por qué |
| --- | --- |
| `Invoke-Expression`, `iex`, `& ([scriptblock]::Create($x))` | Ejecuta cadena como código. Con admin, es ejecución arbitraria. |
| `Add-Type` con código fuente construido en tiempo de ejecución | Lo mismo, compilado. |
| `DownloadString`, `DownloadFile`, `Invoke-WebRequest` a un script | La aplicación no habla con la red. Si algún día lo hace, es una decisión de producto, no un detalle de implementación. |
| `Start-Process` con la ruta sin comillas | Ruta sin comillas con espacios = *unquoted path*, ejecutable equivocado. |
| Ejecutar algo desde una carpeta escribible por todos | `C:\ProgramData`, `%TEMP%`, la carpeta del propio `.exe` si está en Descargas. |
| `-ExecutionPolicy Bypass` dentro del producto | Vale para desarrollo y para el `README`; no como algo que la aplicación haga a espaldas del usuario. |

```bash
# Barrido rápido
grep -rniE "invoke-expression|\biex\b|downloadstring|downloadfile|start-process" \
  --include=*.ps1 . | grep -v build/
```

## 3. Escribir en el registro — las condiciones

Cada cambio necesita **las cinco**. `core/Registry/Writer.ps1` ya las cumple; al
revisar un ajuste nuevo o una rama nueva de la lista blanca, comprueba que se siguen
cumpliendo:

1. **Valor de restauración documentado.** El `Default` declarado en
   `ui/Data/Categories/*.ps1` es ese contrato: `OFF` escribe ese valor, o lo **borra**
   si la clave declara `DefaultAbsent = $true` (de fábrica no existe). Cada clave lleva
   uno de los dos, nunca ambos (lo vigila `Security.Tests.ps1`). Un ajuste sin ninguno
   no se puede revertir: no se aplica. `Writer.ps1` guarda además el valor previo en
   `$RegistrySnapshots` (**solo en memoria**, y así se queda: el propietario descartó
   persistirlo, ver `SECURITY.md` §4).
2. **Distinguir "no existía" de "valía otra cosa".** `Writer.ps1` lo hace vía
   `Get-RegistryStoredValue` (`missing` vs `read`) y lo apunta en el snapshot
   (`Existed`, `State`). Si la primera copia de la sesión lo vio `missing`, `OFF` lo
   borra con `Remove-RegistryValue` (estado `deleted`): solo el valor, misma lista
   blanca de ruta y nombre, `-WhatIf`, relectura. Un `denied` no cuenta como ausente.
3. **Ruta validada contra `$RegistryWriteAllowlist`** (`Test-RegistryWriteAllowed`),
   nunca concatenada con entrada libre. Se abre siempre `RegistryView::Registry64`.
   Fuera de la lista → estado `blocked`, no se escribe. **Ampliar esa lista es una
   decisión de seguridad**: `HKLM\SOFTWARE\Policies\Microsoft` (ya dentro) alcanza las
   claves GPO de Defender, Update y SmartScreen.
4. **Escribir el tipo declarado.** `ConvertTo-RegistryData` respeta el `Type`; un tipo
   real distinto al pedido → estado `typemismatch`, no se pisa. `MultiString` no se
   sabe escribir todavía (`unsupported`).
5. **Nada de tocar ACLs ni propietarios.** Clave protegida → `denied`, se enseña, no
   se fuerza. Cambiar el propietario de una clave del sistema es un agujero permanente.

**Preferir `HKCU` a `HKLM` siempre que exista la variante.** Afecta solo al usuario,
no necesita privilegios y el daño potencial es mucho menor.

**Descartado por decisión del propietario:** ni `reg export`, ni punto de
restauración, ni "deshacer" en la UI (`SECURITY.md` §4 y §11 nº 2). No lo propongas
como hallazgo; la red de seguridad es el `Default`/`DefaultAbsent` de cada clave.

## 4. Ajustes que degradan la seguridad del equipo

**Esta es la revisión que más importa aquí.** Un ajuste que baja la postura de
seguridad no está prohibido, pero:

- **no puede llamarse "Recommended"** sin más,
- su descripción tiene que decir **qué protección se pierde**,
- y no puede estar activo por defecto.

Revisa `ui/Data/Categories/*.ps1` contra esta lista. Todo lo que toque:

`ConsentPromptBehaviorAdmin` · `PromptOnSecureDesktop` · `EnableLUA` ·
`LocalAccountTokenFilterPolicy` · Windows Defender / `DisableAntiSpyware` /
`DisableRealtimeMonitoring` / exclusiones · SmartScreen (`SmartScreenEnabled`,
`EnableSmartScreen`) · `PreventDeviceEncryption` / BitLocker · firewall ·
Windows Update / `NoAutoUpdate` · ejecución de macros · directivas de contraseña ·
UAC remoto

**Estado vivo en este repositorio** (verificado leyendo `ui/Data/Categories/Regedit.ps1`
y `Update.ps1`):

| Grupo (47 ajustes con `-Registry` y 9 de *Servicios y tareas*, uno por objetivo) | Ejemplos | Riesgo |
| --- | --- | --- |
| Rendimiento | MMCSS (`NetworkThrottlingIndex`, `SystemResponsiveness`, prioridades de *Games*), TCP/IP (`DefaultTTL`, `Tcp1323Opts`...), SMB de `LanmanServer`, Prefetcher, QoS | Ninguno de seguridad. Reversibles por su `Default`. |
| Privacidad | Telemetría (`AllowTelemetry`, `Default = 1`: OFF nunca sube el nivel), historial de actividad, ID de publicidad, escritura a mano, voz en línea, peticiones de comentarios (`NumberOfSIUFInPeriod`, `DefaultAbsent`) | Ninguno: reducen lo que sale del equipo. |
| Servicios (`Start`) | lfsvc, MapsBroker, CscService, StorSvc, SharedAccess | Ninguno de seguridad; ICS rompe la zona con cobertura (lo dice su nota). |
| *Servicios y tareas* (`-Service`, `-ScheduledTask`, `SECURITY.md` §14) | Tipo de inicio de DiagTrack, dmwappushservice y SysMain; seis tareas de telemetría (CEIP, Appraiser, Autochk\Proxy, DiskDiagnosticDataCollector) | Ninguno de seguridad. Listas blancas propias y listas de **protegidos** (Defender, firewall, Update, BITS, cifrado, núcleo) que se rechazan en runtime. |
| Sube la seguridad | *Block WPBT Executables* (`DisableWpbtExecution`) | — |
| *Actualizaciones* | Delivery Optimization (`DODownloadMode` = 0, solo HTTP) | Ninguno: reduce lo que sale del equipo. |
| *Actualizaciones* — **baja la seguridad** | *Auto-Restart With Active Sessions* (`NoAutoRebootWithLoggedOnUsers` = 1) | Los parches que piden reiniciar esperan al usuario. Lleva `-AllowsSecurityTradeoff`, lo dice en su descripción y no viene activo (de fábrica el valor no existe). |

Repasado el 2026-11-08: solo `NoAutoRebootWithLoggedOnUsers` toca la denylist de
arriba, y lo declara. Los ajustes de UAC, BitLocker y Automatic Maintenance que
antes vivían en *Regedit* **fueron retirados**.

Fuera del registro, las secciones de comandos tienen **dos pasos que bajan la postura**,
los dos desmarcados de serie y con aviso: restablecer el firewall (borra las reglas
propias) y fijar el DNS de Google (sustituye el del router). Un paso con aviso **nunca**
se restaura marcado desde `settings.json` (§5).

**Control automático:** `tests/Source/Security.Tests.ps1` recorre todos los `-Registry`
de `ui/Data/Categories/*` y **falla la suite** si alguno apunta a un nombre de valor de
la denylist de arriba sin llevar `AllowsSecurityTradeoff = $true` en el ajuste. Esa
marca obliga a una decisión explícita y revisable; no la pongas para "callar el test".

Al revisar un tweak nuevo, comprueba siempre **el valor numérico**, no el nombre del
ajuste. El nombre lo escribimos nosotros; el número es lo que ejecuta Windows.

## 5. Datos del usuario

- `settings.json` vive en `%APPDATA%\OptimizadorPC\`: correcto (no junto al `.exe`,
  que puede estar en una carpeta sin permisos).
- **No debe guardar nada sensible.** Preferencias de interfaz y qué pasos marcó el
  usuario, nada más. Ni rutas de otros usuarios, ni credenciales, ni identificadores de
  máquina.
- **Y no es de fiar**: lo escribe cualquier programa del usuario sin privilegios, y el
  `.exe` lo lee elevado. Nada que salga de ahí puede elegir qué se ejecuta ni dejar
  preparado un paso peligroso (por eso los pasos con aviso no se restauran).
- El **registro de actividad** (`core/Diagnostics/Log.ps1`) guarda rutas y valores del
  registro del equipo (y ahora también las escrituras: valor viejo → valor nuevo). Ya
  se puede **exportar a un archivo** que elige el usuario ("Save to file" del cajón del
  log). Es divulgación de configuración del sistema **por acción propia del usuario** —
  aceptable, pero: no debe salir a la red por sí solo, y si algún día hay "enviar
  informe", revisa qué se manda. Hoy solo son claves de optimización, nada sensible.
- Sin telemetría, sin red saliente. Si aparece cualquiera de las dos, es una decisión
  de producto con consentimiento explícito, no un añadido silencioso.

## 6. Cadena de suministro

`build.ps1` instala su compilador desde internet. Desde 2026-09 va **fijado**:

```powershell
$Ps2ExeVersion = '1.0.18'
Install-Module -Name ps2exe -RequiredVersion $Ps2ExeVersion -Repository PSGallery -Scope CurrentUser -Force -AllowClobber
Import-Module ps2exe -RequiredVersion $Ps2ExeVersion
```

Al revisar: que `-RequiredVersion` y `-Repository PSGallery` sigan ahí (sin ellos, cada
compilación podría traer código distinto o ganar otro repositorio registrado), y que
subir de versión sea un cambio consciente con recompilación y prueba. `-Force
-AllowClobber` sobrescribe sin preguntar: aceptable para un build local.

**Sin resolver:** el `.exe` **no está firmado** (Authenticode). Un binario sin firma
que pide UAC es justo lo que Windows enseña a no ejecutar. Bloquea distribuir a
terceros hasta que haya firma. **El build ya firma** (2026-11-09):
`build.ps1 -CertificateThumbprint` firma SHA-256 + RFC 3161 vía `SignerSignEx2`
(`tools/CodeSigning.ps1`, fuera de las capas) y verifica; falta que el propietario
compre el certificado (OV/EV) o use Azure Trusted Signing. Al revisar: que el
`Add-Type` de `tools/CodeSigning.ps1` siga siendo un literal fijo y que
`New-DevSigningCert.ps1` nunca meta su certificado en la raíz de confianza. En la CI, `actions/checkout` va fijado por SHA y la
imagen `semgrep/semgrep` por digest (2026-11-08); PSScriptAnalyzer se instala con
`-RequiredVersion 1.25.0` (`.github/workflows/ci.yml`). Subir cualquiera de los tres es
un cambio consciente, como ps2exe.

## 7. Cómo revisar y cómo reportar

Revisión de un diff, en este orden:

1. ¿Aparece alguna escritura al sistema nueva? (`SetValue`, `Set-Service`,
   `New-ItemProperty`, `schtasks`, `bcdedit`, `netsh`) → revisión completa de §3.
2. ¿Algún ajuste toca la lista de §4? → comprueba el número y la etiqueta.
3. ¿Entra código desde fuera? → §2.
4. ¿Algo escapa de `core/` como excepción? Con `-noConsole` eso es una ventana que se
   cierra sin explicación.
5. ¿Se guarda algo nuevo en disco? → §5.

Reporta cada hallazgo así, y **ordénalos por gravedad real** (ejemplo ilustrativo, no
es un caso vivo):

```
[Alta] ui/Data/Categories/Ejemplo.ps1:53 — ConsentPromptBehaviorAdmin Recommended = 0
Qué pasa: al aplicar el ajuste, cualquier proceso que pida elevación la obtiene sin
que el usuario vea el aviso. UAC deja de ser una barrera.
Arreglo: usar 5 (por defecto) o 2 como recomendado, describir la pérdida, y marcar
AllowsSecurityTradeoff = $true para que pase Security.Tests.ps1 de forma explícita.
```

Sé concreto y sin dramatismo: un escenario de fallo con valores reales convence; una
categoría genérica de riesgo, no. Y **no inventes hallazgos**: si el diff está limpio,
dilo en una línea.
